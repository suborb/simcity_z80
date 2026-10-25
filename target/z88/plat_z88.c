/* Cambridge Z88 platform: OZ text window and menus beside the generic-console map. */
#include <stdint.h>
#include <time.h>
#include <conio.h>
#include <input.h>
#include <stdio.h>
#include <sys/ioctl.h>
#include <fcntl.h>
#include "engine.h"
#include "platform.h"
#include "prompt.h"

#define Z88_TEXT_X    2                    /* the text starts 2 cells in from the bars (so a 40 column screen is in the middle of the window) */
#define Z88_TEXT_COLS 43                   /* the window is 47 wide: less the bars and the 2 */
#define Z88_TEXT_ROWS 7
#define Z88_MAP_COLS  32
#define Z88_MAP_ROWS  8
#define ICON_FIRST_CHAR 64
#define NUM_ICONS 14
#define DEMAND_FIRST  120                  /* the characters left after the icons' 56: the demand bars' 7 */

extern void z88_sop(const char *s) __z88dk_fastcall;
extern char *z88_fgets_cons(char *s, size_t n);
extern const uint8_t z88_icons[];
extern void plat_set_font(const void *p) __z88dk_fastcall;
extern void plat_set_udgs(const void *p) __z88dk_fastcall;

static uint16_t clock_count;
static uint16_t z88_mode;
uint8_t icons_ok;                       /* (the demand indicator, in plat_z88.asm, looks at it) */
static const uint8_t *font_now;
static const uint8_t *udg_now;
static uint8_t cursor_art[8];
static char z88_text[5 + Z88_TEXT_COLS + 1];
char z88_banner[] = "\x01" "7#1" "\x22" "\x20" "\x4f" "\x28" "\x83" "\x01" "2C1" "\x01" "3+TR" "\x01" "3@" "\x34" "\x20" "SIMCITY      " "\x01" "3@  " "\x01" "2A" "\x4f" "\x01" "2-R" "\x01" "2-C";
static uint8_t cmd_queue[8];
static uint8_t cmd_head, cmd_tail;

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

/* The demand indicator's cells, 6 pixels wide: the zero mark, a bar of 1 to 5 pixels from the cell's left edge.  A full cell is a
   space in reverse video, and a bar growing to the left is the bar of the other 6 - n pixels in reverse video. */
static const uint8_t demand_art[7][8] = {
    { 0x0C, 0, 0x0C, 0, 0x0C, 0, 0x0C, 0 },            /* the zero mark: dotted, so that it is not taken for the end of a bar */
    { 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20 },
    { 0x30, 0x30, 0x30, 0x30, 0x30, 0x30, 0x30, 0x30 },
    { 0x38, 0x38, 0x38, 0x38, 0x38, 0x38, 0x38, 0x38 },
    { 0x3C, 0x3C, 0x3C, 0x3C, 0x3C, 0x3C, 0x3C, 0x3C },
    { 0x3E, 0x3E, 0x3E, 0x3E, 0x3E, 0x3E, 0x3E, 0x3E },
    { 0, 0, 0, 0, 0x3F, 0, 0, 0 },                      /* the track, in a cell with no bar */
};

void define_icons(void)
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
    for (c = 0; c < 7; ++c) {                           /* the demand bars' cells */
        d[3] = (char)(DEMAND_FIRST + c);
        for (r = 0; r < 8; ++r)
            d[4 + r] = (char)(demand_art[c][r] | 0x80);
        z88_sop(d);
    }
    icons_ok = 1;
}

void plat_init(void)
{
    plat_set_font(view_tile_art);
    plat_set_udgs(view_tile_art + NUM_TILE_ART * 8u);
    font_now = view_tile_art;
    udg_now = view_tile_art + NUM_TILE_ART * 8u;
    z88_mode = 1;
    console_ioctl(IOCTL_GENCON_SET_MODE, &z88_mode);
    z88_sop("\x01" "2-C");
    plat_text_clear();
    clrscr();
}

void plat_exit(void)
{
    plat_set_font(0);
    plat_set_udgs(0);
    z88_mode = 0;
    console_ioctl(IOCTL_GENCON_SET_MODE, &z88_mode);
    plat_text_clear();
}

uint8_t plat_cols(void) { return Z88_MAP_COLS; }
uint8_t plat_rows(void) { return Z88_MAP_ROWS; }
void plat_clear(void) { clrscr(); }
void plat_put(uint8_t col, uint8_t row, uint8_t ch) { (void)col; (void)row; (void)ch; }
void plat_puts(uint8_t col, uint8_t row, const char *s) { plat_text_puts(col, row, s); }

