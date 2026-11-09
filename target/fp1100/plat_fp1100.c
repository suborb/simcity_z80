/* Casio FP-1100 (CP/M 2.2) platform: 40x25 cells of 8x8 pixels in three planes, drawn by the sub-CPU's program (target/fp1100/sub.s.in) that the Z80 talks
   to a byte at a time (fp_sub.asm).  A cell costs about a tenth of a millisecond to send as a picture index and a good deal more as pixels, so
   the map's pictures and the text's glyphs are kept in the sub-CPU's spare video RAM and drawn by number, in runs of adjacent cells:
     bank 0 ($00)  pictures 0 to 255          bank 1 ($40)  pictures 256 to 344 (the engine's 345, see tools/extract_cpc_tiles.py --planes)
     bank 2 ($80)  glyphs: the character code is the picture (the font, white on black, and the boxes' line pieces, codes 1 to 6)
   The pictures are put there by fp_art (fp_sub.asm) at startup, read from the disc after the program: nothing of them is in the program's
   memory.  The glyphs are made here from the font.  Coloured text, icons, bars and sprites are built here from 8 bytes of art and an
   attribute (the Spectrum's: ink in bits 0-2, paper in 3-5) and sent as cells. */
#include <stdint.h>
#include <string.h>
#include "platform.h"
#include "engine.h"

extern void fp_addr(uint16_t a);
extern void fp_bank(uint8_t b);
extern void fp_fill(uint8_t n, uint8_t v);
extern void fp_mini(const uint8_t *data, uint8_t two);
extern void fp_text(const uint8_t *chars, uint8_t n, uint8_t attr);
extern void fp_tiles(const uint8_t *idx, uint8_t n);
extern void fp_cell(const uint8_t *planes);
extern void fp_ovl(const uint8_t *planes);
extern void fp_pat(const uint8_t *p);
extern void fp_inv(void);
extern void fp_keys(uint8_t *out);
extern uint8_t fp_tick(void);
extern const uint8_t font_8x8_bbc_system[];     /* 96 glyphs from the space, 8 bytes each (z88dk's) */
extern const uint8_t fp_box[];                  /* the line pieces, 1 to 6 (fp_data.asm) */

/* The leftmost pixel of a byte is bit 0 on this machine (the other way round from the Spectrum's art, the font, the icons and the bars): everything that goes to a plane
   is turned about here, and the pictures were turned when TILES were made (the Makefile). */
uint16_t fp_rowcell[25];                    /* the number of a row's first cell */
static uint8_t revtab[256];                     /* (made by plat_init) */
#define rev(b) (revtab[(uint8_t)(b)])

static void make_tables(void)
{
    static const uint8_t nib[16] = { 0x0, 0x8, 0x4, 0xC, 0x2, 0xA, 0x6, 0xE, 0x1, 0x9, 0x5, 0xD, 0x3, 0xB, 0x7, 0xF };
    uint16_t b;
    uint8_t r;

    for (b = 0; b < 256; ++b)
        revtab[b] = (uint8_t)((nib[b & 15] << 4) | nib[b >> 4]);
    for (r = 0; r < 25; ++r)
        fp_rowcell[r] = (uint16_t)r * 40;
}

#define TEXT_ATTR   7                           /* white on black */
#define MAP_ROW     6                           /* the map's cell rows: the only ones with a cache entry */
#define MAP_ROWS    19
#define PICTURES    345
#define CELL(col, row) ((uint16_t)0x2000 + (fp_rowcell[row] + (col)) * 8)

uint16_t fp_cache[MAP_ROWS * 40];           /* what each map cell shows: the picture, with bit 15 set if inverted; $FFFF if not known */
uint8_t fp_txt[25][40];                     /* the characters of the text drawn (plat_text_attr redraws them in colour) */
uint8_t fp_pend_bank, fp_pend_n;
static uint8_t sub_bank = 0xFF;
uint8_t fp_blank;                           /* plat_clear has run and nothing has been drawn since */
uint16_t fp_pend_cell;
static uint16_t sub_de = 0xFFFF;     /* (cell numbers; the sub program's DE as one) */
uint8_t fp_pend_idx[40];
static uint8_t planes[24];
static uint16_t clock_count;
#define STATUS_ROWS 6                           /* the rows above the map: panel cells keep a checksum of what they show (0: not known), and are not sent again if it is the same */
static uint16_t cell_sum[STATUS_ROWS * 40];

