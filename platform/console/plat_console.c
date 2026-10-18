/* ------------------------------------------------------------------------
   Console platform: z88dk's conio for output and its input library for the
   keyboard, so that the same file serves every machine z88dk can drive that
   way (Aquarius+, NC200, Z88 and ZX Spectrum).  Nothing here reads a keyboard
   matrix or writes video memory directly; that is z88dk's job.

   Tile graphics (HAVE_TILES): the game's pictures are 8x8 bitmaps held back to
   back in the engine (view_tile_art: 94 map tiles, then 251 large-zone pieces).

   ZX Spectrum (TARGET_ZX): a cell is drawn by copying its 8 bytes straight into
   screen memory (zx_cxy2saddr/zx_cxy2aaddr find the cell, zx_blit8 copies).
   Printing the same cell through the console costs about 7000 T-states, 20 times
   as much, which made scrolling and redraws take a second.  Text still goes
   through conio, in its 32 column mode (CLIB_ZX_CONIO32), where cells are 8x8.

   Other bitmap consoles (NC200, and the Aquarius+ once it is switched to its bitmap
   mode, TARGET_AQPLUS): the console looks a character's 8 bytes up in a
   font or UDG table *when it is printed*, and the table is just a pointer, so the
   map is drawn without copying anything:

     tile n            font pointer -> view_tile_art,           character 32 + n
     zone piece p      UDG pointer  -> a 128-piece window,      character 128 + p%128
     cursor            UDG pointer  -> a scratch inverted copy, character 128

   Text is printed with the standard font, put back whenever a string is drawn.

   The Z88 (TARGET_Z88) is different: z88dk's mode 1 gives a text window of 51 columns on the
   left and a 256 pixel graphics map on the right, and when a font pointer is set the console
   IS the map (32 columns by 8 rows, drawn with custom font and UDGs, as on the NC200).  So the
   console only ever draws tiles, and all text goes to the OZ text window with OZ's own string
   call (GN_Sop), through plat_text_puts().
   ------------------------------------------------------------------------ */
#include <stdint.h>
#include <conio.h>
#include <input.h>
#include <stdio.h>
#include <sys/ioctl.h>
#ifdef TARGET_Z88
#include <fcntl.h>
#endif
#include "engine.h"
#include "platform.h"

static uint16_t clock_count;

#ifdef TARGET_Z88
extern void z88_sop(const char *s) __z88dk_fastcall;    /* plat_z88.asm: OZ GN_Sop */
#define Z88_TEXT_COLS   51      /* the text window z88dk's mode 1 opens, beside the map */
#define Z88_TEXT_ROWS   8
#define Z88_MAP_COLS    32      /* the 256 pixel map, in 8 pixel cells */
#define Z88_MAP_ROWS    8
static char z88_text[5 + Z88_TEXT_COLS + 1];

/* ---- the tool icons: OZ user defined characters 64..119, four to an icon ----
   1,138,'=',code,r0..r7 defines a character (the rows with bit 7 set), 1,'2','?',code prints it. */
extern const uint8_t z88_icons[];           /* platform/console/plat_z88.asm */
#define ICON_FIRST_CHAR 64
#define NUM_ICONS       14
static uint8_t icons_ok;                    /* the characters are defined */
static char icon_text[5 + NUM_ICONS * 12 + 1];

static void define_icons(void)
{
    char d[13];
    uint8_t c, r;

    d[0] = 1; d[1] = (char)138; d[2] = '=';
    d[12] = 0;
    for (c = 0; c < NUM_ICONS * 4; ++c) {
        d[3] = (char)(ICON_FIRST_CHAR + c);
        for (r = 0; r < 8; ++r)
            d[4 + r] = (char)(z88_icons[c * 8 + r] | 0x80);
        z88_sop(d);
    }
    icons_ok = 1;
}

/* The icons, two rows of 14 icons of 2 cells, in rows 3 and 4 of the text window; the selected one in reverse. */
void plat_icons(uint8_t selected)
{
    uint8_t i, r, n;
    char c;

    if (!icons_ok)
        define_icons();
    for (r = 0; r < 2; ++r) {
        icon_text[0] = 1; icon_text[1] = '3'; icon_text[2] = '@';
        icon_text[3] = 32;
        icon_text[4] = (char)(32 + 3 + r);                 /* rows 3 and 4 */
        n = 5;
        for (i = 0; i < NUM_ICONS; ++i) {
            if (i == selected) {
                icon_text[n++] = 1; icon_text[n++] = 'R';
            }
            for (c = 0; c < 2; ++c) {
                icon_text[n++] = 1; icon_text[n++] = '2'; icon_text[n++] = '?';
                icon_text[n++] = (char)(ICON_FIRST_CHAR + i * 4 + r * 2 + c);
            }
            if (i == selected) {
                icon_text[n++] = 1; icon_text[n++] = 'R';
            }
        }
        icon_text[n] = 0;
        z88_sop(icon_text);
    }
}
static uint16_t z88_mode;
#endif

