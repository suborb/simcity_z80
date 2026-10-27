/* ZX Spectrum Next platform: Layer 2, 256x192 pixels of 8 bits (the palette entry of each), used as 32 x 24 cells of 8x8.  The drawing
   primitives (a cell from the picture atlas, a glyph, a line of pixels) are in plat_zxn.asm; this has what is made from them: text,
   the tool icons, the demand and bar charts, the mini map's rows, and the keyboard.  The palette is in three parts: the Atari ST's 16 colours (entry 0
   black and 15 white), which the text, charts, mini maps and tool icons use, then the map art's 64 (the Amiga SimCity 1 Meg's by default), those inverted
   (the cursor), and the Amiga's 16 for the tool icons; this follows the SAM Coupe (target/sam/plat_sam.asm); tools/st_tiles_3bpp.py --zxn makes the art. */
#include <stdint.h>
#include <arch/zxn.h>                  /* ZXN_NEXTREG, REG_* (z88dk's names for the Next's registers) */
#include <string.h>
#include <fcntl.h>
#include <unistd.h>
#include "platform.h"
#include "engine.h"

extern void zxn_tile(uint8_t col, uint8_t row, uint16_t pic, uint8_t inverse);
extern void zxn_glyph(uint8_t col, uint8_t row, const uint8_t *art, uint8_t ink, uint8_t paper);
extern void zxn_overlay(uint8_t col, uint8_t row, const uint8_t *art, uint8_t colour);
extern void zxn_wr(uint8_t y, uint8_t x, const uint8_t *src, uint16_t len);
extern void zxn_rd(uint8_t y, uint8_t x, uint8_t *dst, uint16_t len);
extern void zxn_fill(uint8_t y, uint8_t x, uint16_t len, uint8_t colour);
extern void zxn_palette(const uint8_t *entries, uint8_t first, uint8_t count);
extern void zxn_show(void);
extern void zxn_bank_read(uint8_t *dst, uint8_t page, uint16_t off, uint16_t len);
extern void zxn_dma(uint8_t srcpage, uint16_t srcoff, uint8_t dstpage, uint16_t dstoff, uint16_t len, uint8_t dec);
extern void snd_init(void);
extern void snd_wait(void);
extern uint8_t zxn_in(uint16_t port);
extern void zxn_out(uint16_t port, uint8_t value);

extern const uint8_t font_8x8_bbc_system[];     /* 96 glyphs, from space */
extern const uint8_t view_tile_art[];           /* picture n is at 8 * n from it */
extern uint8_t V_view_tick;                     /* the game's frame counter: the animations' clock */
extern const uint8_t zxn_head[];               /* 208 palette entries (2 bytes each: the ST's 16 for the interface, the map art's 64, the same inverted, the Amiga's 64 for the tool icons), 8 attribute colours, then the 64 colours a dimmed icon's are */

#define COLS        32
#define MAP_ROW     (ICON_ROWS + 3)             /* the map's cell rows: the only ones with a cache entry (after the panel: ui/game.c) */
#define MAP_ROWS    (24 - MAP_ROW)
#define BLACK       0
#define WHITE       15
#define TEXT_ATTR   7                           /* white on black */
#define PALETTE_ENTRIES 208
#define ATTRS       (zxn_head + 2 * PALETTE_ENTRIES)
#define DIM         (ATTRS + 8)                 /* what each of the icons' 64 colours is, dimmed: an absolute palette entry */
#define PICTURES    345                         /* the engine's pictures (the animations' frames come after them) */
#define ANIM_MAP    (DIM + 64)                  /* a byte a picture: its animation (from 1), or 0 */
#define ANIM_TAB    (ANIM_MAP + PICTURES)       /* an animation: the first frame's picture (a word) and the frames less one, 3 bytes (tools/st_tiles_3bpp.py ANIMATED) */
#define ICON_PAGE   44                          /* the icons: 14 of 22x20 bytes, a palette index (0 to 63) a pixel, in the 8 KB page 44 (bank 22, zxn_data.asm) */
#define ICON_W      22                          /* the tool icons: the Amiga's, 22x20 pixels of 6 bits */
#define ICON_H      20
#define ICON_BYTES  (ICON_W * ICON_H)
#define ICON_PALETTE 144                        /* (palette entries 144 to 207) */