/* Send the run of pictures waiting: adjacent cells of one row, from one bank. */
static void flush(void)
{
    if (!fp_pend_n)
        return;
    if (sub_de != fp_pend_cell)
        fp_addr(0x2000 + fp_pend_cell * 8);
    if (sub_bank != fp_pend_bank) {
        fp_bank(fp_pend_bank);
        sub_bank = fp_pend_bank;
    }
    fp_tiles(fp_pend_idx, fp_pend_n);
    sub_de = fp_pend_cell + fp_pend_n;
    fp_pend_n = 0;
}

static void queue(uint8_t col, uint8_t row, uint8_t bank, uint8_t idx)
{
    uint16_t cell = fp_rowcell[row] + col;

    fp_blank = 0;
    if (fp_pend_n && (bank != fp_pend_bank || cell != fp_pend_cell + fp_pend_n || fp_pend_n == 40))
        flush();
    if (!fp_pend_n) {
        fp_pend_cell = cell;
        fp_pend_bank = bank;
    }
    fp_pend_idx[fp_pend_n++] = idx;
}

static uint8_t icon_state[14];                  /* how each icon was drawn: bit 0 selected, bit 1 affordable, bit 2 it is on the screen (0: not known) */

#ifdef HAVE_DEMAND_BARS
static void bars_clear(void);
#else
#define bars_clear()
#endif

/* Something other than an icon is drawn in this cell: if an icon was there, it is not any more. */
static void kill_icon(uint8_t col, uint8_t row)
{
    if ((row == 1 || row == 2) && col < 28)
        icon_state[col >> 1] = 0;
}

/* The cell is about to show something the caches do not know. */
static void forget(uint8_t col, uint8_t row)
{
    if (row < STATUS_ROWS)
        cell_sum[fp_rowcell[row] + col] = 0;
    else if (row < MAP_ROW + MAP_ROWS)
        fp_cache[fp_rowcell[row - MAP_ROW] + col] = 0xFFFF;
}

/* The art in the attribute's colours as three planes of eight lines, in planes[]. */
static void build(const uint8_t *art, uint8_t attr)
{
    uint8_t p, k, g, *o = planes;

    for (p = 0; p < 3; ++p) {
        uint8_t ink = attr & 1, paper = (attr >> 3) & 1;

        for (k = 0; k < 8; ++k) {
            g = rev(art[k]);
            *o++ = ink ? (paper ? 0xFF : g) : (paper ? (uint8_t)~g : 0);
        }
        attr >>= 1;
    }
}

/* A cell from the planes[] just built.  The video bus inverts what is written, so a direct write is the complement of the pixels (a picture copied inside the video RAM
   is not: that is a read and a write).  A cell of the panel that already shows these pixels is left alone (the panel is redrawn whenever one of its numbers changes). */
static void put_cell(uint8_t col, uint8_t row)
{
    uint8_t k;
    uint16_t sum = 0, *e = 0;

    fp_blank = 0;
    flush();
    for (k = 0; k < 24; ++k) {
        planes[k] = (uint8_t)~planes[k];
        sum = (uint16_t)((sum << 1 | sum >> 15) + planes[k]);
    }
    if (row < STATUS_ROWS) {
        sum |= 1;
        e = &cell_sum[fp_rowcell[row] + col];
        if (*e == sum)
            return;
    }
    forget(col, row);
    kill_icon(col, row);
    fp_txt[row][col] = 0;
    fp_addr(CELL(col, row));
    fp_cell(planes);
    sub_de = 0xFFFF;
    if (e)
        *e = sum;
}

