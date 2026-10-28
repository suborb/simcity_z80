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

/* The 4bpp mini map's sidebar is on the text layer (the font is in the character RAM from 160, ASCII + 128; the pictures from 128): the cells here,
   the colour bytes ink << 4 | paper of the text palette (plat_aqplus.asm) */
extern uint8_t aq_mm4;                  /* the mini map's mode is on */
extern uint8_t aq_mm_want;              /* a mini map is up */
extern void aq_mm_enter(void);
extern void aq_mm_leave(void);
extern void aq_tcell(uint8_t col, uint8_t row, uint8_t ch, uint8_t colour) __smallc;
extern void aq_defchar(uint8_t ch, const uint8_t *art) __smallc;
#define MM_CH_SOLID 128                 /* a solid cell */
#define MM_CH_BAR   130                 /* seven cells for each of the demand bars (rows mod 3) */

static void tcells(uint8_t col, uint8_t row, const char *s, uint8_t colour)
{
    uint8_t c;

    while ((c = (uint8_t)*s++) != 0) {
        aq_tcell(col++, row, c >= 32 && c < 128 ? (uint8_t)(c + 128) : 160, colour);
    }
}
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

#if defined(HAVE_DEMAND_BARS) && !defined(HAVE_TEXT_COLOUR)
#error "the demand bars use the colour screens' palette (HAVE_TEXT_COLOUR)"
#endif

#ifdef HAVE_DEMAND_BARS
/* A demand indicator: the letter, then seven cells of 8 pixels with the zero mark at pixel 27 and `level` pixels (the zones, +-27) of
   green to its right or red to its left, ink on the dark grey track.  A cell has two colours, so the zero mark is a white line only
   when the demand is nothing; otherwise the fill starting next to it shows where it is. */
void plat_demand(uint8_t col, uint8_t row, char name, int8_t level)
{
    uint8_t k, b, bits, a[8], colour;
    int16_t x;

    if (aq_mm4) {                       /* on the text layer: the bar's cells are characters redefined each time */
        char s[2];
        uint8_t ch = (uint8_t)(MM_CH_BAR + row % 3 * 7);

        s[0] = name;
        s[1] = 0;
        tcells(col, row, s, 0x70);
        colour = (uint8_t)(aq_pal[level > 0 ? COL_GREEN : level < 0 ? COL_RED : COL_WHITE] << 4 | 15);
        for (k = 0; k < 7; ++k) {
            bits = 0;
            for (b = 0; b < 8; ++b) {
                x = 8 * k + b;
                if (level == 0 ? x == 27 : (level > 0 ? x > 27 && x <= 27 + level : x < 27 && x >= 27 + level))
                    bits |= (uint8_t)(0x80 >> b);
            }
            for (b = 0; b < 8; ++b)
                a[b] = (b && b < 7) ? bits : 0;
            aq_defchar((uint8_t)(ch + k), a);
            aq_tcell((uint8_t)(col + 1 + k), row, (uint8_t)(ch + k), colour);
        }
        return;
    }
    plat_put(col, row, (uint8_t)name);
    colour = (uint8_t)(aq_pal[level > 0 ? COL_GREEN : level < 0 ? COL_RED : COL_WHITE] << 4 | 15);
    for (k = 0; k < 7; ++k) {
        bits = 0;
        for (b = 0; b < 8; ++b) {
            x = 8 * k + b;
            if (level == 0 ? x == 27 : (level > 0 ? x > 27 && x <= 27 + level : x < 27 && x >= 27 + level))
                bits |= (uint8_t)(0x80 >> b);
        }
        for (b = 0; b < 8; ++b)
            a[b] = (b && b < 7) ? bits : 0;
        aq_blit8((uint8_t)(col + 1 + k), row, a, colour, 0);
    }
}
#endif

void plat_text_clear(void) { plat_clear(); }
void plat_text_puts(uint8_t col, uint8_t row, const char *s)
{
    if (aq_mm4)
        tcells(col, row, s, 0x70);
    else
        plat_puts(col, row, s);
}

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
#ifdef HAVE_POINTER
uint8_t plat_keyboard_key(void)                 /* (target/common/pointer.c makes plat_key and plat_key_game of it) */
#else
uint8_t plat_key(void)
#endif
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
#ifdef HAVE_SOUND
extern void ay_poll(void);                          /* a tick of the sound if a frame has begun */
void plat_idle(void) { ++clock_count; ay_poll(); }
#else
void plat_idle(void) { ++clock_count; }
#endif
void plat_flush(void) {}

#ifdef HAVE_MINIMAP_SQUARE
/* The square mini maps (as the SAM Coupe's page, the picture 24 cells wide at MM_PIC_COL and the sidebar after it): the whole city in the 160x200 4bpp
   bitmap, where a tile is one pixel by two lines (2x2 display pixels) in a colour of its own.  plat_put_minirow() gets the 96 colours of a row of
   tiles (0..7 as ui/minimap.c's builder makes them: dirt 0, water 1, services 2, industry 3, trees 4, housing 5, shops 6, roads and the like 7) and
   looks each up in the view's table of palette entries (the bitmap's palette is the 1bpp screen's: aq_colours[] of tools/make_aq_assets.py).  A
   density is the same ramp of seven colours the key shows, and where it is none the city shows through, dim. */
