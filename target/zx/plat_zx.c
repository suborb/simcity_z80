/* ZX Spectrum platform: direct 8x8 tile blits, or console-character tiles with ZX_PRINT. */
#include <stdint.h>
#include <time.h>
#include <conio.h>
#include <input.h>
#include <arch/zx.h>
#include "engine.h"
#include "platform.h"

static uint16_t clock_count;
extern void zx_blit8(uint8_t *screen, const uint8_t *art, uint8_t inverse) __smallc;

#ifdef ZX_PRINT
extern uint8_t _zx_console_attr;
extern void *plat_std_font(void);
extern void plat_set_font(const void *p) __z88dk_fastcall;
extern void plat_set_udgs(const void *p) __z88dk_fastcall;

static const uint8_t *std_font;
static const uint8_t *font_now;
static const uint8_t *udg_now;
static uint8_t std_attr;
static uint8_t tile_mode;
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

static void text_mode(void)
{
    if (tile_mode) {
        set_font(std_font);
        _zx_console_attr = std_attr;
        tile_mode = 0;
    }
}
#else
#define text_mode()
#endif

void plat_init(void)
{
    clrscr();
#ifdef ZX_PRINT
    std_font = font_now = (const uint8_t *)plat_std_font();
    std_attr = _zx_console_attr;
#endif
}

void plat_exit(void) { text_mode(); clrscr(); }

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

void plat_clear(void) { text_mode(); clrscr(); }

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

uint8_t plat_text_cols(void) { return plat_cols(); }
uint8_t plat_text_rows(void) { return plat_rows(); }
void plat_text_clear(void) { plat_clear(); }
void plat_text_puts(uint8_t col, uint8_t row, const char *s) { plat_puts(col, row, s); }

void plat_put_tile(uint8_t col, uint8_t row, const uint8_t *art, uint8_t attr, uint8_t inverse)
{
#ifndef ZX_PRINT
    zx_blit8(zx_cxy2saddr(col, row), art, inverse);
    *zx_cxy2aaddr(col, row) = attr;
#else
    uint16_t n = (uint16_t)(art - view_tile_art) >> 3;
    uint8_t ch, i;

    _zx_console_attr = attr;
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
#endif
}

void plat_put_bitmap(uint8_t col, uint8_t row, const uint8_t *art)
{
#ifndef ZX_PRINT
    zx_blit8(zx_cxy2saddr(col, row), art, 0);
#else
    uint8_t i;

    for (i = 0; i < 8; ++i)
        cursor_art[i] = art[i];
    set_udgs(cursor_art);
    tile_mode = 1;
    gotoxy(col, row);
    fputc_cons(128);
#endif
}

uint8_t plat_key(void) { return (uint8_t)in_Inkey(); }
uint16_t plat_clock(void) { return (uint16_t)clock() ^ clock_count; }
void plat_idle(void) { ++clock_count; }
void plat_flush(void) {}
