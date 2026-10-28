/* The key to a square mini map's colours for the 3 bit 640x200 targets (the PC-8801 and the Multi 8: HAVE_MINIMAP_SQUARE), in the sidebar's rows 6 to 14
   (column MM_SIDE_COL up): a cell of the colour and what it is.  The colours are the builder's (minimap_640x200_3bpp.asm): 1 blue, 2 red,
   3 magenta, 4 green, 5 cyan, 6 yellow, 7 white; black, the land, shows nothing. */
#include <stdint.h>
#include "platform.h"

#ifdef HAVE_MINIMAP_SQUARE
extern void mp_tile1(uint8_t col, uint8_t row, const uint8_t *art, uint8_t attr, uint8_t inverse);

struct key_entry {
    uint8_t colour;
    const char *label;
};

static const uint8_t key_solid[8] = { 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF };
static const struct key_entry key_city[] = {
    { 0, "LAND" }, { 1, "WATER" }, { 4, "TREES" }, { 7, "ROAD" }, { 5, "HOUSES" }, { 6, "SHOPS" }, { 3, "INDUS" }, { 2, "CIVIC" }
};
static const struct key_entry key_power[] = {
    { 0, "LAND" }, { 1, "WATER" }, { 6, "POWER" }, { 2, "NO PWR" }
};
static const struct key_entry key_transport[] = {
    { 7, "ROAD" }, { 1, "WATER" }
};

static void key_list(const struct key_entry *k, uint8_t n)
{
    uint8_t i;

    for (i = 0; i < n; ++i) {
        if (k[i].colour)
            mp_tile1(MM_SIDE_COL, (uint8_t)(6 + i), key_solid, k[i].colour, 0);
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
            mp_tile1(MM_SIDE_COL, (uint8_t)(6 + i), key_solid, i, 0);
        plat_text_puts(MM_SIDE_COL, 14, "HIGH");
        break;
    }
}
#endif
