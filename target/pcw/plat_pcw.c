/* Amstrad PCW platform: the 45x32 grid of 16x8 pixel cells (target/pcw/plat_pcw.asm draws them).  A tile's 8x8 pixels are drawn twice across, since the PCW's pixels are
   about twice as tall as they are wide.  The text is the 8x8 font the same way. */
#include <stdint.h>
#include "platform.h"
#include "engine.h"
#include <string.h>

extern void pcw_init(void);
extern void pcw_put(uint16_t colrow) __z88dk_fastcall;
extern const uint8_t *pcw_art;
extern uint8_t pcw_xor;
extern void pcw_clear(void);
extern void pcw_move(uint16_t dst) __z88dk_fastcall;
extern uint16_t pcw_mv_src, pcw_mv_len;
extern uint16_t pcw_rows[32];
extern void pcw_invert(uint16_t colrow) __z88dk_fastcall;
extern uint8_t pcw_invert_n;
extern uint8_t pcw_cellbuf[16];
extern void pcw_blit(uint16_t colrow) __z88dk_fastcall;
extern void cpm_print(const char *s) __z88dk_fastcall;

#define CELL(col, row) ((uint16_t)(((row) << 8) | (col)))

/* A nibble with each bit drawn twice: the left (high) four pixels of a source byte are the left column's byte, the low four the right column's. */
static const uint8_t twice[16] = {
    0x00, 0x03, 0x0C, 0x0F, 0x30, 0x33, 0x3C, 0x3F, 0xC0, 0xC3, 0xCC, 0xCF, 0xF0, 0xF3, 0xFC, 0xFF
};

extern const uint8_t pcw_font[];                /* (the SPC-1000's 8x8 font, characters 32 to 96: target/pcw/plat_pcw_font.asm) */

/* Two 256 byte tables for pcw_put (target/pcw/plat_pcw.asm): a source byte's high four pixels drawn twice (the left column's byte) and its low four (the right's). */
#ifndef PCW_TABLES
#define PCW_TABLES ((uint8_t *)0xF200)          /* (common memory above the program: the TPA is 61K) */
#endif

/* What each cell of the map is showing, so that drawing a tile that is there already costs nothing: the tile's picture (and whether it is inverted) as plat_put_tile() was
   given it, or 0 for what it does not know (text, a sprite, a bitmap, a cleared screen).  The panel's six rows are not the map's. */
#define MAP_ROW   6
#define MAP_ROWS  26
#define MAP_COLS  40
#ifndef PCW_NO_CACHE
static uint16_t tcache[MAP_ROWS][MAP_COLS];
#define FORGET(col, row)    do { if ((row) >= MAP_ROW) tcache[(row) - MAP_ROW][col] = 0; } while (0)
#else
#define FORGET(col, row)
#endif

static void put_art(uint8_t col, uint8_t row, const uint8_t *art, uint8_t xor)
{
    pcw_art = art;
    pcw_xor = xor;
    pcw_put(CELL(col, row));
}

void plat_init(void)
{
    uint16_t b;
    uint8_t *t = PCW_TABLES;

    for (b = 0; b < 256; ++b) {
        t[b] = twice[b >> 4];
        t[256 + b] = twice[b & 15];
    }
    cpm_print("\x1b" "f" "\x1b" "E$");                /* hide the cursor, clear the screen (the roller RAM is the system's again after this) */
    pcw_init();
}

void plat_exit(void)
{
    pcw_clear();
    cpm_print("\x1b" "e" "\x1b" "E$");               /* the cursor back, a clear screen */
}

static void forget_all(void)
{
#ifndef PCW_NO_CACHE
    memset(tcache, 0, sizeof(tcache));
#endif
}

void plat_clear(void) { pcw_clear(); forget_all(); }
void plat_flush(void) { }

/* The frame's line pieces (codes 1 to 6, see BOX_TOP in plat_config.h): lines through the middle of the cell, two lines thick across, 2 pixels (4 doubled) down. */
static const uint8_t box_art[6][8] = {
    { 0x00, 0x00, 0x00, 0x1F, 0x1F, 0x18, 0x18, 0x18 },     /* top left */
    { 0x00, 0x00, 0x00, 0xF8, 0xF8, 0x18, 0x18, 0x18 },     /* top right */
    { 0x18, 0x18, 0x18, 0x1F, 0x1F, 0x00, 0x00, 0x00 },     /* bottom left */
    { 0x18, 0x18, 0x18, 0xF8, 0xF8, 0x00, 0x00, 0x00 },     /* bottom right */
    { 0x00, 0x00, 0x00, 0xFF, 0xFF, 0x00, 0x00, 0x00 },     /* across */
    { 0x18, 0x18, 0x18, 0x18, 0x18, 0x18, 0x18, 0x18 },     /* down */
};