#ifdef HAVE_SCROLL
static void screen_move(uint16_t dst, uint16_t src, uint16_t len);
#endif

static uint16_t cache[COLS * MAP_ROWS];         /* what each map cell shows: its art address xor the inverse flag, or $FFFF */
static uint16_t clock_count;
#ifdef HAVE_MINIMAP_SCROLL
static uint8_t minimap_scroll_x;
static uint8_t minimap_pan_edge;              /* 1 = left tile column, 2 = right tile column */

void plat_minimap_scroll(uint8_t x)
{
    minimap_scroll_x = x;
    minimap_pan_edge = 0;
}

#ifdef HAVE_SCROLL
/* Shift the 192x192-pixel mini map by one tile.  The sidebar is outside the
   copied rectangle; draw_minimap() repaints the exposed strip afterwards. */
void plat_minimap_pan(int8_t dx, int8_t dy, uint8_t x)
{
    uint16_t y;

    minimap_scroll_x = x;
    minimap_pan_edge = dx < 0 ? 1 : dx > 0 ? 2 : 0;
    if (dx > 0) {
        for (y = 0; y < 192; ++y)
            screen_move((uint16_t)y * 256, (uint16_t)y * 256 + 2, 190);
    } else if (dx < 0) {
        for (y = 0; y < 192; ++y)
            screen_move((uint16_t)y * 256 + 2, (uint16_t)y * 256, 190);
    }

    if (dy > 0) {
        for (y = 0; y < 190; ++y)
            screen_move((uint16_t)y * 256, (uint16_t)(y + 2) * 256, 192);
    } else if (dy < 0) {
        for (y = 190; y != 0; --y)
            screen_move((uint16_t)(y + 1) * 256, (uint16_t)(y - 1) * 256, 192);
    }
}
#endif
#endif

/* ---- the cache ------------------------------------------------------------------------------------------------------------- */
static uint16_t *entry(uint8_t col, uint8_t row)
{
    row -= MAP_ROW;
    return row < MAP_ROWS ? &cache[(uint16_t)row * COLS + col] : 0;
}

static void forget(uint8_t col, uint8_t row)
{
    uint16_t *e = entry(col, row);

    if (e)
        *e = 0xFFFF;
}

static void forget_all(void)
{
    memset(cache, 0xFF, sizeof(cache));
}

/* ---- scrolling: the map's pixels moved by the DMA ------------------------------------------------------------------------------ */
#ifdef HAVE_SCROLL
#define SCREEN_PAGE 18                          /* Layer 2's first 8 KB page (plat_zxn.asm) */

/* Moves len bytes of the screen (offsets in the 48 KB of it) from src to dst as memmove does, in pieces that are inside a page at both ends. */
static void screen_move(uint16_t dst, uint16_t src, uint16_t len)
{
    uint16_t n, so, d;

    if (dst < src) {
        while (len) {
            so = src & 0x1FFF;
            d = dst & 0x1FFF;
            n = 0x2000 - (so > d ? so : d);
            if (n > len)
                n = len;
            zxn_dma((uint8_t)(SCREEN_PAGE + (src >> 13)), so, (uint8_t)(SCREEN_PAGE + (dst >> 13)), d, n, 0);
            src += n;
            dst += n;
            len -= n;
        }
    } else if (dst > src) {                     /* from the far ends, downwards */
        src += len - 1;
        dst += len - 1;
        while (len) {
            so = src & 0x1FFF;
            d = dst & 0x1FFF;
            n = (so < d ? so : d) + 1;
            if (n > len)
                n = len;
            zxn_dma((uint8_t)(SCREEN_PAGE + (src >> 13)), so, (uint8_t)(SCREEN_PAGE + (dst >> 13)), d, n, 1);
            src -= n;
            dst -= n;
            len -= n;
        }
    }
}

