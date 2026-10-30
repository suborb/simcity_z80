/* MZ-2500 platform: 320x200 in 16 colours, planar video RAM, used as 32 x 24 cells of 8x8 pixels at byte column 4 (the map and the status panel as the MSX2's), the Atari
   ST's art in its 16 colours as the SAM Coupe's.  The drawing primitives (a cell from the planar picture atlas, a glyph, a fill of bytes, a scroll, an icon) are in
   plat_mz2500.asm; this has what is made from them: text, the tool icons, the demand and bar charts, the mini map's rows.  The palette is the ST's 16 (entry 0 black and 15 white);
   tools/st_tiles_3bpp.py --mz2500 makes the atlas (TILES.BIN, linked as pages 22-24) and the tables (mz2500.inc, mz2500.h). */
#include <stdint.h>
#include <string.h>
#include <stdlib.h>
#include <arch/mz2500.h>
#include "platform.h"
#include "engine.h"
#include "mz2500.h"

extern void mz_tile(uint8_t col, uint8_t row, uint16_t n) __smallc;
extern void mz_glyph(uint8_t col, uint8_t row, const uint8_t *art, uint8_t ink, uint8_t paper) __smallc;
extern void mz_glyphr(uint8_t col, uint8_t row, const uint8_t *art, uint8_t ink, uint8_t paper) __smallc;   /* (art with the bits reversed: bit 0 the leftmost) */
extern void mz_overlay(uint8_t col, uint8_t row, const uint8_t *art) __smallc;
extern void mz_xorcell(uint8_t col, uint8_t row) __smallc;
extern void mz_fillb(uint8_t y, uint8_t xb, uint8_t nb, uint8_t ny, uint8_t colour) __smallc;
extern void mz_maskb(uint8_t y, uint8_t xb, uint8_t ny, uint8_t mask, uint8_t colour) __smallc;
extern void mz_recolour(uint8_t col, uint8_t row, uint8_t n, uint8_t ink, uint8_t paper) __smallc;
extern void mz_wrline(uint8_t y, const uint8_t *pixels, uint8_t nlines) __smallc;
extern void mz_shift(uint8_t row, uint8_t rows, int8_t dx, int8_t dy) __smallc;
extern void mz_icon(uint8_t col, uint8_t y, uint16_t offset) __smallc;
extern void mz_setup(void);
#ifdef HAVE_SOUND
extern void mz_snd_init(void);
extern void ay_poll(void);                      /* a tick of the sound if a frame has begun */
#endif
extern void mz_keyinit(void);
extern void mz_pal4096(void);
extern uint8_t mz_keycol(uint8_t column) __smallc;
extern void mz_cleartext(void);
extern void mz_clear(void);

extern const uint8_t mz_font[];                 /* 96 glyphs, from space, bits reversed (mz2500.inc) */
extern const uint8_t view_tile_art[];           /* picture n is at 8 * n from it */
extern uint8_t V_view_tick;                     /* the game's frame counter: the animations' clock */
extern const uint8_t mz_palette[];              /* mz2500.inc: 16 colours, 2 bytes each */
extern const uint8_t mz_attrs[];                /* ... the palette entry nearest each of the 8 attribute colours */
extern const uint8_t mz_animbits[];             /* ... a bit a picture that has an animation, */
extern const uint8_t mz_animlist[];             /* ... and those (the picture, a word, and the animation from 1), */
extern const uint8_t mz_animtab[];              /* ... an animation: the first frame's picture (a word) and the frames less one, 3 bytes (tools/st_tiles_3bpp.py ANIMATED) */

#pragma codeseg BANK_12                         /* (RAM page 12's code area: always mapped, beside the program: the UI bank is full) */

#define COLS        32
#define XB0         4                           /* the byte column of the map's column 0 (plat_mz2500.asm) */
#define MAP_ROW     7                           /* the map's cell rows: the only ones with a cache entry (after the panel: ui/game.c) */
#define MAP_ROWS    (24 - MAP_ROW)
#define BLACK       0
#define WHITE       15

static uint16_t clock_count;