void plat_put(uint8_t col, uint8_t row, uint8_t ch)
{
    FORGET(col, row);
    if (ch >= 1 && ch <= 6) {
        put_art(col, row, box_art[ch - 1], 0);
        return;
    }
    if (ch >= 'a' && ch <= 'z')                     /* (the font has the capitals and the signs: 32 to 96) */
        ch = (uint8_t)(ch - 32);
    if (ch < 32 || ch > 96)
        ch = ' ';
    put_art(col, row, pcw_font + ((ch - 32) << 3), 0);
}

void plat_puts(uint8_t col, uint8_t row, const char *s)
{
    while (*s)
        plat_put(col++, row, (uint8_t)*s++);
}

void plat_text_puts(uint8_t col, uint8_t row, const char *s) { plat_puts(col, row, s); }
void plat_text_clear(void) { pcw_clear(); forget_all(); }

void plat_put_tile(uint8_t col, uint8_t row, const uint8_t *art, uint8_t attr, uint8_t inverse)
{
    uint16_t key;

    (void)attr;
    key = (uint16_t)art ^ (inverse ? 0x8000 : 0);
#ifndef PCW_NO_CACHE
    if (row >= MAP_ROW) {
        if (tcache[row - MAP_ROW][col] == key)
            return;
        tcache[row - MAP_ROW][col] = key;
    }
#endif
    put_art(col, row, art, inverse ? 0 : 0xFF);          /* the map is drawn inverse: the cursor's cell is the tile as it is */
}

/* (the map is inverse, so are the sprites, which are drawn ORed with the tile's picture, and the mini maps) */
void plat_put_bitmap(uint8_t col, uint8_t row, const uint8_t *art) { FORGET(col, row); put_art(col, row, art, 0xFF); }

/* ---- tool icons ----------------------------------------------------------------------------------------------------------------- */
/* The Spectrum's 16x16 pictures as four cells (2 across): the one of the selected tool inverted, the ones there is no money for thinned to a checkerboard. */
extern const uint8_t pcw_icons[];
static uint16_t afford = 0xFFFF;

void plat_afford(uint16_t mask) { afford = mask; }

void plat_icons(uint8_t selected)
{
    uint8_t i, q, k, m;
    uint8_t a[8];
    const uint8_t *src;

    for (i = 0; i < 14; ++i)
        for (q = 0; q < 4; ++q) {
            src = pcw_icons + (uint16_t)(i * 4 + q) * 8;
            for (k = 0; k < 8; ++k) {
                m = ((afford >> i) & 1) ? 0xFF : (k & 1) ? 0xAA : 0x55;
                a[k] = src[k] & m;
            }
            put_art((uint8_t)(i * 2 + (q & 1)), (uint8_t)(1 + (q >> 1)), a, i == selected ? 0xFF : 0);
        }
}

/* ---- shades --------------------------------------------------------------------------------------------------------------------- */
/* No colour: a table's selected line (the attribute has a paper) is inverted, and a bar is filled with a dither the colour chooses (green solid, yellow
   three quarters, red a half, anything else a quarter).  The track of a bar is a sparse dither. */
void plat_text_attr(uint8_t col, uint8_t row, uint8_t n, uint8_t attr)
{
    if (attr & 0x38) {
        uint8_t i;

        for (i = 0; i < n; ++i)
            FORGET(col + i, row);
        pcw_invert_n = n;
        pcw_invert(CELL(col, row));
    }
}

static uint8_t shade(uint8_t colour, uint8_t line)
{
    switch (colour) {
    case COL_GREEN:  return 0xFF;
    case COL_YELLOW: return (line & 1) ? 0xBB : 0xEE;
    case COL_RED:    return (line & 1) ? 0x55 : 0xAA;
    }
    return (line & 1) ? 0x22 : 0x88;
}

/* One cell of a bar: `fill` the pixels (bit 7 the left) in the ink's shade, `zero` pixels that are solid as well, the rest the track.  Six lines tall. */
static void bar_cell(uint8_t col, uint8_t row, uint8_t fill, uint8_t zero, uint8_t colour)
{
    uint8_t a[8], k;

    for (k = 0; k < 8; ++k)
        a[k] = (k && k < 7) ? (uint8_t)((shade(colour, k) & fill) | (((k & 1) ? 0x22 : 0x88) & ~fill) | zero) : 0;
    put_art(col, row, a, 0);
}