/* The rest of plat_put_tile (fp_tile.asm has looked at the cache and found the cell not as wanted): the picture is queued, and the cursor's flipped. */
void fp_tile_slow(uint8_t col, uint8_t row, const uint8_t *art, uint8_t attr, uint8_t inverse)
{
    uint16_t n = (uint16_t)(art - view_tile_art) >> 3;

    (void)attr;
    fp_txt[row][col] = 0;
    if (n < 256)
        queue(col, row, 0x00, (uint8_t)n);
    else
        queue(col, row, 0x40, (uint8_t)(n - 256));
    if (inverse) {
        flush();
        fp_addr(CELL(col, row));
        fp_inv();
        sub_de = fp_rowcell[row] + col;
    }
}

/* 8 bytes of art in the colours of attr (swapped if `inverse`): the icons, the bars. */
void mp_tile1(uint8_t col, uint8_t row, const uint8_t *art, uint8_t attr, uint8_t inverse)
{
    if (inverse)
        attr = (uint8_t)(((attr & 7) << 3) | ((attr >> 3) & 7));
    build(art, attr & 0x3F);
    put_cell(col, row);
}

void plat_put_bitmap(uint8_t col, uint8_t row, const uint8_t *art)
{
    build(art, TEXT_ATTR);
    put_cell(col, row);
}

/* The pixels set in 8 bytes of art, white, over the cell: a sprite. */
void plat_put_overlay(uint8_t col, uint8_t row, const uint8_t *art)
{
    uint8_t k;

    fp_blank = 0;
    flush();
    forget(col, row);
    kill_icon(col, row);
    fp_txt[row][col] = 0;
    for (k = 0; k < 8; ++k)
        planes[k] = planes[k + 8] = planes[k + 16] = rev(art[k]);
    fp_addr(CELL(col, row));
    fp_ovl(planes);
    sub_de = 0xFFFF;
}

void plat_put(uint8_t col, uint8_t row, uint8_t ch)
{
    if (fp_txt[row][col] == ch)                            /* (the glyph is there already, in white) */
        return;
    forget(col, row);
    kill_icon(col, row);
    fp_txt[row][col] = ch;
    queue(col, row, 0x80, ch & 0x7F);
}

void plat_puts(uint8_t col, uint8_t row, const char *s)
{
    while (col < 40 && *s)
        plat_put(col++, row, (uint8_t)*s++);
}

void plat_text_puts(uint8_t col, uint8_t row, const char *s)
{
    plat_puts(col, row, s);
}

/* The art of a character: the font's glyph, a line piece of a frame, or nothing. */
static const uint8_t *glyph(uint8_t ch)
{
    static const uint8_t none[8];

    if (ch >= 32 && ch < 128)
        return font_8x8_bbc_system + (uint16_t)(ch - 32) * 8;
    if (ch >= 1 && ch <= 6)
        return fp_box + (uint16_t)(ch - 1) * 8;
    return none;
}

/* Send the run of characters waiting in text_run, in colours. */
static uint8_t text_run[40];

static void text_send(uint8_t col, uint8_t row, uint8_t n, uint8_t attr)
{
    flush();
    fp_addr(CELL(col, row));
    fp_text(text_run, n, attr);
    sub_de = fp_rowcell[row] + col + n;
}

/* Recolours n cells of the text already drawn: the sub program draws the glyphs in the colours.  A cell of the panel that already shows it is left alone. */
void plat_text_attr(uint8_t col, uint8_t row, uint8_t n, uint8_t attr)
{
    uint8_t run = 0, start = col;

    fp_blank = 0;
    if (col + n > 40)
        n = (uint8_t)(40 - col);
    while (n--) {
        uint8_t ch = fp_txt[row][col] & 0x7F;
        uint16_t hash = (uint16_t)((ch | 0x80) << 8 | (uint8_t)(attr << 1)), *e = 0;

        if (row < STATUS_ROWS) {                        /* (a hash a plane checksum cannot be: bit 0 is clear) */
            e = &cell_sum[fp_rowcell[row] + col];
            if (*e == hash) {
                if (run) {
                    text_send(start, row, run, attr);
                    run = 0;
                }
                ++col;
                continue;
            }
        }
        forget(col, row);
        kill_icon(col, row);
        if (e)
            *e = hash;
        fp_txt[row][col] = ch | 0x80;                   /* (coloured: a plain plat_put of it must draw it again) */
        if (!run)
            start = col;
        text_run[run++] = ch;
        ++col;
    }
    if (run)
        text_send(start, row, run, attr);
}