/* The view's origin moved by (dx, dy) cells: cell (x, y) is now at (x - dx, y - dy).  The map is one block of lines of 256 bytes, so this is one
   move of the block: by dy * 2048 + dx * 8 bytes.  What wraps round at the edges lands in the cells that come into view, which the game
   draws.  The cache of what the cells show moves with them, and the cells that come into view are marked as unknown. */
void plat_scroll(uint8_t row, uint8_t rows, int8_t dx, int8_t dy)
{
    /* the move in bytes, as a size and a sign (it is up to 34816, which a 16 bit unsigned holds: the sum is right modulo 65536 either way) */
    uint16_t delta = ((uint16_t)(int16_t)dy << 11) + (uint16_t)((int16_t)dx * 8);
    uint8_t up = dy < 0 || (dy == 0 && dx < 0);
    uint16_t start = (uint16_t)row * 2048, len = (uint16_t)rows * 2048, m;
    uint16_t *r;
    uint8_t y;

    if (up) {
        m = (uint16_t)(0 - delta);
        if (m < len)
            screen_move(start + m, start, len - m);
    } else if (delta) {
        m = delta;
        if (m < len)
            screen_move(start, start + m, len - m);
    }
    if (row != MAP_ROW || rows != MAP_ROWS) {   /* (not the rows the cache is for) */
        forget_all();
        return;
    }
    if (dy > 0) {
        memmove(cache, cache + (uint16_t)dy * COLS, (uint16_t)(MAP_ROWS - dy) * COLS * 2);
        memset(cache + (uint16_t)(MAP_ROWS - dy) * COLS, 0xFF, (uint16_t)dy * COLS * 2);
    } else if (dy < 0) {
        memmove(cache + (uint16_t)-dy * COLS, cache, (uint16_t)(MAP_ROWS + dy) * COLS * 2);
        memset(cache, 0xFF, (uint16_t)-dy * COLS * 2);
    }
    if (dx > 0) {
        for (y = 0, r = cache; y < MAP_ROWS; ++y, r += COLS) {
            memmove(r, r + dx, (uint16_t)(COLS - dx) * 2);
            memset(r + COLS - dx, 0xFF, (uint16_t)dx * 2);
        }
    } else if (dx < 0) {
        for (y = 0, r = cache; y < MAP_ROWS; ++y, r += COLS) {
            memmove(r - dx, r, (uint16_t)(COLS + dx) * 2);
            memset(r, 0xFF, (uint16_t)-dx * 2);
        }
    }
}
#endif

/* ---- pictures and text ------------------------------------------------------------------------------------------------------ */
/* The picture to show for picture n: an animated one (the airport's radar, the park's fountain, the chimneys' smoke, the nuclear plant's swirl) shows one of its
   frames, which are pictures after the engine's, changing every 16 ticks of the frame counter. */
static uint16_t shown(uint16_t n)
{
    uint8_t k = ANIM_MAP[n];
    const uint8_t *e;

    if (!k)
        return n;
    e = ANIM_TAB + (uint16_t)(k - 1) * 3;
    return (uint16_t)(e[0] | (e[1] << 8)) + ((V_view_tick >> 4) & e[2]);
}

void plat_put_tile(uint8_t col, uint8_t row, const uint8_t *art, uint8_t attr, uint8_t inverse)
{
    uint16_t *e = entry(col, row);
    uint16_t n = shown((uint16_t)(art - view_tile_art) >> 3);
    uint16_t key = (n << 1) | inverse;          /* what the cell shows: the picture and whether it is the cursor's */

    (void)attr;
    if (e) {
        if (*e == key)
            return;
        *e = key;
    }
    zxn_tile(col, row, n, inverse);
}

void plat_put_overlay(uint8_t col, uint8_t row, const uint8_t *art)
{
    forget(col, row);
    zxn_overlay(col, row, art, WHITE);
}

void plat_put_bitmap(uint8_t col, uint8_t row, const uint8_t *art)
{
    forget(col, row);
    zxn_glyph(col, row, art, WHITE, BLACK);
}

