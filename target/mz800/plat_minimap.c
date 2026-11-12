/* The key to a mini map's colours, in the sidebar (columns MM_SIDE_COL up).  A colour is a pair of pens drawn as a checker (see plat_minimap.asm, which has the same
   pairs): here a cell's colour byte is the ink pen and the paper pen << 2 (0 green, 1 yellow, 2 blue, 3 red). */
#include <stdint.h>
#include "platform.h"

#ifdef HAVE_MINIMAP_SQUARE
#define PAIR(a, b) ((a) | ((b) << 2))
#define PG 0
#define PY 1
#define PB 2
#define PR 3

static const uint8_t pair_city[8] = {
    PAIR(PG, PG), PAIR(PB, PB), PAIR(PR, PR), PAIR(PY, PY), PAIR(PG, PB), PAIR(PG, PY), PAIR(PB, PY), PAIR(PY, PR)
};
static const uint8_t pair_ramp[9] = {                /* (the ninth: the city showing through where the density is 0) */
    PAIR(PG, PG), PAIR(PB, PB), PAIR(PG, PY), PAIR(PB, PY), PAIR(PY, PY), PAIR(PY, PR), PAIR(PR, PB), PAIR(PR, PR), PAIR(PG, PB)
};
static const uint8_t checker[8] = { 0xAA, 0x55, 0xAA, 0x55, 0xAA, 0x55, 0xAA, 0x55 };

struct key_entry {
    uint8_t colour;
    const char *label;
};

static const struct key_entry key_city[] = {
    { 0, "LAND" }, { 1, "WATER" }, { 4, "TREES" }, { 7, "ROAD" }, { 5, "HOUSES" }, { 6, "SHOPS" }, { 3, "INDUS" }, { 2, "CIVIC" }
};
static const struct key_entry key_power[] = {
    { 0, "LAND" }, { 1, "WATER" }, { 6, "POWER" }, { 2, "NO PWR" }
};
static const struct key_entry key_transport[] = {
    { 7, "ROAD" }, { 1, "WATER" }
};

static void swatch(uint8_t row, uint8_t pair)
{
    plat_put_tile(MM_SIDE_COL, row, checker, pair, 0);
}

static void key_list(const struct key_entry *k, uint8_t n)
{
    uint8_t i;

    for (i = 0; i < n; ++i) {
        swatch((uint8_t)(6 + i), pair_city[k[i].colour]);
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
    default:                                    /* a density: the colours 1 to 7 are its levels, low to high */
        plat_text_puts(MM_SIDE_COL, 6, "LOW");
        for (i = 1; i < 8; ++i)
            swatch((uint8_t)(6 + i), pair_ramp[i]);
        plat_text_puts(MM_SIDE_COL, 14, "HIGH");
        swatch(15, pair_ramp[8]);
        plat_text_puts((uint8_t)(MM_SIDE_COL + 1), 15, "CITY");
        break;
    }
}
#endif
