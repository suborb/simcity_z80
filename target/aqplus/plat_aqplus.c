/* Aquarius+ platform: 320x200 bitmap tiles and text, drawn by the placer in plat_aqplus.asm, which also sets the
   video mode and clears the screen: nothing of z88dk's console is used. */
#include <stdint.h>
#include <input.h>
#include "engine.h"
#include "platform.h"
#ifdef HAVE_FILES
#include <fcntl.h>
#endif

static uint16_t clock_count;
static uint8_t key_held;

/* Colours are the Aquarius+'s own colour bytes (ink << 4 | paper, palette entries; see tools/make_aq_assets.py):
   the tile and icon tables are converted when the game is built, so nothing is converted while drawing. */
#define WHITE_ON_BLACK  0x80            /* light grey ink */

/* target/aqplus/plat_aqplus.asm: aq_blit8 is plat_put_tile as well (the tile attributes are colour bytes) */
extern void aq_blit8(uint8_t col, uint8_t row, const uint8_t *art, uint8_t colour, uint8_t inverse) __smallc;
extern void plat_aq_printc(uint8_t col, uint8_t row, uint8_t ch) __smallc;    /* the same as plat_put */
extern const uint8_t aq_icons[];

/* plat_init, plat_exit, plat_clear, plat_put and plat_puts are in the assembler too */

#ifdef HAVE_TEXT_COLOUR
extern void aq_colours(uint8_t col, uint8_t row, uint8_t n, uint8_t colour) __smallc;

/* The palette entry of each of the game's colours (Spectrum order: black, blue, red, magenta, green, cyan, yellow, white), the bright ones
   (tools/make_aq_assets.py) */
static const uint8_t aq_pal[8] = { 0, 4, 1, 5, 2, 6, 3, 7 };

/* Colours text already drawn: only the colour bytes change, as a glyph's pixels are the ink */
void plat_text_attr(uint8_t col, uint8_t row, uint8_t n, uint8_t attr)
{
    aq_colours(col, row, n, (uint8_t)(aq_pal[attr & 7] << 4 | aq_pal[(attr >> 3) & 7]));
}

/* A bar of n cells, the first `fill` pixels (8 to a cell) in the ink of attr, the rest the track: dark grey.  The cell's own two colours do it
   (ink on a dark grey paper), the picture being the filled pixels of its middle six lines. */
void plat_bar(uint8_t col, uint8_t row, uint8_t cells, uint8_t fill, uint8_t attr)
{
    uint8_t i, k, bits, a[8], colour = (uint8_t)(aq_pal[attr & 7] << 4 | 15);
    int16_t px;

    for (i = 0; i < cells; ++i) {
        px = (int16_t)fill - 8 * i;
        bits = px >= 8 ? 0xFF : px <= 0 ? 0 : (uint8_t)(0xFF << (8 - px));
        for (k = 0; k < 8; ++k)
            a[k] = (k && k < 7) ? bits : 0;
        aq_blit8((uint8_t)(col + i), row, a, colour, 0);
    }
}
#endif

void plat_text_clear(void) { plat_clear(); }
void plat_text_puts(uint8_t col, uint8_t row, const char *s) { plat_puts(col, row, s); }

void plat_put_bitmap(uint8_t col, uint8_t row, const uint8_t *art)
{
    aq_blit8(col, row, art, WHITE_ON_BLACK, 0);
}

#ifdef HAVE_MINIMAP_COLOUR
/* The original minimap uses an eight-step intensity ramp with equal ink and paper (Spectrum bright colours 0x49,
   0x52, ..., 0x7f); a solid cell of these Aquarius+ colours: blue, red, magenta, green, cyan, yellow, white. */
static const uint8_t minimap_colours[8] = { WHITE_ON_BLACK, 0x44, 0x11, 0x55, 0x22, 0x66, 0x33, 0x77 };