/* How tiles are drawn.  TILE_BLIT: copy to screen memory (ZX Spectrum default).
   TILE_PRINT: print characters whose pictures come from the font and UDG pointers (the
   NC200, the Aquarius+ and, with ZX_PRINT, the Spectrum: the same path as text). */
#if defined(HAVE_TILES) && defined(TARGET_ZX) && !defined(ZX_PRINT)
#define TILE_BLIT
#elif defined(HAVE_TILES)
#define TILE_PRINT
#endif

#if defined(TILE_BLIT)
#include <arch/zx.h>
extern void zx_blit8(uint8_t *screen, const uint8_t *art, uint8_t inverse) __smallc;   /* plat_zx_blit.asm */
#define text_mode()
#elif defined(TILE_PRINT)
#ifdef TARGET_ZX
extern uint8_t _zx_console_attr;                /* the colour the console prints in */
static uint8_t std_attr;
#endif
extern void *plat_std_font(void);               /* plat_font.asm */
extern void plat_set_font(const void *p) __z88dk_fastcall;
extern void plat_set_udgs(const void *p) __z88dk_fastcall;

static const uint8_t *std_font;
static const uint8_t *font_now;                 /* font the console is using */
static const uint8_t *udg_now;                  /* UDG table the console is using */
static uint8_t tile_mode;                       /* the tile font and colours are selected */
static uint8_t cursor_art[8];

static void set_font(const uint8_t *p)
{
    if (p != font_now) {
        plat_set_font(p);
        font_now = p;
    }
}

static void set_udgs(const uint8_t *p)
{
    if (p != udg_now) {
        plat_set_udgs(p);
        udg_now = p;
    }
}

/* Back to the standard font and colour before printing text. */
static void text_mode(void)
{
#ifdef TARGET_Z88
    return;                             /* the console is always the map: the text is OZ's */
#endif
    if (tile_mode) {
        set_font(std_font);
#if defined(TARGET_ZX)
        _zx_console_attr = std_attr;
#endif
        tile_mode = 0;
    }
}
#else
#define text_mode()
#endif

#ifdef TARGET_AQPLUS
/* Aquarius+ video control: 4 = 320x200 1bpp bitmap, text off (40x25 cells of 8x8); 1 = text. */
static uint16_t aq_mode;

static void aq_set_mode(uint16_t m)
{
    aq_mode = m;
    console_ioctl(IOCTL_GENCON_SET_MODE, &aq_mode);
}
#endif

void plat_init(void)
{
#ifdef TARGET_Z88
    /* Font and UDG pointers first: with one set, mode 1 makes the console the graphics map. */
    plat_set_font(view_tile_art);
    plat_set_udgs(view_tile_art + NUM_TILE_ART * 8u);
    font_now = view_tile_art;
    udg_now = view_tile_art + NUM_TILE_ART * 8u;
    z88_mode = 1;
    console_ioctl(IOCTL_GENCON_SET_MODE, &z88_mode);
    z88_sop("\x01" "2-C");                 /* no cursor in the text window */
    plat_text_clear();
    clrscr();                           /* the map */
    return;
#endif
#ifdef TARGET_AQPLUS
    aq_set_mode(4);                     /* bitmap mode: the console then draws characters from its font pointers */
#endif
    clrscr();
#if defined(TILE_PRINT)
    std_font = font_now = (const uint8_t *)plat_std_font();
#if defined(TARGET_ZX)
    std_attr = _zx_console_attr;
#endif
#endif
}

void plat_exit(void)
{
#ifdef TARGET_Z88
    plat_set_font(0);
    plat_set_udgs(0);
    z88_mode = 0;                       /* text mode again, one full window */
    console_ioctl(IOCTL_GENCON_SET_MODE, &z88_mode);
    plat_text_clear();
    return;
#endif
    text_mode();
#ifdef TARGET_AQPLUS
    aq_set_mode(1);                     /* back to the text screen */
#endif
    clrscr();
}

uint8_t plat_cols(void)
{
#ifdef TARGET_Z88
    return Z88_MAP_COLS;
#else
    unsigned int x, y;
    screensize(&x, &y);
    return (uint8_t)x;
#endif
}