/* ---- fills --------------------------------------------------------------------------------------------------------------------- */
/* A rectangle of pixels in one colour: x and w in pixels of the 256 wide area (byte column XB0 on), y and h in lines */
static void rect(uint16_t x, uint16_t y, uint16_t w, uint16_t h, uint8_t colour)
{
    uint8_t x0, x1, mask, y8 = (uint8_t)y, h8 = (uint8_t)h;
    uint16_t e = x + w;

    if (!w || !h)
        return;
    x0 = (uint8_t)(x >> 3);
    x1 = (uint8_t)(e >> 3);                     /* the byte column of the end (the pixels of it before e are in the mask) */
    if (x0 == x1) {                             /* inside one byte */
        mask = (uint8_t)((1 << (e & 7)) - (1 << (x & 7)));
        mz_maskb(y8, XB0 + x0, h8, mask, colour);
        return;
    }
    if (x & 7) {
        mz_maskb(y8, XB0 + x0, h8, (uint8_t)(0xFF << (x & 7)), colour);
        ++x0;
    }
    if (x1 > x0)
        mz_fillb(y8, XB0 + x0, x1 - x0, h8, colour);
    if (e & 7)
        mz_maskb(y8, XB0 + x1, h8, (uint8_t)((1 << (e & 7)) - 1), colour);
}

static void vfill(uint8_t y, uint8_t x, uint16_t nx, uint8_t ny, uint8_t colour)
{
    rect(x, y, nx, ny, colour);
}

/* ---- the cache ------------------------------------------------------------------------------------------------------------- */
/* what each map cell shows (its picture and the inverse flag, or $FFFF) */
static uint16_t cache[MAP_ROWS][COLS];

