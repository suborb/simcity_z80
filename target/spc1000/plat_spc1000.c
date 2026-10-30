/* SPC-1000 platform, the parts in C: the demand bars. */
#include <stdint.h>
#include "platform.h"
#include "menu.h"

extern uint8_t mp_cg;
extern void plat_put_raw(uint8_t col, uint8_t row, const uint8_t *eight);
extern void plat_swatch(uint8_t col, uint8_t row, uint8_t pair);

#ifdef HAVE_DEMAND_BARS
/* plat_demand() draws a demand indicator (see ui/platform.h): the letter, then seven cells, 56 pixels, with a zero mark (a tall tick) at pixel 27 and `level`
   (-27 to 27) pixels of bar from it, six lines tall: to the right if more is wanted and to the left if there is too much.  The empty part of the track is a
   dotted line.  A cell is drawn as it is (plat_put_tile with inverse set: light on dark), which is how the panel is. */
void plat_demand(uint8_t col, uint8_t row, char name, int8_t level)
{
    uint8_t k, b, m, y, a[8];
    int16_t x, half;

    plat_put(col, row, (uint8_t)name);
    if (mp_cg) {                            /* in a mini map: seven bytes of four pixels, blue; the mark yellow, the bar red (half the pixels) */
        half = (int16_t)level / 2;
        for (k = 0; k < 7; ++k) {
            for (y = 0; y < 8; ++y)
                a[y] = 0xAA;
            for (b = 0; b < 4; ++b) {
                uint8_t sh = (uint8_t)(6 - 2 * b);
                uint8_t v, lo, hi;                  /* the pixel's colour, and the lines it fills */
                uint8_t bar = 0;

                x = 4 * k + b;
                if (half > 0) {
                    if (x > 13 && x <= 13 + half)
                        bar = 1;
                } else if (half < 0) {
                    if (x < 13 && x >= 13 + half)
                        bar = 1;
                }
                if (x == 13) {
                    v = 1; lo = 0; hi = 8;
                } else if (bar) {
                    v = 3; lo = 2; hi = 6;
                } else if (!(x & 1)) {
                    v = 1; lo = 3; hi = 5;
                } else
                    continue;
                for (y = lo; y < hi; ++y)
                    a[y] = (uint8_t)((a[y] & ~(3 << sh)) | (v << sh));
            }
            plat_put_raw((uint8_t)(col + 1 + k), row, a);
        }
        return;
    }
    for (k = 0; k < 7; ++k) {
        for (y = 0; y < 8; ++y)
            a[y] = 0;
        for (b = 0; b < 8; ++b) {
            m = (uint8_t)(0x80 >> b);
            x = 8 * k + b;
            if (x == 27) {
                for (y = 0; y < 8; ++y)
                    a[y] |= m;
            } else if (level > 0 ? x > 27 && x <= 27 + level : level < 0 && x < 27 && x >= 27 + level) {
                for (y = 1; y < 7; ++y)
                    a[y] |= m;
            } else if (!(x & 1)) {
                a[3] |= m;
                a[4] |= m;
            }
        }
        plat_put_tile((uint8_t)(col + 1 + k), row, a, 0, 1);
    }
}
#endif

#ifdef HAVE_MINIMAP
/* plat_minimap_key(): the key to the colours of a mini map, in the sidebar's rows 6 to 14 (columns 24 to 31): a swatch of the palette byte
   (plat_put_minirow's: the even colour in bits 3-2, the odd in bits 1-0) and what it is. */
struct key_entry {
    uint8_t pair;
    const char *label;
};

static const struct key_entry key_city[] = {
    { 0x00, "LAND" }, { 0x0A, "WATER" }, { 0x05, "ROAD" }, { 0x0F, "HOUSES" }, { 0x0C, "SHOPS" }, { 0x0E, "INDUS" }, { 0x0D, "CIVIC" }
};
static const struct key_entry key_power[] = {
    { 0x00, "LAND" }, { 0x0A, "WATER" }, { 0x05, "POWER" }, { 0x0F, "NO PWR" }
};
static const struct key_entry key_transport[] = {
    { 0x05, "ROAD" }, { 0x0A, "WATER" }
};
static const uint8_t ramp[4] = { 0x01, 0x05, 0x07, 0x0F };      /* a density's levels (none shows the city, dim) */

static void key_list(const struct key_entry *k, uint8_t n)
{
    uint8_t i;

    for (i = 0; i < n; ++i) {
        plat_swatch(MM_SIDE_COL, (uint8_t)(6 + i), k[i].pair);
        plat_text_puts((uint8_t)(MM_SIDE_COL + 1), (uint8_t)(6 + i), k[i].label);
    }
}

void plat_minimap_key(uint8_t view)
{
    uint8_t i;

    for (i = 6; i < 16; ++i)
        plat_text_puts(MM_SIDE_COL, i, "        ");
    switch (view) {
    case 1:
        key_list(key_city, sizeof(key_city) / sizeof(key_city[0]));
        break;
    case 6:
        key_list(key_power, sizeof(key_power) / sizeof(key_power[0]));
        break;
    case 7:
        key_list(key_transport, sizeof(key_transport) / sizeof(key_transport[0]));
        break;
    default:                                /* a density: low, the levels, high */
        plat_text_puts(MM_SIDE_COL, 6, "LOW");
        for (i = 0; i < 4; ++i)
            plat_swatch(MM_SIDE_COL, (uint8_t)(7 + i), ramp[i]);
        plat_text_puts(MM_SIDE_COL, 11, "HIGH");
        break;
    }
}
#endif

#ifdef HAVE_FILES
/* A city is saved to the cassette as one file in the machine's own format (z88dk's tape_save, arch/spc1000.h): the map is its data and the
   31 byte city header is kept in the file's own header.  The deck is the player's: RECORD and PLAY (or PLAY) first, and the driver waits for
   it to run; Shift and Break together give up. */
extern int tape_save(const char *name, const void *addr, uint16_t len, const void *user, uint16_t ulen) __smallc;
extern int tape_load_to(const char *name, void *buf, uint16_t len, void *user, uint16_t ulen) __smallc;

static uint8_t wait_key(void)
{
    uint8_t k;

    while (!(k = plat_key()))
        plat_idle();
    return k;
}

uint8_t plat_file_save(const char *name, const uint8_t *a, uint16_t alen, const uint8_t *b, uint16_t blen)
{
    plat_puts((uint8_t)(menu_col + 2), (uint8_t)(menu_row + 5), "RECORD+PLAY, THEN A KEY ");   /* in the dialogue's box, where its keys were */
    if (wait_key() == KEY_ESC)
        return 1;
    plat_puts((uint8_t)(menu_col + 2), (uint8_t)(menu_row + 5), "SHIFT+BREAK STOPS      ");
    return tape_save(name, b, blen, a, alen) ? 1 : 0;
}

uint8_t plat_file_load(const char *name, uint8_t *a, uint16_t alen, uint8_t *b, uint16_t blen)
{
    int r;

    plat_puts((uint8_t)(menu_col + 2), (uint8_t)(menu_row + 5), "PLAY.  SHIFT+BREAK STOPS");
    r = tape_load_to(name, b, blen, a, alen);
    if (r == -1)
        return 1;                           /* nothing read */
    return r == (int)blen ? 0 : 2;          /* the map is whole, or partly overwritten */
}
#endif