/* The line pieces of the boxes' frames, pipes two pixels thick with rounded corners: 1 top left, 2 top right, 3 bottom left, 4 bottom
   right, 5 across, 6 down */
static const uint8_t box[6][8] = {
    { 0x00, 0x00, 0x00, 0x0F, 0x1F, 0x18, 0x18, 0x18 },
    { 0x00, 0x00, 0x00, 0xF0, 0xF8, 0x18, 0x18, 0x18 },
    { 0x18, 0x18, 0x18, 0x1F, 0x0F, 0x00, 0x00, 0x00 },
    { 0x18, 0x18, 0x18, 0xF8, 0xF0, 0x00, 0x00, 0x00 },
    { 0x00, 0x00, 0x00, 0xFF, 0xFF, 0x00, 0x00, 0x00 },
    { 0x18, 0x18, 0x18, 0x18, 0x18, 0x18, 0x18, 0x18 }
};

void plat_put(uint8_t col, uint8_t row, uint8_t ch)
{
    forget(col, row);
    if (ch < 32)
        zxn_glyph(col, row, box[ch - 1], WHITE, BLACK);
    else
        zxn_glyph(col, row, font_8x8_bbc_system + (uint16_t)(ch - 32) * 8, WHITE, BLACK);
}

void plat_puts(uint8_t col, uint8_t row, const char *s)
{
    while (col < COLS && *s)
        plat_put(col++, row, (uint8_t)*s++);
}

void plat_text_puts(uint8_t col, uint8_t row, const char *s)
{
    plat_puts(col, row, s);
}

/* ---- the screen -------------------------------------------------------------------------------------------------------------- */
static void clear_lines(uint8_t y, uint8_t n)
{
    while (n--)
        zxn_fill(y++, 0, 256, BLACK);
}

static uint8_t icons_last = 0xFF;               /* the tool whose icon is framed on the screen, or $FF if the icons are not drawn */

void plat_clear(void)
{
    icons_last = 0xFF;                          /* (the icons have to be drawn again) */
    clear_lines(0, 192);
    forget_all();
}

void plat_text_clear(void)
{
    plat_clear();
}

void plat_clear_map(void)
{
    clear_lines(48, 144);                       /* below the status panel's first six rows: the panel and the icons stay */
    forget_all();
}

#ifndef ZXN_SPEED
#define ZXN_SPEED RTM_14MHZ                    /* the CPU's speed: RTM_3MHZ, RTM_7MHZ, RTM_14MHZ or RTM_28MHZ: the game's pace is the frame interrupt's (plat_idle), not the CPU's */
#endif
#define REG_INTERRUPT_CONTROL   0xC0           /* (z88dk has no names for these two) */
#define REG_INTERRUPT_ENABLE_0  0xC4

void plat_init(void)
{
    ZXN_NEXTREG(REG_TURBO_MODE, ZXN_SPEED);
    /* The sound effects use AY channel C: ACB stereo centers C in both speakers (ABC puts it on the right).
       Preserve the other Peripheral 3 bits set by the machine or loader. */
    ZXN_NEXTREGA(REG_PERIPHERAL_3, ZXN_READ_REG(REG_PERIPHERAL_3) | RP3_STEREO_ACB);
    ZXN_NEXTREG(REG_INTERRUPT_CONTROL, 0);       /* interrupts as a Spectrum's: mode 1 (not the Next's own mode 2 table) */
    ZXN_NEXTREG(REG_INTERRUPT_ENABLE_0, 1);      /* the frame interrupt of the ULA */
    snd_init();
                                                /* (the sound's frame interrupt: interrupts are on from here) */
    zxn_palette(zxn_head, 0, 100);                /* (the call takes up to 127 entries) */
    zxn_palette(zxn_head + 200, 100, 100);
    zxn_palette(zxn_head + 400, 200, PALETTE_ENTRIES - 200);
    zxn_show();
    zxn_out(0xFE, 0);                              /* a black border */
}

void plat_exit(void)
{
}

