/* MSX2 platform (MSX-DOS 2): screen 5, 256x192 pixels of 4 bits, used as 32 x 24 cells of 8x8, the Atari ST's art in its 16 colours as the SAM Coupe's.  The
   drawing primitives (a cell from the picture atlas in the video RAM, a glyph, a line of pixels, a VDP command) are in plat_msx2.asm; this has what is made from
   them: text, the tool icons, the demand and bar charts, the mini map's rows, the keyboard and the files.  The palette is the ST's 16 (entry 0 black and 15 white);
   tools/st_tiles_3bpp.py --msx2 makes the atlas (TILES.DAT, which the program loads into the video RAM's second page) and the tables (msx2.inc, msx2.h). */
#include <stdint.h>
#include <string.h>
#include <stdlib.h>
#include <fcntl.h>
#include <unistd.h>
#include <msx.h>
#include "platform.h"
#include "engine.h"
#include "msx2.h"

extern void msx_tile(uint8_t col, uint8_t row, uint16_t n);
extern void msx_wr(uint8_t y, uint8_t x, const uint8_t *src, uint16_t len);
extern void msx_rd(uint8_t y, uint8_t x, uint8_t *dst, uint16_t len);
extern void msx_sync(void);
extern void msx_psg15(uint8_t value);
extern void vram_read(uint16_t addr, uint8_t *dst, uint16_t len);
extern uint16_t msx_cget(uint16_t addr);
extern void msx_cset(uint16_t addr, uint16_t value);
extern void vram_write(uint16_t addr, const uint8_t *src, uint16_t len);
extern void msx_glyph(uint8_t col, uint8_t row, const uint8_t *art, uint8_t ink, uint8_t paper);
extern void msx_vreg(uint8_t reg, uint8_t value);
extern void msx_pal(const uint8_t *entries);
extern uint8_t msx_keyrow(uint8_t row);
#ifdef HAVE_SOUND
extern void snd_init(void);
extern void snd_exit(void);
#else
#define snd_init()
#define snd_exit()
#endif

extern const uint8_t font_8x8_bbc_system[];     /* 96 glyphs, from space */
extern const uint8_t view_tile_art[];           /* picture n is at 8 * n from it */
extern uint8_t V_view_tick;                     /* the game's frame counter: the animations' clock */
extern const uint8_t msx_palette[];             /* msx2.inc: 16 colours, 2 bytes each */
extern const uint8_t msx_attrs[];               /* ... the palette entry nearest each of the 8 attribute colours */
extern const uint8_t msx_animbits[];            /* ... a bit a picture that has an animation, */
extern const uint8_t msx_animlist[];            /* ... and those (the picture, a word, and the animation from 1), */
extern const uint8_t msx_animtab[];             /* ... an animation: the first frame's picture (a word) and the frames less one, 3 bytes (tools/st_tiles_3bpp.py ANIMATED) */

#define COLS        32
#define MAP_ROW     7                           /* the map's cell rows: the only ones with a cache entry (after the panel: ui/game.c) */
#define MAP_ROWS    (24 - MAP_ROW)
#define BLACK       0
#define WHITE       15
#define JIFFY       (*(volatile uint16_t *)0xFC9E)  /* the BIOS's frame counter */
#define CLIKSW      (*(volatile uint8_t *)0xF3DB)   /* the BIOS's key click switch: its interrupt scans the keyboard and clicks for a key */
#define RG8SAV      (*(volatile uint8_t *)0xFFE7)   /* the BIOS's copies of VDP registers 8 and 9 */
#define RG9SAV      (*(volatile uint8_t *)0xFFE8)

/* VDP commands (the high nibble of R#46; a logical command's operation is its low nibble) */
#define CMD_LMMV    0x80
#define CMD_LMMM    0x90
#define CMD_HMMV    0xC0
#define OP_IMP      0
#define OP_AND      1
#define OP_XOR      3

static uint16_t clock_count;
static uint8_t saved_r9;
static uint8_t saved_click;
static uint8_t pace;                            /* the passes since the 60 Hz display's extra frame */

/* ---- VDP commands ------------------------------------------------------------------------------------------------------------ */
extern void msx_command(uint16_t sx, uint16_t sy, uint16_t dx, uint16_t dy, uint16_t nx, uint16_t ny, uint8_t clr, uint8_t cmd);       /* (plat_msx2.asm) */

#include "shift_rect.h"

/* A rectangle of pixels in one colour (x and nx even for the high speed fill; the pixel exact one is for the frames) */
static void vfill(uint8_t y, uint8_t x, uint16_t nx, uint8_t ny, uint8_t colour)
{
    msx_command(0, 0, x, y, nx, ny, (uint8_t)(colour * 17), CMD_HMMV);
}