#define MM_COL0 8                       /* the picture's first byte in a line (display pixel 32, two to a byte) */
extern void aq_vcopy(uint16_t offset, const uint8_t *src, uint8_t n) __smallc;
extern uint8_t aq_mm_buf[72];

static const uint8_t mm_city[8]  = { 0, 4, 7, 3, 15, 13, 6, 8 };       /* dirt black, water blue, services white, industry yellow, trees dark grey, housing light green, shops cyan, roads light grey */
static const uint8_t mm_power[8] = { 0, 9, 1, 15, 0, 15, 3, 15 };      /* a building without power red, powered yellow, other things dark grey, water teal */
static const uint8_t mm_trans[8] = { 0, 9, 15, 15, 0, 15, 15, 7 };     /* roads white */
static const uint8_t mm_dim[8]   = { 0, 9, 15, 15, 0, 15, 15, 8 };     /* what shows through where a density is none */
static const uint8_t mm_ramp[8]  = { 0, 11, 4, 6, 2, 3, 5, 1 };        /* from none to the most: dark blue, blue, cyan, green, yellow, magenta, red */

void plat_minimap_mode(uint8_t on)
{
    static const uint8_t solid[8] = { 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF };

    aq_mm_want = on;
    if (on) {
        if (!aq_mm4) {
            aq_mm_enter();
            aq_defchar(MM_CH_SOLID, solid);
        }
    } else if (aq_mm4)
        aq_mm_leave();
}

void plat_put_minirow(uint8_t ty, const uint8_t *colours, const uint8_t *base, uint8_t view)
{
    const uint8_t *tab = view == 1 ? mm_city : view == 6 ? mm_power : view == 7 ? mm_trans : mm_ramp;
    uint8_t i, a, b, dens;
    uint16_t off = (uint16_t)ty * 160 + MM_COL0;

    dens = view != 1 && view != 6 && view != 7;

    if (!aq_mm4) {                      /* (a dialogue left the mode) */
        aq_mm_want = 1;
        plat_minimap_mode(1);
    }
    for (i = 0; i < 48; ++i) {
        a = colours[0] & 7;
        b = colours[1] & 7;
        colours += 2;
        if (dens) {
            a = a ? mm_ramp[a] : base ? mm_dim[base[0] & 7] : 0;
            b = b ? mm_ramp[b] : base ? mm_dim[base[1] & 7] : 0;
            if (base)
                base += 2;
        } else {
            a = tab[a];
            b = tab[b];
        }
        aq_mm_buf[i] = (uint8_t)(a << 4 | b);
    }
    aq_vcopy(off, aq_mm_buf, 48);
    aq_vcopy((uint16_t)(off + 80), aq_mm_buf, 48);
}

/* The key in the sidebar's rows 6 to 14 (columns MM_SIDE_COL up, to the edge: 12): a cell of the colour and what it is, in full. */
static void key_cell(uint8_t row, uint8_t colour, const char *label)
{
    aq_tcell(MM_SIDE_COL, row, MM_CH_SOLID, (uint8_t)(colour << 4));
    tcells((uint8_t)(MM_SIDE_COL + 1), row, label, 0x70);
}

void plat_minimap_key(uint8_t view)
{
    uint8_t i;

    for (i = 6; i < 16; ++i)
        tcells(MM_SIDE_COL, i, "            ", 0x70);
    switch (view) {
    case 1:
        key_cell(6, mm_city[5], "HOUSES");
        key_cell(7, mm_city[6], "SHOPS");
        key_cell(8, mm_city[3], "INDUSTRY");
        key_cell(9, mm_city[2], "SERVICES");
        key_cell(10, mm_city[7], "ROAD");
        key_cell(11, mm_city[1], "WATER");
        key_cell(12, mm_city[4], "TREES");
        break;
    case 6:
        key_cell(6, 3, "POWER");
        key_cell(7, 1, "NO PWR");
        key_cell(8, 15, "BUILT");
        key_cell(9, mm_power[1], "WATER");
        break;
    case 7:
        key_cell(6, 7, "ROAD");
        key_cell(7, 15, "BUILT");
        key_cell(8, mm_trans[1], "WATER");
        break;
    default:                                /* a density: none (the city, dim), the levels, the most */
        tcells(MM_SIDE_COL, 6, "LOW", 0x70);
        for (i = 1; i < 8; ++i)
            aq_tcell(MM_SIDE_COL, (uint8_t)(6 + i), MM_CH_SOLID, (uint8_t)(mm_ramp[i] << 4));
        tcells(MM_SIDE_COL, 14, "HIGH", 0x70);
        break;
    }
}
#endif