uint16_t plat_clock(void) { return clock_count; }
/* Once a pass of the game's loop, which waits for ZXN_PACE frame interrupts (50 a second): the game's speed does not depend on the CPU's. */
#ifndef ZXN_PACE
#define ZXN_PACE 1
#endif
void plat_idle(void)
{
    uint8_t i;

    ++clock_count;
    for (i = 0; i < ZXN_PACE; ++i)
        snd_wait();
}
void plat_flush(void) {}

#ifdef HAVE_SCENARIOS
void plat_scenario_preview_row(uint8_t y, uint8_t x, const uint8_t *pixels)
{
    zxn_wr(y, x, pixels, 120);
}
#endif

/* ---- a bar of six lines: the demand and the charts, the key's swatches --------------------------------------------------------- */
/* One cell of a bar: the pixel line `px` (8 pixels) between two black lines, six times, at (col, row). */
static void bar_cell(uint8_t col, uint8_t row, const uint8_t *px)
{
    uint8_t y = (uint8_t)(row * 8), k;

    forget(col, row);
    zxn_fill(y, (uint8_t)(col * 8), 8, BLACK);
    for (k = 1; k < 7; ++k)
        zxn_wr((uint8_t)(y + k), (uint8_t)(col * 8), px, 8);
    zxn_fill((uint8_t)(y + 7), (uint8_t)(col * 8), 8, BLACK);
}

void plat_swatch(uint8_t col, uint8_t row, uint8_t cells, uint8_t index)
{
    uint8_t px[8];

    memset(px, index, 8);
    while (cells--)
        bar_cell(col++, row, px);
}

/* the colours of the bar charts: palette entries of the ST's 16: 10 light green, 12 light red, 8 dark grey, 15 white */
#define DM_GREEN    10
#define DM_RED      12
#define DM_EMPTY    8
#define DM_ZERO     15

/* A demand indicator: the letter in the cell (col, row), then a bar seven cells (56 pixels) wide on a dark grey track, with a white
   line in the middle (pixel 27) and `level` (-27..27) pixels of fill from it: to the right green, to the left red. */
void plat_demand(uint8_t col, uint8_t row, char name, int8_t level)
{
    uint8_t px[8], k, i, p;
    int8_t edge = (int8_t)(27 + level);

    plat_put(col, row, (uint8_t)name);
    for (k = 0; k < 7; ++k) {
        for (i = 0; i < 8; ++i) {
            p = (uint8_t)(k * 8 + i);
            if (p == 27)
                px[i] = DM_ZERO;
            else if (p < 27)
                px[i] = level < 0 && (int8_t)p >= edge ? DM_RED : DM_EMPTY;
            else
                px[i] = level > 0 && (int8_t)p <= edge ? DM_GREEN : DM_EMPTY;
        }
        bar_cell((uint8_t)(col + 1 + k), row, px);
    }
}

/* The colours of an attribute (the Spectrum's: ink in bits 0-2, paper in 3-5), as palette entries. */
static uint8_t ink_of(uint8_t attr) { return ATTRS[attr & 7]; }
static uint8_t paper_of(uint8_t attr) { return ATTRS[(attr >> 3) & 7]; }

/* Recolours n cells of text already drawn (white on black): the set pixels take the ink and the others the paper. */
void plat_text_attr(uint8_t col, uint8_t row, uint8_t n, uint8_t attr)
{
    uint8_t buf[8], ink = ink_of(attr), paper = paper_of(attr), k, i;

    while (n--) {
        forget(col, row);
        for (k = 0; k < 8; ++k) {
            zxn_rd((uint8_t)(row * 8 + k), (uint8_t)(col * 8), buf, 8);
            for (i = 0; i < 8; ++i)
                if (buf[i] == WHITE)
                    buf[i] = ink;
                else if (buf[i] == BLACK)
                    buf[i] = paper;
            zxn_wr((uint8_t)(row * 8 + k), (uint8_t)(col * 8), buf, 8);
        }
        ++col;
    }
}

/* A horizontal bar chart `cells` cells wide: the first `fill` pixels (0 to 8 * cells) in the ink of the attribute, the rest in its paper
   (a black one is the dark grey of the demand bars: the track the bar is on). */