void plat_bar(uint8_t col, uint8_t row, uint8_t cells, uint8_t fill, uint8_t attr)
{
    uint8_t i;
    int16_t px;

    for (i = 0; i < cells; ++i) {
        px = (int16_t)fill - 8 * i;
        bar_cell((uint8_t)(col + i), row, px >= 8 ? 0xFF : px <= 0 ? 0 : (uint8_t)(0xFF << (8 - px)), 0, (uint8_t)(attr & 7));
    }
}

/* seven cells, 56 pixels: the zero mark at pixel 27, `level` pixels of fill to the right (green) or to the left (red) of it */
void plat_demand(uint8_t col, uint8_t row, char name, int8_t level)
{
    uint8_t k, b, fill, zero;
    int16_t x;

    plat_put(col, row, (uint8_t)name);
    for (k = 0; k < 7; ++k) {
        fill = zero = 0;
        for (b = 0; b < 8; ++b) {
            x = 8 * k + b;
            if (x == 27)
                zero |= (uint8_t)(0x80 >> b);
            else if (level > 0 ? x > 27 && x <= 27 + level : level < 0 && x < 27 && x >= 27 + level)
                fill |= (uint8_t)(0x80 >> b);
        }
        bar_cell((uint8_t)(col + 1 + k), row, fill, zero, level > 0 ? COL_GREEN : COL_RED);
    }
}

/* ---- scrolling ------------------------------------------------------------------------------------------------------------------ */
/* The map's cells (x, y) move to (x - dx, y - dy): a text row of the screen is 720 bytes, a cell 16 bytes of it, so a row is moved by whole rows (dy) and a row sideways by
   16 * dx bytes.  The cells that come into view are what the game draws; their cache entries are 0. */
void plat_scroll(uint8_t row, uint8_t rows, int8_t dx, int8_t dy)
{
    int16_t y, ys;
    uint8_t i, ax = (uint8_t)(dx < 0 ? -dx : dx);

    for (i = 0; i < rows; ++i) {
        y = dy < 0 ? (int16_t)rows - 1 - i : i;         /* (the rows in the order that does not overwrite what is still to move) */
        ys = y + dy;
        if (ys < 0 || ys >= rows)
            continue;
        pcw_mv_src = (uint16_t)(pcw_rows[row + ys] + (dx > 0 ? 16 * ax : 0));
        pcw_mv_len = (uint16_t)(640 - 16 * ax);
        pcw_move((uint16_t)(pcw_rows[row + y] + (dx < 0 ? 16 * ax : 0)));
#ifndef PCW_NO_CACHE
        memmove(&tcache[row + y - MAP_ROW][dx < 0 ? ax : 0], &tcache[row + ys - MAP_ROW][dx > 0 ? ax : 0], (MAP_COLS - ax) * 2);
        if (dx > 0)
            memset(&tcache[row + y - MAP_ROW][MAP_COLS - ax], 0, ax * 2);
        else if (dx < 0)
            memset(&tcache[row + y - MAP_ROW][0], 0, ax * 2);
#endif
    }
#ifndef PCW_NO_CACHE
    for (i = 0; i < rows; ++i) {                        /* the rows that come into view */
        y = i;
        ys = y + dy;
        if (ys < 0 || ys >= rows)
            memset(&tcache[row + y - MAP_ROW][0], 0, MAP_COLS * 2);
    }
#endif
}

/* ---- mini maps ------------------------------------------------------------------------------------------------------------------ */
/* HAVE_MINIMAP_NATIVE with HAVE_MINIMAP_SQUARE: the builder (target/common/minimap_640x200_3bpp.asm) gives 96 colour classes (0..7) a tile row, and a tile is 4x2 pixels
   here (the 96 tiles are 384 pixels, 24 cells, and the 96 rows 192 lines, 24 text rows), each class its own little picture.  A palette byte is the pattern: the pixels of
   line 0 in the high nibble (the left pixel is bit 3), of line 1 in the low.  What a class is depends on the view; 8 and up is the city shown dim where a density is none. */
extern uint8_t pcw_minibuf[96];
extern void pcw_mini(uint16_t dst) __z88dk_fastcall;