/* ---- the cache ------------------------------------------------------------------------------------------------------------- */
/* what each map cell shows (its picture and the inverse flag, or $FFFF) is in the video RAM, from MSX_CACHE: a word a cell, a line of 128 bytes (a cell is 4 pixels wide:
   the cache is an image that a VDP copy can move as the map is scrolled) */
#define CACHE_Y     (256 + 216)                 /* its first line, in the pixels of the second page (MSX_CACHE is the same place, as an address) */

static uint16_t entry(uint8_t col, uint8_t row)         /* the address of the cell's word, or 0 outside the map */
{
    row -= MAP_ROW;
    return row < MAP_ROWS ? MSX_CACHE + (uint16_t)row * 128 + col * 2 : 0;
}

static void forget(uint8_t col, uint8_t row)
{
    uint16_t e = entry(col, row);

    if (e)
        msx_cset(e, 0xFFFF);
}

static void forget_rect(uint16_t cx, uint16_t cy, uint16_t cw, uint16_t ch)    /* cells of the cache (cell columns, map rows) */
{
    msx_command(0, 0, cx * 4, CACHE_Y + cy, cw * 4, ch, 0xFF, CMD_HMMV);
}

static void forget_all(void)
{
    forget_rect(0, 0, COLS, MAP_ROWS);
}

/* ---- pictures and text ------------------------------------------------------------------------------------------------------ */
/* The picture to show for picture n: an animated one (the airport's radar, the park's fountain, the chimneys' smoke, the nuclear plant's swirl) shows one of its
   frames, which are pictures after the engine's, changing every 16 ticks of the frame counter. */
static uint16_t shown(uint16_t n)
{
    const uint8_t *e = msx_animlist;

    if (n >= MSX_ANIMATED || !(msx_animbits[n >> 3] & (1 << (n & 7))))
        return n;
    while ((uint16_t)(e[0] | (e[1] << 8)) != n)
        e += 3;
    e = msx_animtab + (uint16_t)(e[2] - 1) * 3;
    return (uint16_t)(e[0] | (e[1] << 8)) + ((V_view_tick >> 4) & e[2]);
}

void plat_put_tile(uint8_t col, uint8_t row, const uint8_t *art, uint8_t attr, uint8_t inverse)
{
    uint16_t e = entry(col, row);
    uint16_t n = shown((uint16_t)(art - view_tile_art) >> 3);
    uint16_t key = (n << 1) | inverse;          /* what the cell shows: the picture and whether it is the cursor's */

    (void)attr;
    if (e) {
        if (msx_cget(e) == key)
            return;
        msx_cset(e, key);
    }
    msx_tile(col, row, n);
    if (inverse)                                /* the cursor: the pixels' colours complemented */
        msx_command(0, 0, (uint16_t)col * 8, (uint16_t)row * 8, 8, 8, 15, CMD_LMMV | OP_XOR);
}

void plat_put_overlay(uint8_t col, uint8_t row, const uint8_t *art)
{
    uint8_t buf[8], k, i;

    forget(col, row);
    for (k = 0; k < 8; ++k) {
        msx_rd((uint8_t)(row * 8 + k), (uint8_t)(col * 8), buf, 8);
        for (i = 0; i < 8; ++i)
            if (art[k] & (0x80 >> i))
                buf[i] = WHITE;
        msx_wr((uint8_t)(row * 8 + k), (uint8_t)(col * 8), buf, 8);
    }
}