static uint16_t *entry(uint8_t col, uint8_t row)        /* the cell's word, or 0 outside the map */
{
    row -= MAP_ROW;
    return row < MAP_ROWS ? &cache[row][col] : 0;
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

/* ---- pictures and text ------------------------------------------------------------------------------------------------------ */
/* The picture to show for picture n: an animated one (the airport's radar, the park's fountain, the chimneys' smoke, the nuclear plant's swirl) shows one of its
   frames, which are pictures after the engine's, changing every 16 ticks of the frame counter. */
static uint16_t shown(uint16_t n)
{
    const uint8_t *e = mz_animlist;

    if (n >= MZ_ANIMATED || !(mz_animbits[n >> 3] & (1 << (n & 7))))
        return n;
    while ((uint16_t)(e[0] | (e[1] << 8)) != n)
        e += 3;
    e = mz_animtab + (uint16_t)(e[2] - 1) * 3;
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
    mz_tile(col, row, n);
    if (inverse)                                /* the cursor: the pixels' colours complemented */
        mz_xorcell(col, row);
}

void plat_put_overlay(uint8_t col, uint8_t row, const uint8_t *art)
{
    forget(col, row);
    mz_overlay(col, row, art);
}

void plat_put_bitmap(uint8_t col, uint8_t row, const uint8_t *art)
{
    forget(col, row);
    mz_glyph(col, row, art, WHITE, BLACK);
}

/* The line pieces of the boxes' frames, pipes two pixels thick with rounded corners: 1 top left, 2 top right, 3 bottom left, 4 bottom
   right, 5 across, 6 down (bits reversed, as the font) */
static const uint8_t box[6][8] = {
    { 0x00, 0x00, 0x00, 0xF0, 0xF8, 0x18, 0x18, 0x18 },
    { 0x00, 0x00, 0x00, 0x0F, 0x1F, 0x18, 0x18, 0x18 },
    { 0x18, 0x18, 0x18, 0xF8, 0xF0, 0x00, 0x00, 0x00 },
    { 0x18, 0x18, 0x18, 0x1F, 0x0F, 0x00, 0x00, 0x00 },
    { 0x00, 0x00, 0x00, 0xFF, 0xFF, 0x00, 0x00, 0x00 },
    { 0x18, 0x18, 0x18, 0x18, 0x18, 0x18, 0x18, 0x18 }
};

void plat_put(uint8_t col, uint8_t row, uint8_t ch)
{
    forget(col, row);
    if (ch < 32)
        mz_glyphr(col, row, box[ch - 1], WHITE, BLACK);
    else
        mz_glyphr(col, row, mz_font + (uint16_t)(ch - 32) * 8, WHITE, BLACK);
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
static uint8_t icons_last = 0xFF;               /* the tool whose icon is framed on the screen, or $FF if the icons are not drawn */

void plat_clear(void)
{
    icons_last = 0xFF;                          /* (the icons have to be drawn again) */
    mz_clear();
    forget_all();
}

void plat_text_clear(void)
{
    plat_clear();
}

void plat_clear_map(void)
{
    vfill(48, 0, 256, 144, BLACK);               /* below the status panel's first six rows: the panel and the icons stay */
    forget_all();
}

#ifdef HAVE_SCROLL
/* The view's origin moved by (dx, dy) cells: cell (x, y) is now at (x - dx, y - dy).  The map's pixels, and the cache that says what they show, are moved by copies
   (a CRTC start address that scrolls the map was tried: Takeda's lower display area does not wrap at SAD1 as the ring needed); the cells that come into view are left to the
   game, and marked as unknown. */
void plat_scroll(uint8_t row, uint8_t rows, int8_t dx, int8_t dy)
{
    mz_shift(row, rows, dx, dy);
    if (row != MAP_ROW || rows != MAP_ROWS) {   /* (not the rows the cache is for) */
        forget_all();
        return;
    }
    {
        uint8_t y, x;

        if (dy > 0) {
            for (y = 0; y < MAP_ROWS - dy; ++y)
                memcpy(cache[y], cache[y + dy], (COLS * 2));
            for (; y < MAP_ROWS; ++y)
                memset(cache[y], 0xFF, (COLS * 2));
        } else if (dy < 0) {
            for (y = MAP_ROWS - 1; y >= -dy; --y)
                memcpy(cache[y], cache[y + dy], (COLS * 2));
            for (y = 0; y < -dy; ++y)
                memset(cache[y], 0xFF, (COLS * 2));
        }
        if (dx > 0) {
            for (y = 0; y < MAP_ROWS; ++y) {
                memmove(&cache[y][0], &cache[y][dx], (COLS - dx) * 2);
                for (x = COLS - dx; x < COLS; ++x)
                    cache[y][x] = 0xFFFF;
            }
        } else if (dx < 0) {
            for (y = 0; y < MAP_ROWS; ++y) {
                memmove(&cache[y][-dx], &cache[y][0], (COLS + dx) * 2);
                for (x = 0; x < -dx; ++x)
                    cache[y][x] = 0xFFFF;
            }
        }
    }
}
#endif



/* ---- start and stop ------------------------------------------------------------------------------------------------------------ */
void plat_init(void)
{
    uint8_t n;

    mz2500_set_mode(0x14);                      /* (screen B is over A: the pointer's layer) */
    mz2500_set_display_planes(0xFF);            /* ... and shown: the planes of both screens */
    mz_pal4096();                               /* (the IPL leaves the fixed digital 16 colours: red and green the other way round from the ST's numbering) */
    for (n = 0; n < 16; ++n) {                  /* the palette; pixel value n shows entry n */
        mz2500_set_palette(n, mz_palette[n * 2] >> 4, mz_palette[n * 2 + 1] & 15, mz_palette[n * 2] & 15);
        mz2500_set_pixel_palette(n, n);
    }
    mz_setup();
#ifdef HAVE_SOUND
    mz_snd_init();
#endif
    mz_keyinit();
    mz_cleartext();
    plat_clear();
}

void plat_exit(void)
{
}

uint16_t plat_clock(void) { return clock_count; }

/* Once a pass of the game's loop, which waits for the next frame (the vertical blanking flag) */
void plat_idle(void)
{
    ++clock_count;
#ifdef HAVE_SOUND
    ay_poll();
#endif
    mz2500_wait_vblank();
}
void plat_flush(void) {}

/* ---- a bar of six lines: the demand and the charts, the key's swatches --------------------------------------------------------- */
static void forget_cells(uint8_t col, uint8_t row, uint8_t n)
{
    while (n--)
        forget(col++, row);
}

/* A bar of `cells` cells at (col, row): a black line, six lines of `colour` (the first `filled` pixels in `a`, the rest in `b`), a black line */
static void bar(uint8_t col, uint8_t row, uint8_t cells, uint16_t filled, uint8_t a, uint8_t b)
{
    uint16_t x = (uint16_t)col * 8, y = (uint16_t)row * 8, w = (uint16_t)cells * 8;

    forget_cells(col, row, cells);
    if (filled > w)
        filled = w;
    rect(x, y, w, 1, BLACK);
    rect(x, y + 1, filled, 6, a);
    rect(x + filled, y + 1, w - filled, 6, b);
    rect(x, y + 7, w, 1, BLACK);
}

void plat_swatch(uint8_t col, uint8_t row, uint8_t cells, uint8_t index)
{
    bar(col, row, cells, (uint16_t)cells * 8, index, index);
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
    uint16_t x = (uint16_t)(col + 1) * 8, y = (uint16_t)row * 8;

    plat_put(col, row, (uint8_t)name);
    bar(col + 1, row, 7, 0, DM_EMPTY, DM_EMPTY);
    if (level > 0)
        rect(x + 28, y + 1, (uint16_t)level, 6, DM_GREEN);
    else if (level < 0)
        rect(x + 27 + level, y + 1, (uint16_t)-level, 6, DM_RED);
    rect(x + 27, y + 1, 1, 6, DM_ZERO);
}

/* The colours of an attribute (the Spectrum's: ink in bits 0-2, paper in 3-5), as palette entries. */
static uint8_t ink_of(uint8_t attr) { return mz_attrs[attr & 7]; }
static uint8_t paper_of(uint8_t attr) { return mz_attrs[(attr >> 3) & 7]; }

/* Recolours n cells of text already drawn (white on black): the set pixels take the ink and the others the paper */
void plat_text_attr(uint8_t col, uint8_t row, uint8_t n, uint8_t attr)
{
    forget_cells(col, row, n);
    mz_recolour(col, row, n, ink_of(attr), paper_of(attr));
}

/* A horizontal bar chart `cells` cells wide: the first `fill` pixels (0 to 8 * cells) in the ink of the attribute, the rest in its paper
   (a black one is the dark grey of the demand bars: the track the bar is on). */
void plat_bar(uint8_t col, uint8_t row, uint8_t cells, uint8_t filled, uint8_t attr)
{
    uint8_t ink = ink_of(attr), paper = paper_of(attr);

    if (ink == BLACK)
        ink = DM_EMPTY;
    if (paper == BLACK)
        paper = DM_EMPTY;
    bar(col, row, cells, filled, ink, paper);
}

/* ---- the tool icons ------------------------------------------------------------------------------------------------------------ */
/* The 14 tools as the Atari ST game's buttons, 24x14 pixels in a 24x16 button, in two rows of seven: icon i is in cell (3 * (i mod 7), 1 + 2 * (i div 7)).  They
   are in the atlas, and the dimmed ones (a tool there is no money for) after them; the selected one has a yellow frame (colour 14). */
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
    uint8_t x = (uint8_t)(i % 7) * 24, y = (uint8_t)(8 + 16 * (i / 7));
    uint16_t off = ((afford_mask >> i) & 1 ? MZ_ICONS : MZ_DIM_ICONS) + (uint16_t)i * 168;

    if (i == icon_sel)                          /* the frame, yellow, over the button's edge */
        rect(x, y, 24, 16, 14);
    else
        rect(x, y, 24, 16, BLACK);
    mz_icon(XB0 + x / 8, (uint8_t)(y + 1), off);
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

/* Tile row ty of the mini map: each tile is 2x2 pixels, at byte column XB0 on.  For a density a tile with no level shows its colour from base, the city's row, dimmed. */
void plat_put_minirow(uint8_t ty, const uint8_t *colours, const uint8_t *base, uint8_t view)
{
    static uint8_t line[192];
    uint8_t x, c;
    const uint8_t *tab = mm_tabs[(view - 1) & 7];
    uint8_t dens = (MM_DENSITIES >> ((view - 1) & 7)) & 1;

    for (x = 0; x < MAP_W; ++x) {
        c = colours[x] & 7;
        c = c ? tab[c] : dens ? mm_dim[base[x] & 7] : tab[0];
        line[x * 2] = c;
        line[x * 2 + 1] = c;
    }
    mz_wrline((uint8_t)(ty * 2), line, 2);
}

/* ---- the keyboard ------------------------------------------------------------------------------------------------------------- */
/* The matrix (as Takeda's source has it): 12 columns of 8 keys read through the Z80 PIO, a key down is a 0 bit (bit 0 first).  Column 11 has SHIFT (bit 2). */
static const uint8_t keys[11][8] = {
    { 0, 0, 0, 0, 0, 0, 0, 0 },                         /* F1 to F8 */
    { 0, 0, 0, 0, 0, 0, 0, 0 },                         /* F9, F10 and the keypad */
    { 0, 0, 0, 0, 0, 0, 0, 0 },
    { 0, ' ', KEY_ENTER, KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT, 0 },
    { '/', 'a', 'b', 'c', 'd', 'e', 'f', 'g' },
    { 'h', 'i', 'j', 'k', 'l', 'm', 'n', 'o' },
    { 'p', 'q', 'r', 's', 't', 'u', 'v', 'w' },
    { 'x', 'y', 'z', '\'', '\\', 0, '.', ',' },
    { '0', '1', '2', '3', '4', '5', '6', '7' },
    { '8', '9', ';', '=', '-', '`', '[', 0 },
    { ']', 0, 0, 127, 127, KEY_ESC, '*', '/' }
};

static uint8_t held;                            /* the code of the key that is down, or 0 */
static uint8_t held_for;                        /* the looks it has been down for */

/* The key down now (the first in the matrix), as the game's code: letters lower case, a capital with SHIFT, SHIFT with a cursor key the eight cell move. */
static uint8_t scan(void)
{
    uint8_t col, bits, bit, k = 0, shift;

    shift = !(mz_keycol(11) & 4);
    for (col = 0; col < 11 && !k; ++col) {
        bits = (uint8_t)~mz_keycol(col);
        for (bit = 0; bit < 8 && !k; ++bit)
            if (bits & (1 << bit))
                k = keys[col][bit];
    }
    if (!k)
        return 0;
    if (shift) {
        switch (k) {
        case KEY_LEFT: return KEY_FAR_LEFT;
        case KEY_RIGHT: return KEY_FAR_RIGHT;
        case KEY_UP: return KEY_FAR_UP;
        case KEY_DOWN: return KEY_FAR_DOWN;
        case '=': return '+';
        }
        if (k >= 'a' && k <= 'z')
            k = (uint8_t)(k - 32);
    }
    return k;
}

/* A key registers when it goes down; a cursor key (or Q, A, O or P) repeats after 12 looks, then every 3 */
#ifdef HAVE_POINTER
uint8_t plat_keyboard_key(void)                 /* (target/common/pointer.c makes plat_key and plat_key_game of it) */
#else
uint8_t plat_key(void)
#endif
{
    uint8_t k = scan();

    if (k != held) {
        held = k;
        held_for = 0;
        return k;
    }
    if (!k || ++held_for < 12)
        return 0;
    if (k == KEY_LEFT || k == KEY_RIGHT || k == KEY_UP || k == KEY_DOWN || k == KEY_FAR_LEFT || k == KEY_FAR_RIGHT || k == KEY_FAR_UP || k == KEY_FAR_DOWN ||
        k == 'q' || k == 'a' || k == 'o' || k == 'p' || k == 'Q' || k == 'A' || k == 'O' || k == 'P') {
        held_for = 9;
        return k;
    }
    held_for = 12;
    return 0;
}