void plat_bar(uint8_t col, uint8_t row, uint8_t cells, uint8_t fill, uint8_t attr)
{
    uint8_t px[8], ink = ink_of(attr), paper = paper_of(attr), i, n;

    if (ink == BLACK)
        ink = DM_EMPTY;
    if (paper == BLACK)
        paper = DM_EMPTY;
    while (cells--) {
        n = fill >= 8 ? 8 : fill;
        fill -= n;
        for (i = 0; i < 8; ++i)
            px[i] = i < n ? ink : paper;
        bar_cell(col++, row, px);
    }
}

/* ---- the tool icons ------------------------------------------------------------------------------------------------------------ */
/* The 14 tools as the Amiga game's buttons, 22x20 pixels, in two rows of seven: icon i is at pixel (23 * (i mod 7), 8 + 20 * (i div 7)), under the
   status line and left of the demand bars; the selected one has a yellow frame (colour 14 of the interface's). */
static uint8_t icon_sel;
static uint16_t afford_mask = 0x3FFF;           /* the tools there is money for, and what changed since the icons were drawn */
static uint16_t afford_diff;

void plat_afford(uint16_t mask)
{
    afford_diff |= afford_mask ^ mask;
    afford_mask = mask;
}

static void icon_one(uint8_t i)
{
    uint8_t buf[ICON_BYTES], x, y, c;
    uint16_t n;
    uint8_t dim = !((afford_mask >> i) & 1);

    zxn_bank_read(buf, ICON_PAGE + (uint8_t)(((uint16_t)i * ICON_BYTES) >> 13), (uint16_t)((uint16_t)i * ICON_BYTES) & 0x1FFF, ICON_BYTES);
    for (n = 0; n < ICON_BYTES; ++n) {          /* (what is not affordable is in greys) */
        c = buf[n];
        buf[n] = dim ? DIM[c] : (uint8_t)(ICON_PALETTE + c);
    }
    if (i == icon_sel) {                        /* the frame, yellow, over the button's edge */
        memset(buf, 14, ICON_W);
        memset(buf + (ICON_H - 1) * ICON_W, 14, ICON_W);
        for (y = 1; y < ICON_H - 1; ++y)
            buf[y * ICON_W] = buf[y * ICON_W + ICON_W - 1] = 14;
    }
    x = (uint8_t)(23 * (i % 7));
    y = (uint8_t)(8 + 20 * (i / 7));
    for (c = 0; c < ICON_H; ++c)
        zxn_wr((uint8_t)(y + c), x, buf + c * ICON_W, ICON_W);
}

void plat_icons(uint8_t selected)
{
    uint8_t i;
    uint16_t diff;

    icon_sel = selected;
    if (icons_last == 0xFF) {                   /* a new screen: all of them */
        for (i = 0; i < 14; ++i)
            icon_one(i);
    } else {
        if (icons_last == selected && afford_diff == 0)
            return;                             /* the same tool, and no price has come within reach or gone out of it */
        diff = afford_diff;
        for (i = 0; i < 14; ++i, diff >>= 1)
            if ((diff & 1) || i == selected || i == icons_last)
                icon_one(i);
    }
    icons_last = selected;
    afford_diff = 0;
}

/* ---- the mini maps ------------------------------------------------------------------------------------------------------------- */
/* The palette entry of each of the eight colours the builder makes, a view to a line (views 1 to 8: the city, pollution, police cover, fire
   cover, traffic, power, transport, crime).  The city: 0 dirt, 1 water, 2 fire and the services, 3 industry, 4 trees, 5 housing, 6 commerce,
   7 roads and the other networks; a density: its level from 0, dark grey, up through blues, greens and yellow to red, magenta and white (the
   first is none: the city shows); power: dirt, water, red where there is something without power, yellow where there is; transport: roads
   white. */