/* ---- the mini maps ----
   Tile row ty (0 to 95) of the mini map is two lines of 192 pixels at the left of the screen, a tile 2x2 pixels, and the colours are 3 bits (blue, red, green) with
   bit 3 for the city shown dim where a view has none: a checker.  Four tiles are a byte (the leftmost pixel is bit 0), a byte a cell and plane. */
static uint8_t mini[144];

void plat_put_minirow(uint8_t ty, const uint8_t *colours, const uint8_t *base, uint8_t view)
{
    uint8_t p, c, t, a, b, sh, mask, dim = 0, *o = mini;
    const uint8_t *k;

    (void)base;
    (void)view;
    flush();
    fp_blank = 0;
    for (c = 0; c < 96; ++c)
        if (colours[c] & 8) {
            dim = 1;
            break;
        }
    for (p = 0; p < 3; ++p) {
        mask = (uint8_t)(1 << p);
        k = colours;
        for (c = 0; c < 24; ++c) {
            a = b = 0;
            for (t = 0; t < 4; ++t) {
                uint8_t col = *k++;

                if (col & mask) {
                    sh = (uint8_t)(t * 2);
                    if (col & 8) {
                        a |= (uint8_t)(1 << sh);
                        b |= (uint8_t)(2 << sh);
                    } else
                        a = b = (uint8_t)(a | (3 << sh));
                }
            }
            *o++ = (uint8_t)~a;                         /* (direct writes are complements) */
            if (dim)
                *o++ = (uint8_t)~b;
        }
    }
    fp_addr(0x2000 + fp_rowcell[ty >> 2] * 8 + (ty & 3) * 2);
    fp_mini(mini, dim);
    sub_de = 0xFFFF;
}

void plat_clear(void)
{
    uint8_t r;

    if (fp_blank)  /* (cleared already, and nothing drawn since) */
        return;
    for (r = 0; r < 14; ++r)
        icon_state[r] = 0;
    flush();
    memset(fp_txt, ' ', sizeof(fp_txt));
    memset(fp_cache, 0xFF, sizeof(fp_cache));
    memset(cell_sum, 0, sizeof(cell_sum));
    bars_clear();
    fp_addr(0x2000);
    for (r = 0; r < 31; ++r)
        fp_fill(32, 0xFF);                              /* (a direct write of $FF is a blank cell) */
    fp_fill(8, 0xFF);
    sub_de = 1000;
    fp_blank = 1;
}

void plat_text_clear(void)
{
    plat_clear();
}

void plat_flush(void)
{
    flush();
}

void plat_exit(void)
{
    flush();
}

/* The glyphs into the sub-CPU's spare video RAM (the pictures are there already: fp_art put them). */
static void upload_glyphs(void)
{
    uint16_t n;
    uint8_t k;

    for (n = 0; n < 128; ++n) {
        const uint8_t *g = glyph((uint8_t)n);
        uint8_t r[8];

        for (k = 0; k < 8; ++k)
            r[k] = rev(g[k]);
        fp_addr(0xC000 + n * 32);
        for (k = 0; k < 3; ++k)
            fp_pat(r);
    }
}

extern void fp_boot(void);
extern void fp_art(void);

void plat_init(void)
{
    fp_boot();
    fp_art();
    make_tables();
    upload_glyphs();
    plat_clear();
}

/* ---- keys ----
   The keyboard is a matrix the sub program reads a column at a time (column 1 to 12, seven row bits).  Takeda's table of it, by column and bit: */