void plat_put_bitmap(uint8_t col, uint8_t row, const uint8_t *art)
{
    forget(col, row);
    msx_glyph(col, row, art, WHITE, BLACK);
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
        msx_glyph(col, row, box[ch - 1], WHITE, BLACK);
    else
        msx_glyph(col, row, font_8x8_bbc_system + (uint16_t)(ch - 32) * 8, WHITE, BLACK);
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
    vfill(0, 0, 256, 192, BLACK);
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
/* The view's origin moved by (dx, dy) cells: cell (x, y) is now at (x - dx, y - dy).  The map's pixels, and the cache that says what they show, are moved by VDP copies;
   the cells that come into view are left to the game, and marked as unknown. */
void plat_scroll(uint8_t row, uint8_t rows, int8_t dx, int8_t dy)
{
    shift_rect(0, (uint16_t)row * 8, 256, (uint16_t)rows * 8, dx * 8, dy * 8);
    if (row != MAP_ROW || rows != MAP_ROWS) {   /* (not the rows the cache is for) */
        forget_all();
        msx_sync();
        return;
    }
    shift_rect(0, CACHE_Y, COLS * 4, MAP_ROWS, dx * 4, dy);
    if (dy > 0)
        forget_rect(0, MAP_ROWS - dy, COLS, dy);
    else if (dy < 0)
        forget_rect(0, 0, COLS, -dy);
    if (dx > 0)
        forget_rect(COLS - dx, 0, dx, MAP_ROWS);
    else if (dx < 0)
        forget_rect(0, 0, -dx, MAP_ROWS);
    msx_sync();                                 /* (the cache is read without waiting for the VDP) */
}
#endif

/* The MSX2 BIOS's palette, for the text screen DOS comes back to (red and blue, then green) */
static const uint8_t bios_palette[32] = {
    0x00, 0, 0x00, 0, 0x11, 6, 0x33, 7, 0x17, 1, 0x27, 3, 0x51, 1, 0x27, 6,
    0x71, 1, 0x73, 3, 0x61, 6, 0x64, 6, 0x11, 4, 0x65, 2, 0x55, 5, 0x77, 7
};

static const char no_atlas[] = "TILES.DAT is not here.\r\n$";
extern void msx_print(const char *dollar_string);
extern void msx_bye(void);                      /* (msx_bank.asm) page 2 back as DOS had it, and out */       /* DOS function 9 */

void plat_init(void)
{
    uint8_t buf[128];
    uint16_t line;
    int fd = open("TILES.DAT", O_RDONLY, 0);

    if (fd < 0) {
        msx_print(no_atlas);
        msx_bye();
    }
    saved_r9 = RG9SAV;
    saved_click = CLIKSW;
    CLIKSW = 0;                                 /* (the game reads the keys itself) */
    msx_screen(5);
    msx_vreg(9, (uint8_t)(RG9SAV & 0x7F));      /* 192 lines (and PAL or NTSC as the machine has it) */
    msx_vreg(8, (uint8_t)(RG8SAV | 2));         /* no sprites */
    msx_vreg(7, 0);                             /* a black border (the BIOS's colour 4 is red in the ST's palette) */
    msx_pal(msx_palette);
    plat_clear();
    snd_init();                                 /* (the sound's frame hook) */
    for (line = 0; line < 256; ++line) {        /* the atlas, in the second page */
        if (read(fd, buf, 128) != 128)
            break;
        vram_write(0x8000u + line * 128u, buf, 128);
    }
    close(fd);
}

void plat_exit(void)
{
    snd_exit();
#ifdef HAVE_MOUSE
    msx_psg15(0xCF);                            /* (the mouse's strobe low, port 1, as the BIOS has it) */
#endif
    CLIKSW = saved_click;
    msx_vreg(14, 0);
    msx_vreg(9, saved_r9);
    msx_pal(bios_palette);
    msx_screen(0);
}

uint16_t plat_clock(void) { return clock_count; }
/* Once a pass of the game's loop, which waits for the next frame interrupt (the BIOS counts them in JIFFY).  The game is timed for 50 frames a second: on a 60 Hz
   display (R#9's NT bit clear) every fifth pass waits a second frame, which makes 5 passes in 6 frames, 50 a second. */
void plat_idle(void)
{
    uint16_t j = JIFFY;

    ++clock_count;
    while (JIFFY == j)
        ;
    if (!(saved_r9 & 2) && ++pace == 5) {
        pace = 0;
        j = JIFFY;
        while (JIFFY == j)
            ;
    }
}
void plat_flush(void) {}

/* The bars, the recolouring and the tool icons are resident too, below $8000 (with the data: the low area has room, and page 3 is for the rest) */
#pragma codeseg code_compiler

/* ---- a bar of six lines: the demand and the charts, the key's swatches --------------------------------------------------------- */
/* A rectangle of one colour: the fast VDP fill if it is on whole bytes (even x and width), else the pixel exact one */
static void rect(uint16_t x, uint16_t y, uint16_t w, uint16_t h, uint8_t colour)
{
    if (!w)
        return;
    if ((x | w) & 1)
        msx_command(0, 0, x, y, w, h, colour, CMD_LMMV | OP_IMP);
    else
        msx_command(0, 0, x, y, w, h, (uint8_t)(colour * 17), CMD_HMMV);
}

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
static uint8_t ink_of(uint8_t attr) { return msx_attrs[attr & 7]; }
static uint8_t paper_of(uint8_t attr) { return msx_attrs[(attr >> 3) & 7]; }

/* Recolours n cells of text already drawn (white on black): the set pixels take the ink and the others the paper, which two VDP logic commands do for the whole run:
   AND with ink xor paper (white stays that, black stays black), then XOR with paper. */
void plat_text_attr(uint8_t col, uint8_t row, uint8_t n, uint8_t attr)
{
    uint8_t ink = ink_of(attr), paper = paper_of(attr);

    forget_cells(col, row, n);
    msx_command(0, 0, (uint16_t)col * 8, (uint16_t)row * 8, (uint16_t)n * 8, 8, ink ^ paper, CMD_LMMV | OP_AND);
    msx_command(0, 0, (uint16_t)col * 8, (uint16_t)row * 8, (uint16_t)n * 8, 8, paper, CMD_LMMV | OP_XOR);
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
   are in the atlas, and the dimmed ones (a tool there is no money for) beside them; the selected one has a yellow frame (colour 14). */
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
    uint16_t sx = (uint16_t)(i % 7) * 24, sy = 256 + ((afford_mask >> i) & 1 ? MSX_ICON_Y : MSX_DIM_Y) + (uint16_t)(i / 7) * 14;
    uint8_t y = (uint8_t)(8 + 16 * (i / 7));

    if (i == icon_sel) {                        /* the frame, yellow, over the button's edge */
        vfill(y, (uint8_t)sx, 24, 16, 14);
        msx_command(sx + 1, sy, sx + 1, y + 1, 22, 14, 0, CMD_LMMM | OP_IMP);
    } else {
        vfill(y, (uint8_t)sx, 24, 16, BLACK);
        msx_command(sx, sy, sx, y + 1, 24, 14, 0, 0xD0);
    }
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

/* From here on the code is resident, in page 3 ($C000 up, SIMCITY.HI): the UI's bank, which --codeseg BANK_UI fills with the C code, holds 16 KB.  It runs while the
   bank is mapped, so it may call the bank's functions. */
#pragma codeseg CODE_HI

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
    uint8_t line[MAP_W * 2], x, c;
    const uint8_t *tab = mm_tabs[(view - 1) & 7];
    uint8_t dens = (MM_DENSITIES >> ((view - 1) & 7)) & 1;

    for (x = 0; x < MAP_W; ++x) {
        c = colours[x] & 7;
        c = c ? tab[c] : dens ? mm_dim[base[x] & 7] : tab[0];
        line[x * 2] = c;
        line[x * 2 + 1] = c;
    }
    msx_wr((uint8_t)(ty * 2), 0, line, MAP_W * 2);
    msx_wr((uint8_t)(ty * 2 + 1), 0, line, MAP_W * 2);
}

/* ---- the keyboard ------------------------------------------------------------------------------------------------------------- */
/* The MSX matrix: PPI row 0 to 8, a key down is a 0 bit (bit 0 first).  Row 6 has SHIFT (bit 0), CTRL, GRAPH, CAPS, CODE and F1 to F3. */
static const uint8_t keys[9][8] = {
    { '0', '1', '2', '3', '4', '5', '6', '7' },
    { '8', '9', '-', '=', '\\', '[', ']', ';' },
    { '\'', '`', ',', '.', '/', 0, 'a', 'b' },
    { 'c', 'd', 'e', 'f', 'g', 'h', 'i', 'j' },
    { 'k', 'l', 'm', 'n', 'o', 'p', 'q', 'r' },
    { 's', 't', 'u', 'v', 'w', 'x', 'y', 'z' },
    { 0, 0, 0, 0, 0, 0, 0, 0 },
    { 0, 0, KEY_ESC, 0, KEY_ESC, 127, 0, KEY_ENTER },
    { ' ', 0, 0, 127, KEY_LEFT, KEY_UP, KEY_DOWN, KEY_RIGHT }
};

static uint8_t held;                            /* the code of the key that is down, or 0 */
static uint8_t held_for;                        /* the looks it has been down for */

/* The key down now (the first in the matrix), as the game's code: letters lower case, a capital with SHIFT, SHIFT with a cursor key the eight cell move. */
static uint8_t scan(void)
{
    uint8_t row, bits, col, k = 0, shift;

    shift = !(msx_keyrow(6) & 1);
    for (row = 0; row < 9 && !k; ++row) {
        if (row == 6)
            continue;
        bits = (uint8_t)~msx_keyrow(row);
        for (col = 0; col < 8 && !k; ++col)
            if (bits & (1 << col))
                k = keys[row][col];
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

/* ---- files --------------------------------------------------------------------------------------------------------------------- */
/* The city to and from a DOS file (z88dk's open, read and write on DOS 2's handles). */
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

        /* A 96x96 city is a valid prefix of a larger file.  Do not silently accept it (or any other file with the wrong map size). */
        if (read(fd, &extra, 1) > 0)           /* (at the end of the file DOS 2 gives its end of file error, which z88dk's read makes -1) */
            r = 2;
    }
    close(fd);
    return r;
}