static const uint8_t mm_tabs[8][8] = {
    { 6, 1, 12, 14, 2, 10, 9, 15 },
    { 8, 3, 11, 10, 14, 12, 13, 15 },
    { 8, 3, 11, 10, 14, 12, 13, 15 },
    { 8, 3, 11, 10, 14, 12, 13, 15 },
    { 8, 3, 11, 10, 14, 12, 13, 15 },
    { 6, 1, 12, 6, 6, 6, 14, 6 },
    { 0, 1, 0, 0, 0, 0, 0, 15 },
    { 8, 3, 11, 10, 14, 12, 13, 15 }
};
/* The city under a density, dimmed: dirt dark grey, water blue, trees dark green, everything built light grey */
static const uint8_t mm_dim[8] = { 8, 1, 7, 7, 2, 7, 7, 7 };
#define MM_DENSITIES 0x9E                       /* views 2, 3, 4, 5 and 8, a bit each (view - 1) */

/* Tile row ty of the mini map: each tile is 2x2 pixels.  For a density a tile with no level shows its colour from base, the city's row, dimmed. */
void plat_put_minirow(uint8_t ty, const uint8_t *colours, const uint8_t *base, uint8_t view)
{
#ifdef HAVE_MINIMAP_SCROLL
    uint8_t line[192], x, c;
    uint8_t edge[2];
#else
    uint8_t line[MAP_W * 2], x, c;
#endif
    const uint8_t *tab = mm_tabs[(view - 1) & 7];
    uint8_t dens = (MM_DENSITIES >> ((view - 1) & 7)) & 1;

#ifdef HAVE_MINIMAP_SCROLL
    if (minimap_pan_edge) {
        x = minimap_pan_edge == 1 ? 0 : 95;
        c = colours[x + minimap_scroll_x] & 7;
        c = c ? tab[c] : dens ? mm_dim[base[x + minimap_scroll_x] & 7] : tab[0];
        edge[0] = edge[1] = c;
        x = minimap_pan_edge == 1 ? 0 : 190;
        zxn_wr((uint8_t)(ty * 2), x, edge, 2);
        zxn_wr((uint8_t)(ty * 2 + 1), x, edge, 2);
        return;
    }
    for (x = 0; x < 96; ++x) {
        c = colours[x + minimap_scroll_x] & 7;
        c = c ? tab[c] : dens ? mm_dim[base[x + minimap_scroll_x] & 7] : tab[0];
        line[x * 2] = c;
        line[x * 2 + 1] = c;
    }
#else
    for (x = 0; x < MAP_W; ++x) {
        c = colours[x] & 7;
        c = c ? tab[c] : dens ? mm_dim[base[x] & 7] : tab[0];
        line[x * 2] = c;
        line[x * 2 + 1] = c;
    }
#endif
#ifdef HAVE_MINIMAP_SCROLL
    zxn_wr((uint8_t)(ty * 2), 0, line, 192);
    zxn_wr((uint8_t)(ty * 2 + 1), 0, line, 192);
#else
    zxn_wr((uint8_t)(ty * 2), 0, line, MAP_W * 2);
    zxn_wr((uint8_t)(ty * 2 + 1), 0, line, MAP_W * 2);
#endif
}

/* ---- the keyboard ------------------------------------------------------------------------------------------------------------- */
/* The Spectrum's matrix: a row for each bit of the port's high byte that is low, its keys in bits 0-4 of port $FE (low bit first):
   row 0 SHIFT Z X C V, 1 A S D F G, 2 Q W E R T, 3 1 2 3 4 5, 4 0 9 8 7 6, 5 P O I U Y, 6 ENTER L K J H, 7 SPACE SYMBOL M N B.  Symbol
   shift (with a letter) gives the punctuation the game uses. */
static const uint8_t keys[8][5] = {
    { 0, 'z', 'x', 'c', 'v' },
    { 'a', 's', 'd', 'f', 'g' },
    { 'q', 'w', 'e', 'r', 't' },
    { '1', '2', '3', '4', '5' },
    { '0', '9', '8', '7', '6' },
    { 'p', 'o', 'i', 'u', 'y' },
    { 13, 'l', 'k', 'j', 'h' },
    { ' ', 0, 'm', 'n', 'b' }
};