static const uint8_t keymap[12][7] = {
    { 0, 0, 0, 0, 0, 0, 0 },                                       /* 1: shift, ctrl, ... */
    { 'a', KEY_ESC, '-', 'q', 'z', '*', 0 },
    { 's', '1', '+', 'w', 'x', '/', 0 },
    { 'd', '2', '3', 'e', 'c', 0, '.' },
    { 'f', '3', '6', 'r', 'v', KEY_RIGHT, 0 },
    { 'g', '4', '9', 't', 'b', 0, ' ' },
    { 'h', '5', '8', 'y', 'n', KEY_DOWN, '0' },
    { 'j', '6', '5', 'u', 'm', KEY_UP, '2' },
    { 'k', '7', '4', 'i', ',', 0, '1' },
    { 'l', '8', '7', 'o', '.', KEY_LEFT, 0 },
    { ';', '9', KEY_ENTER, 'p', '/', 0, 0 },
    { ':', '0', '^', '@', 0, 0, '-' },
};
static uint8_t last_col, last_rows, held, hold_count;

uint8_t plat_key(void)
{
    uint8_t kb[3], key = 0, b, code = 0;

    flush();
    fp_keys(kb);                                        /* shift, the column of a key that is down (0: none), its rows */
    if (kb[1]) {
        for (b = 0; b < 7 && !(kb[2] & (1 << b)); ++b)
            ;
        code = b < 7 ? keymap[kb[1] - 1][b] : 0;
    }
    if (code) {
        if (kb[1] != last_col || kb[2] != last_rows) {  /* a key that was not down */
            key = code;
            hold_count = 0;
        } else if (++hold_count >= 8 && !(hold_count & 1))  /* auto repeat: while the key stays down */
            key = code;
    }
    last_col = code ? kb[1] : 0;
    last_rows = code ? kb[2] : 0;
    if (key >= 'a' && key <= 'z' && kb[0])
        key = (uint8_t)(key - 'a' + 'A');
    else if (kb[0] && key >= KEY_LEFT && key <= KEY_UP)
        key = (uint8_t)(key == KEY_LEFT ? KEY_FAR_LEFT : key == KEY_RIGHT ? KEY_FAR_RIGHT : key == KEY_DOWN ? KEY_FAR_DOWN : KEY_FAR_UP);
    return key;
}

/* ---- time ----  A frame is TICKS_PER_FRAME ticks of the sub-CPU's timer (the ROM left it running, and the sub program counts its overflows, about 0.67 ms apart: the Z80 has nothing of
   its own).  If the frame took longer, plat_idle does not wait; the wait is bounded, in case the timer is not running. */
#ifndef TICKS_PER_FRAME
#define TICKS_PER_FRAME 30                      /* about 20 ms (a tick is 0.67 ms): 50 frames a second */
#endif

uint16_t plat_clock(void)
{
    return clock_count;
}

void plat_idle(void)
{
    uint8_t n, ticks = 0;

    flush();
    ++clock_count;
    for (n = 0; ticks < TICKS_PER_FRAME && n < 250; ++n)
        ticks += fp_tick();
}

/* ---- the line editor and the files ---- */

/* ENTER ends, ESC cancels, backspace takes a letter back. */
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
        if ((k == KEY_LEFT || k == 8) && n) {
            buf[--n] = 0;
            plat_put((uint8_t)(col + n), row, ' ');
        } else if (k >= (spaces ? ' ' : '!') && k < 127 && n < max) {
            buf[n++] = (char)k;
            buf[n] = 0;
            plat_put((uint8_t)(col + n - 1), row, k);
        }
    }
}

/* ---- the bar charts ----  (target/common/plat_charts.c made of mp_tile1 and an overlay: here a cell is worked out whole and sent once, so it never shows half of itself) */
/* One cell of a bar: `fill` is the pixels (bit 7 the left) in the ink colour, `zero` pixels that are white as well (and, without NO_BAR_TRACK, the dots of a checkerboard that are
   white on the part that is not filled); six lines tall with a black line above and below. */
static void chart_cell(uint8_t col, uint8_t row, uint8_t fill, uint8_t zero, uint8_t ink)
{
    uint8_t k, p, a, d;

    for (k = 0; k < 8; ++k) {
        a = d = 0;
        if (k && k < 7) {
            a = fill;
#ifdef NO_BAR_TRACK
            d = zero;                                       /* (no checkerboard track: only the zero mark) */
#else
            d = (uint8_t)(~fill & ((k & 1) ? 0xAA : 0x55) | zero);
#endif
        }
        for (p = 0; p < 3; ++p)
            planes[p * 8 + k] = rev((ink >> p) & 1 ? (uint8_t)(a | d) : d);
    }
    put_cell(col, row);
}