void plat_put_minimap(uint8_t col, uint8_t row, const uint8_t *art,
                      uint8_t view, uint8_t level)
{
    uint8_t colour = WHITE_ON_BLACK;          /* stable white city silhouette */

    /* Density and coverage levels are 0..16 and 0..15 respectively, so halve them to get the 0..7 ramp index. */
    if (view != 1) {
        level >>= 1;
        if (level > 7)
            level = 7;
        colour = minimap_colours[level];
    }
    aq_blit8(col, row, art, colour, 0);
}
#endif

/* The tool icons: 16x16 pictures, four cells each. */
#define NUM_ICONS 14

/* the tools there is the money for, bit i for tool i (plat_afford): the icons of the others are thinned to a checkerboard
   (each byte of the picture AND %01010101 on the even rows and %10101010 on the odd ones) */
static uint16_t afford = 0xFFFF;

void plat_afford(uint16_t mask)
{
    afford = mask;
}

void plat_icons(uint8_t selected)
{
    uint8_t i, r, c, cell, k;
    const uint8_t *art;
    uint8_t thin[8];

    for (i = 0; i < NUM_ICONS; ++i)
        for (r = 0; r < 2; ++r)
            for (c = 0; c < 2; ++c) {
                cell = (uint8_t)(i * 4 + r * 2 + c);
                art = aq_icons + cell * 8;
                if (!((afford >> i) & 1)) {
                    for (k = 0; k < 8; ++k)
                        thin[k] = art[k] & ((k & 1) ? 0xAA : 0x55);
                    art = thin;
                }
                aq_blit8((uint8_t)(i * 2 + c), (uint8_t)(1 + r), art, aq_icons[NUM_ICONS * 32 + cell], i == selected);
            }
}

/* in_Inkey() reports the matrix state every poll.  The game and especially its pop-up
   menus run much faster than a human key press, so turn that level into one event until
   the key is released. */
uint8_t plat_key(void)
{
    uint8_t k = (uint8_t)in_Inkey();

    if (!k) {
        key_held = 0;
        return 0;
    }
    if (key_held == k)
        return 0;
    key_held = k;
    return k;
}

#ifdef HAVE_FILES
/* A tiny editor for file names.  This deliberately uses the game console rather
   than fgets_cons: the latter brings in a complete generic console editor, while
   this target already has keyboard polling and a character writer. */
uint8_t plat_text_input(uint8_t col, uint8_t row, char *buf, uint8_t max, uint8_t spaces)
{
    uint8_t n = 0, k;

    buf[0] = 0;
    for (;;) {
        k = plat_key();
        if (!k) {
            plat_idle();
            continue;
        }
        if (k == KEY_ENTER)
            return n != 0;
        if (k == KEY_ESC)
            return 0;
        if ((k == KEY_LEFT || k == 127) && n) {
            --n;
            plat_aq_printc((uint8_t)(col + n), row, ' ');
        } else if (k >= (spaces ? ' ' : '!') && k < 127 && n < max) {
            buf[n] = (char)k;
            plat_aq_printc((uint8_t)(col + n), row, k);
            ++n;
            buf[n] = 0;
        }
    }
}

uint8_t plat_file_save(const char *name, const uint8_t *a, uint16_t alen, const uint8_t *b, uint16_t blen)
{
    int fd = open(name, O_WRONLY | O_CREAT | O_TRUNC, 0);
    uint8_t bad;

    if ((uint8_t)fd >= 0xF0)             /* Aquarius+ ESP error codes are $F7..$FF */
        return 1;
    bad = write(fd, (void *)a, alen) != (ssize_t)alen ||
          write(fd, (void *)b, blen) != (ssize_t)blen;
    close(fd);
    return bad;
}

uint8_t plat_file_load(const char *name, uint8_t *a, uint16_t alen, uint8_t *b, uint16_t blen)
{
    int fd = open(name, O_RDONLY, 0);
    uint8_t r = 1;

    if ((uint8_t)fd >= 0xF0)
        return 1;
    if (read(fd, a, alen) == (ssize_t)alen)
        r = read(fd, b, blen) == (ssize_t)blen ? 0 : 2;
    close(fd);
    return r;
}
#endif

uint16_t plat_clock(void) { return clock_count; }
void plat_idle(void) { ++clock_count; }
void plat_flush(void) {}