uint8_t plat_rows(void)
{
#ifdef TARGET_Z88
    return Z88_MAP_ROWS;
#else
    unsigned int x, y;
    screensize(&x, &y);
    return (uint8_t)y;
#endif
}

void plat_clear(void)
{
    text_mode();
    clrscr();
}

void plat_put(uint8_t col, uint8_t row, uint8_t ch)
{
#ifdef TARGET_Z88
    (void)col; (void)row; (void)ch;      /* the console is the map: it draws tiles only */
    return;
#endif
    text_mode();
    gotoxy(col, row);
    fputc_cons(ch);
}

void plat_puts(uint8_t col, uint8_t row, const char *s)
{
#ifdef TARGET_Z88
    plat_text_puts(col, row, s);        /* text belongs in OZ's text window */
    return;
#endif
    text_mode();
    gotoxy(col, row);
    while (*s)
        fputc_cons((uint8_t)*s++);
}

#ifdef TARGET_Z88
uint8_t plat_text_cols(void) { return Z88_TEXT_COLS; }
uint8_t plat_text_rows(void) { return Z88_TEXT_ROWS; }

void plat_text_clear(void)
{
    z88_sop("\x01" "2C1");               /* SOH 2 C 1: clear window 1, the text window */
}

void plat_text_puts(uint8_t col, uint8_t row, const char *s)
{
    uint8_t n = 5;

    /* position the cursor: SOH 3 @ x y (coordinates offset by 32).  NB SOH 2 C n CLEARS window n, so it
       must not be sent with each line. */
    z88_text[0] = 1; z88_text[1] = '3'; z88_text[2] = '@';
    z88_text[3] = (char)(32 + col);
    z88_text[4] = (char)(32 + row);
    while (*s && n < sizeof(z88_text) - 1)
        z88_text[n++] = *s++;
    z88_text[n] = 0;
    z88_sop(z88_text);
}
#else
uint8_t plat_text_cols(void) { return plat_cols(); }
uint8_t plat_text_rows(void) { return plat_rows(); }
void plat_text_clear(void) { plat_clear(); }
void plat_text_puts(uint8_t col, uint8_t row, const char *s) { plat_puts(col, row, s); }
#endif

#ifdef HAVE_TILES
void plat_put_tile(uint8_t col, uint8_t row, const uint8_t *art, uint8_t attr, uint8_t inverse)
{
#if defined(TILE_BLIT)
    zx_blit8(zx_cxy2saddr(col, row), art, inverse);
    *zx_cxy2aaddr(col, row) = attr;
#elif defined(TILE_PRINT)
    uint16_t n = (uint16_t)(art - view_tile_art) >> 3;      /* 0..344 */
    uint8_t ch, i;

#if defined(TARGET_ZX)
    _zx_console_attr = attr;                            /* the console prints in this colour */
#else
    (void)attr;                                         /* Aquarius+, NC200: not mapped yet */
#endif
    if (inverse) {
        for (i = 0; i < 8; ++i)
            cursor_art[i] = (uint8_t)(art[i] ^ 0xFF);
        set_udgs(cursor_art);
        ch = 128;
    } else if (n < NUM_TILE_ART) {
        set_font(view_tile_art);
        ch = (uint8_t)(32 + n);
    } else {
        n -= NUM_TILE_ART;
        set_udgs(view_tile_art + (NUM_TILE_ART + (n & ~127u)) * 8u);
        ch = (uint8_t)(128 + (n & 127));
    }
    tile_mode = 1;
    gotoxy(col, row);
    fputc_cons(ch);
#else
    (void)col; (void)row; (void)art; (void)attr; (void)inverse;
#endif
}
#endif

#ifdef HAVE_FILES
/* ---- files: OZ's, through z88dk's open, read, write and close ---- */

uint8_t plat_file_save(const char *name, const uint8_t *a, uint16_t alen, const uint8_t *b, uint16_t blen)
{
    int fd = open((char *)name, O_WRONLY, 0);
    uint8_t bad;

    if (fd < 0)
        return 1;
    bad = write(fd, (void *)a, alen) != (ssize_t)alen || write(fd, (void *)b, blen) != (ssize_t)blen;
    close(fd);
    return bad;
}

uint8_t plat_file_load(const char *name, uint8_t *a, uint16_t alen, uint8_t *b, uint16_t blen)
{
    int fd = open((char *)name, O_RDONLY, 0);
    uint8_t r = 1;

    if (fd < 0)
        return 1;
    if (read(fd, a, alen) == (ssize_t)alen)
        r = read(fd, b, blen) == (ssize_t)blen ? 0 : 2;
    close(fd);
    return r;
}
#endif