static uint8_t held;                            /* the code of the key that is down, or 0 */
static uint8_t caps_was;                        /* caps shift was down when plat_key last looked */

/* The key down now (the lowest in the matrix), as the game's code: letters lower case, a capital if caps shift is down; with symbol shift
   n is ',', m '.', j '-', k '+'; caps shift with 5 to 8 are the cursor keys (the Next's own cursor keys, which a host's arrows are too,
   send them: the shift cannot tell a shifted cursor key from the plain one, so symbol shift as well makes the eight cell move), and with SPACE (BREAK) or 1 (EDIT) the
   escape. */
static uint8_t caps_now;                        /* what scan() found of caps shift */

static uint8_t scan(void)
{
    uint8_t row, bits, col, k = 0, caps, sym;

    caps = !(zxn_in(0xFEFE) & 1);
    caps_now = caps;
    sym = !(zxn_in(0x7FFE) & 2);
    for (row = 0; row < 8 && !k; ++row) {
        bits = (uint8_t)(~zxn_in((uint16_t)(((uint16_t)(0xFE << row | 0xFF >> (8 - row)) << 8) | 0xFE)) & 0x1F);
        if (row == 0)
            bits &= 0x1E;
        if (row == 7)
            bits &= 0x1D;
        for (col = 0; col < 5 && !k; ++col)
            if (bits & (1 << col))
                k = keys[row][col];
    }
    if (!k)
        return 0;
    if (caps) {
        switch (k) {
        case '5': return sym ? KEY_FAR_LEFT : KEY_LEFT;
        case '6': return sym ? KEY_FAR_DOWN : KEY_DOWN;
        case '7': return sym ? KEY_FAR_UP : KEY_UP;
        case '8': return sym ? KEY_FAR_RIGHT : KEY_RIGHT;
        case ' ': case '1': return KEY_ESC;      /* BREAK, or EDIT */
        case '0': return 127;                   /* delete */
        }
        if (k >= 'a' && k <= 'z')
            k = (uint8_t)(k - 32);
    } else if (sym) {
        switch (k) {
        case 'n': return ',';
        case 'm': return '.';
        case 'j': return '-';
        case 'k': return '+';
        }
    }
    return k;
}

uint8_t plat_key(void)
{
    uint8_t k = scan();

    if (k == held) {
        caps_was = caps_now;
        return 0;                               /* the same key, still down (or none) */
    }
    held = k;
    if (k >= '0' && k <= '9' && caps_was && !caps_now)
        k = 0;                                  /* a cursor key (caps shift and 5 to 8) whose shift came up first: not the tool's digit */
    caps_was = caps_now;
    return k;
}

/* ---- files --------------------------------------------------------------------------------------------------------------------- */
/* The city to and from an esxDOS file (z88dk's esxdos fcntl: open, read, write and close).  What esxDOS is given to read and write is
   in the upper RAM (the stack's name, the data from $A400), as the DivMMC takes the lowest 16 KB while it runs. */
uint8_t plat_file_save(const char *name, const uint8_t *a, uint16_t alen, const uint8_t *b, uint16_t blen)
{
    int fd = open(name, O_WRONLY | O_CREAT | O_TRUNC, 0);
    uint8_t r = 1;

    if (fd < 0)
        return 1;
    if (write(fd, (void *)a, alen) == (int)alen && write(fd, (void *)b, blen) == (int)blen)
        r = 0;
    close(fd);
    return r;
}

uint8_t plat_file_load(const char *name, uint8_t *a, uint16_t alen, uint8_t *b, uint16_t blen)
{
    int fd = open(name, O_RDONLY, 0);
    uint8_t r = 0;

    if (fd < 0)
        return 1;
    if (read(fd, a, alen) != (int)alen)
        r = 1;
    else if (read(fd, b, blen) != (int)blen)
        r = 2;
    else {
        char extra;

        /* A 96x96 city is a valid prefix of a 120x100 file.  Do not silently
           accept it (or any other file with the wrong map size). */
        if (read(fd, &extra, 1) != 0)
            r = 2;
    }
    close(fd);
    return r;
}
