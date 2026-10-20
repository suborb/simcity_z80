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

#define Z88_TEXT_COLS 51
#define Z88_TEXT_ROWS 8
#define Z88_MAP_COLS  32
#define Z88_MAP_ROWS  8
#define ICON_FIRST_CHAR 64
#define NUM_ICONS 14

extern void z88_sop(const char *s) __z88dk_fastcall;
extern const uint8_t z88_icons[];
extern void plat_set_font(const void *p) __z88dk_fastcall;
extern void plat_set_udgs(const void *p) __z88dk_fastcall;

static uint16_t clock_count;
static uint16_t z88_mode;
static uint8_t icons_ok;
static const uint8_t *font_now;
static const uint8_t *udg_now;
static uint8_t cursor_art[8];
static char z88_text[5 + Z88_TEXT_COLS + 1];
static char icon_text[5 + NUM_ICONS * 12 + 1];
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

void plat_icons(uint8_t selected)
{
    uint8_t i, r, n;
    char c;

    if (!icons_ok)
        define_icons();
    for (r = 0; r < 2; ++r) {
        icon_text[0] = 1; icon_text[1] = '3'; icon_text[2] = '@';
        icon_text[3] = 32;
        icon_text[4] = (char)(32 + 3 + r);
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
void plat_text_clear(void) { z88_sop("\x01" "2C1"); }

void plat_text_puts(uint8_t col, uint8_t row, const char *s)
{
    uint8_t n = 5;

    z88_text[0] = 1; z88_text[1] = '3'; z88_text[2] = '@';
    z88_text[3] = (char)(32 + col);
    z88_text[4] = (char)(32 + row);
    while (*s && n < sizeof(z88_text) - 1)
        z88_text[n++] = *s++;
    z88_text[n] = 0;
    z88_sop(z88_text);
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
    plat_text_puts(col, row, "");
    z88_sop("\x01" "2+C");
    buf[0] = 0;
    r = fgets_cons(buf, (size_t)max + 1);
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
                return (uint8_t)(c + 'a' - 'A');
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