#define PAT_WATER  0xA5
#define PAT_TREES  0x48
#define PAT_HOUSES 0xEA
#define PAT_SHOPS  0xF9
#define PAT_INDUS  0xF6
#define PAT_CIVIC  0x69
#define PAT_ROAD   0x66

static const uint8_t pal_city[16] = {
    0x00, PAT_WATER, PAT_CIVIC, PAT_INDUS, PAT_TREES, PAT_HOUSES, PAT_SHOPS, PAT_ROAD, 0, 0, 0, 0, 0, 0, 0, 0
};
static const uint8_t pal_power[16] = {      /* water, power (the builder's 6), and what is built without it (2) */
    0x00, 0x24, PAT_CIVIC, 0x00, 0x00, 0x00, 0xFF, 0x00, 0, 0, 0, 0, 0, 0, 0, 0
};
static const uint8_t pal_transport[16] = {
    0x00, 0x24, 0x00, 0x00, 0x00, 0x00, 0x00, 0xFF, 0, 0, 0, 0, 0, 0, 0, 0
};
static const uint8_t pal_density[16] = {    /* the levels, then the city shown as single pixels where there is none */
    0x00, 0x48, 0xA5, 0xED, 0xFF, 0xFF, 0xFF, 0xFF, 0x00, 0x00, 0x40, 0x40, 0x00, 0x40, 0x40, 0x40
};

static const uint8_t *palette(uint8_t view)
{
    return view == 1 ? pal_city : view == 6 ? pal_power : view == 7 ? pal_transport : pal_density;
}

void plat_put_minirow(uint8_t ty, const uint8_t *colours, const uint8_t *base, uint8_t view)
{
    const uint8_t *pal = palette(view);
    uint8_t *o = pcw_minibuf;
    uint8_t i, a, b;

    (void)base;
    for (i = 0; i < 48; ++i) {
        a = pal[*colours++ & 15];
        b = pal[*colours++ & 15];
        *o++ = (uint8_t)((a & 0xF0) | (b >> 4));            /* line 0 of two tiles */
        *o++ = (uint8_t)(((a & 15) << 4) | (b & 15));       /* line 1 */
    }
    pcw_mini((uint16_t)(pcw_rows[ty >> 2] + ((ty & 3) << 1)));
}

/* The key: a cell of the pattern (the 4 pixels repeated across, the two lines alternating) and what it is, in the sidebar's rows 6 and on. */
static void swatch(uint8_t col, uint8_t row, uint8_t pat)
{
    uint8_t k, n;

    for (k = 0; k < 8; ++k) {
        n = (uint8_t)((k & 1) ? (pat & 15) : (pat >> 4));
        pcw_cellbuf[k] = pcw_cellbuf[8 + k] = (k == 0 || k == 7) ? 0 : (uint8_t)((n << 4) | n);      /* (a blank line each end: the swatches of a list do not run together) */
    }
    FORGET(col, row);
    pcw_blit(CELL(col, row));
}

static void key_line(uint8_t row, uint8_t pat, const char *label)
{
    swatch(MM_SIDE_COL, row, pat);
    plat_puts((uint8_t)(MM_SIDE_COL + 2), row, label);
}

void plat_minimap_key(uint8_t view)
{
    uint8_t i;

    for (i = 6; i < 16; ++i)
        plat_puts(MM_SIDE_COL, i, "              ");
    switch (view) {
    case 1:
        key_line(6, PAT_WATER, "WATER");
        key_line(7, PAT_TREES, "TREES");
        key_line(8, PAT_ROAD, "ROADS");
        key_line(9, PAT_HOUSES, "HOUSES");
        key_line(10, PAT_SHOPS, "SHOPS");
        key_line(11, PAT_INDUS, "INDUSTRY");
        key_line(12, PAT_CIVIC, "CIVIC");
        break;
    case 6:
        key_line(6, 0x24, "WATER");
        key_line(7, 0xFF, "POWERED");
        key_line(8, PAT_CIVIC, "NO POWER");
        break;
    case 7:
        key_line(6, 0x24, "WATER");
        key_line(7, 0xFF, "ROADS");
        break;
    default:                                /* a density: low, the levels, high */
        plat_puts(MM_SIDE_COL, 6, "LOW");
        key_line(7, 0x48, "");
        key_line(8, 0xA5, "");
        key_line(9, 0xED, "");
        key_line(10, 0xFF, "");
        plat_puts(MM_SIDE_COL, 11, "HIGH");
        break;
    }
}