#ifdef HAVE_BITMAP
/* A picture of the game's own: the same as a tile, through the scratch UDG (or straight to the screen). */
void plat_put_bitmap(uint8_t col, uint8_t row, const uint8_t *art)
{
#if defined(TILE_BLIT)
    zx_blit8(zx_cxy2saddr(col, row), art, 0);
#elif defined(TILE_PRINT)
    uint8_t i;

    for (i = 0; i < 8; ++i)
        cursor_art[i] = art[i];
    set_udgs(cursor_art);
    tile_mode = 1;
    gotoxy(col, row);
    fputc_cons(128);
#else
    (void)col; (void)row; (void)art;
#endif
}
#endif

#ifdef TARGET_Z88
/* ---- Z88: keys and menus come from OZ ------------------------------------------------
   in_Inkey reads the keyboard matrix directly, which OZ never sees, so no menu would ever
   open.  getk() asks OZ instead.  When the user chooses a menu item OZ makes getk() call
   handlecmds() (the application's callback, set up by `#pragma redirect` in
   platform/console/zpragma_z88rom.inc) with the command code from the descriptor in
   z88_dor.c; the codes are the CMD_* of platform.h, so we queue them and return them from
   plat_key() like keys.  OZ also asks us to redraw (redrawscreen) after drawing over the
   screen.

   Keys: the cursor keys are extended keys: OS_In returns 0 and then the code, and getk() hands
   back that second code ($B1 and up; below that is a menu command).  From the Z88 Developer
   Notes ("Input and the keyboard decoder"): left $FC, right $FD, down $FE, up $FF, and with
   SHIFT $F8, $F9, $FA, $FB.  Plain cursor keys move one cell and shifted ones eight, as the
   game's o/p/q/a and O/P/Q/A do.  Letters are folded to lower case (the app may run with caps
   lock on) and the rest of the control codes except ENTER and ESC (27) are ignored, so TAB (9) does
   not move the cursor.  ENTER: getk() returns the key's CR (13) as LF (10), because the program is
   built with -Cc-standard-escape-chars, so 10 is what the ENTER key sends; it is KEY_ENTER here. */
static uint8_t cmd_queue[8];
static uint8_t cmd_head, cmd_tail;

static void queue_cmd(uint8_t cmd)
{
    uint8_t next = (uint8_t)((cmd_tail + 1) & 7);
    if (next != cmd_head) {
        cmd_queue[cmd_tail] = cmd;
        cmd_tail = next;
    }
}

void handlecmds(int cmd)
{
    queue_cmd((uint8_t)cmd);
}

void redrawscreen(void)
{
    icons_ok = 0;                       /* the user defined characters may have gone too */
    queue_cmd(CMD_REDRAW);
}

uint8_t plat_key(void)
{
    int k;
    uint8_t c;

    if (cmd_head == cmd_tail) {
        k = getk();                     /* may call handlecmds() and then return 0 */
        if (cmd_head == cmd_tail) {
            c = (uint8_t)k;
            switch (c) {
            case 0xFC: return KEY_LEFT;
            case 0xFD: return KEY_RIGHT;
            case 0xFE: return KEY_DOWN;
            case 0xFF: return KEY_UP;
            case 9: return '.';         /* TAB: the next tool (the icons show it) */
            case 0xD2: return ',';      /* SHIFT-TAB: the one before */
            case 0xF8: return KEY_FAR_LEFT;     /* shift + cursor: eight cells */
            case 0xF9: return KEY_FAR_RIGHT;
            case 0xFA: return KEY_FAR_DOWN;
            case 0xFB: return KEY_FAR_UP;
            }
            if (c == 10)                /* getk() turns the ENTER key's CR into LF (standard escape chars) */
                return KEY_ENTER;
            if (c >= 'A' && c <= 'Z')   /* the app may run with caps lock on */
                return (uint8_t)(c + 'a' - 'A');
            if (c < ' ' && c != KEY_ENTER && c != KEY_ESC)
                return 0;
            return c;
        }
    }
    c = cmd_queue[cmd_head];
    cmd_head = (uint8_t)((cmd_head + 1) & 7);
    return c;
}
#else
uint8_t plat_key(void)
{
    return (uint8_t)in_Inkey();
}
#endif

uint16_t plat_clock(void)
{
    return clock_count;
}

void plat_idle(void)
{
    ++clock_count;
}

void plat_flush(void)
{
}