uint8_t plat_text_cols(void) { return Z88_TEXT_COLS; }
uint8_t plat_text_rows(void) { return Z88_TEXT_ROWS; }
/* The text window is one OZ window (1): 47 x 8 at column 2, centred on the 51 columns, with OZ's bars (type 131).  Its first row is the
   city name, reverse and centred; the text is in the 7 rows below, inside the bars, and in OZ's tiny font (plat_text_puts(),
   plat_icons() and plat_demand() add the offset).  Clearing the window is defining it again (with bit 7 of the type it is cleared) and
   drawing the banner. */
void plat_text_clear(void)
{
    z88_sop(z88_banner);
}

void plat_text_puts(uint8_t col, uint8_t row, const char *s)
{
    uint8_t n = 5;

    z88_text[0] = 1; z88_text[1] = '3'; z88_text[2] = '@';
    z88_text[3] = (char)(32 + 1 + Z88_TEXT_X + col);    /* inside the bars, below the title */
    z88_text[4] = (char)(32 + 1 + row);
    while (*s && n < sizeof(z88_text) - 1) {
        z88_text[n] = *s;
        ++n;
        ++s;
    }
    z88_text[n] = 0;
    z88_sop(z88_text);
}

void plat_text_bold(uint8_t col, uint8_t row, const char *s)
{
    z88_sop("\x01" "2+B");
    plat_text_puts(col, row, s);
    z88_sop("\x01" "2-B");
}

void plat_put_tile(uint8_t col, uint8_t row, const uint8_t *art, uint8_t attr, uint8_t inverse)
{
    uint16_t n = (uint16_t)(art - view_tile_art) >> 3;
    uint8_t ch, i;

    (void)attr;
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
    gotoxy(col, row);
    fputc_cons(ch);
}

void plat_put_bitmap(uint8_t col, uint8_t row, const uint8_t *art)
{
    uint8_t i;

    for (i = 0; i < 8; ++i)
        cursor_art[i] = art[i];
    set_udgs(cursor_art);
    gotoxy(col, row);
    fputc_cons(128);
}

uint8_t plat_text_input(uint8_t col, uint8_t row, char *buf, uint8_t max, uint8_t spaces)
{
    char *r;
    uint8_t n;

    (void)spaces;
    for (n = 0; n < max && city_name[n]; ++n)
        buf[n] = city_name[n];
    buf[n] = 0;
    plat_text_puts(col, row, "");
    z88_sop("\x01" "2+C");
    r = z88_fgets_cons(buf, (size_t)max + 1);
    z88_sop("\x01" "2-C");
    for (n = 0; buf[n]; ++n)
        ;
    while (n && (uint8_t)buf[n - 1] < ' ')
        buf[--n] = 0;
    return r != 0 && n != 0;
}

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

static void queue_cmd(uint8_t cmd)
{
    uint8_t next = (uint8_t)(cmd_tail + 1) & 7;
    if (next != cmd_head) {
        cmd_queue[cmd_tail] = cmd;
        cmd_tail = next;
    }
}

void handlecmds(int cmd) { queue_cmd((uint8_t)cmd); }
void redrawscreen(void) { icons_ok = 0; queue_cmd(CMD_REDRAW); }

uint8_t plat_key(void)
{
    int k;
    uint8_t c;

    if (cmd_head == cmd_tail) {
        k = getk();
        if (cmd_head == cmd_tail) {
            c = (uint8_t)k;
            switch (c) {
            case 0xFC: return KEY_LEFT;
            case 0xFD: return KEY_RIGHT;
            case 0xFE: return KEY_DOWN;
            case 0xFF: return KEY_UP;
            case 9: return '.';
            case 0xD2: return ',';
            case 0xF8: return KEY_FAR_LEFT;
            case 0xF9: return KEY_FAR_RIGHT;
            case 0xFA: return KEY_FAR_DOWN;
            case 0xFB: return KEY_FAR_UP;
            }
            if (c == 10)
                return KEY_ENTER;
            if (c >= 'A' && c <= 'Z')
                return c == 'Q' || c == 'A' || c == 'O' || c == 'P' ? c : (uint8_t)(c + 'a' - 'A');      /* (shifted QAOP: 8 cells) */
            if (c < ' ' && c != KEY_ENTER && c != KEY_ESC)
                return 0;
            return c;
        }
    }
    c = cmd_queue[cmd_head];
    cmd_head = (uint8_t)(cmd_head + 1) & 7;
    return c;
}

uint16_t plat_clock(void) { return (uint16_t)clock() ^ clock_count; }
void plat_idle(void) { ++clock_count; }
void plat_flush(void) {}