#ifdef HAVE_TEXT_COLOUR
void plat_bar(uint8_t col, uint8_t row, uint8_t cells, uint8_t fill, uint8_t attr)
{
    uint8_t i;
    int16_t px;

    for (i = 0; i < cells; ++i) {
        px = (int16_t)fill - 8 * i;
        chart_cell((uint8_t)(col + i), row, px >= 8 ? 0xFF : px <= 0 ? 0 : (uint8_t)(0xFF << (8 - px)), 0, (uint8_t)(attr & 7));
    }
}
#endif

#ifdef HAVE_DEMAND_BARS
/* the bars drawn: a bar whose level is the same, and whose cells have not been drawn over since (their checksums are still there), is not worked out again */
static struct { uint8_t col, row, valid; int8_t level; } bars[4];

/* seven cells, 56 pixels: the zero mark at pixel 27, `level` pixels of green to the right or red to the left */
void plat_demand(uint8_t col, uint8_t row, char name, int8_t level)
{
    uint8_t k, b, fill, zero, same, free_slot = 4;
    int16_t x;

    for (b = 0; b < 4; ++b) {
        if (bars[b].valid && bars[b].col == col && bars[b].row == row)
            break;
        if (!bars[b].valid)
            free_slot = b;
    }
    if (b == 4)
        b = free_slot < 4 ? free_slot : 0;
    same = bars[b].valid && bars[b].col == col && bars[b].row == row && bars[b].level == level && fp_txt[row][col] == (uint8_t)name;
    for (k = 0; same && k < 7; ++k)
        if (row < STATUS_ROWS && !cell_sum[fp_rowcell[row] + col + 1 + k])
            same = 0;
    if (same)
        return;
    bars[b].col = col;
    bars[b].row = row;
    bars[b].level = level;
    bars[b].valid = 1;
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
        chart_cell((uint8_t)(col + 1 + k), row, fill, zero, level > 0 ? COL_GREEN : COL_RED);
    }
}
#endif

/* plat_icons (target/common/plat_icons.c, HAVE_ICON_CACHE) asks before it works an icon out: 1 if it was drawn like this and nothing has drawn over it since. */
uint8_t plat_icon_same(uint8_t icon, uint8_t selected, uint8_t affordable)
{
    uint8_t s = 4 | selected | (uint8_t)(affordable << 1);

    if (icon_state[icon] == s)
        return 1;
    icon_state[icon] = s;
    return 0;
}

/* An icon (plat_icons, HAVE_ICONS_STORED): its four cells are pictures in the sub program's store (bank 2 from index 128, tools/fp1100_art.py: those of the dimmed icons 56
   on), queued like text; the selected icon is flipped afterwards. */
void plat_icon_stored(uint8_t icon, uint8_t selected, uint8_t affordable)
{
    uint8_t r, c, col, row, idx;

    for (r = 0; r < 2; ++r)
        for (c = 0; c < 2; ++c) {
            col = (uint8_t)(icon * 2 + c);
            row = (uint8_t)(1 + r);
            idx = (uint8_t)(128 + icon * 4 + r * 2 + c + (affordable ? 0 : 56));
            forget(col, row);
            fp_txt[row][col] = 0;
            queue(col, row, 0x80, idx);
        }
    if (selected) {
        flush();
        for (r = 0; r < 2; ++r)
            for (c = 0; c < 2; ++c) {
                col = (uint8_t)(icon * 2 + c);
                row = (uint8_t)(1 + r);
                fp_addr(CELL(col, row));
                fp_inv();
                sub_de = fp_rowcell[row] + col;
            }
    }
}

#ifdef HAVE_DEMAND_BARS
static void bars_clear(void)
{
    uint8_t b;

    for (b = 0; b < 4; ++b)
        bars[b].valid = 0;
}
#endif
