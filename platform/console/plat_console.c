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
   ------------------------------------------------------------------------ */
#include <stdint.h>
#include <conio.h>
#include <input.h>
#include <stdio.h>
#include <sys/ioctl.h>
#include "engine.h"
#include "platform.h"

static uint16_t clock_count;

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
    text_mode();
#ifdef TARGET_AQPLUS
    aq_set_mode(1);                     /* back to the text screen */
#endif
    clrscr();
}

uint8_t plat_cols(void)
{
    unsigned int x, y;
    screensize(&x, &y);
    return (uint8_t)x;
}

uint8_t plat_rows(void)
{
    unsigned int x, y;
    screensize(&x, &y);
    return (uint8_t)y;
}

void plat_clear(void)
{
    text_mode();
    clrscr();
}

void plat_put(uint8_t col, uint8_t row, uint8_t ch)
{
    text_mode();
    gotoxy(col, row);
    fputc_cons(ch);
}

void plat_puts(uint8_t col, uint8_t row, const char *s)
{
    text_mode();
    gotoxy(col, row);
    while (*s)
        fputc_cons((uint8_t)*s++);
}

uint8_t plat_has_tiles(void)
{
#ifdef HAVE_TILES
    return 1;
#else
    return 0;
#endif
}

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
            cursor_art[i] = (uint8_t)~art[i];
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
   lock on) and the rest of the control codes except ENTER (13) and ESC (27) are ignored, so
   TAB (9) and LF (10) do not move the cursor. */
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
            case 0xF8: return 'O';      /* shift + cursor: eight cells */
            case 0xF9: return 'P';
            case 0xFA: return 'A';
            case 0xFB: return 'Q';
            }
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
