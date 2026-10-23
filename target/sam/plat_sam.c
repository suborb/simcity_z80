/* SAM Coupe platform: the drawing (the tool icons too), the screen set-up and the keyboard are in plat_sam.asm; this has the
   frame counter. */
#include <stdint.h>
#include "platform.h"

static uint16_t clock_count;

uint16_t plat_clock(void) { return clock_count; }
void plat_idle(void) { ++clock_count; }
void plat_flush(void) {}

#ifdef HAVE_MINIMAP_SQUARE
/* The key to a mini map's colours, in the sidebar's rows 6 to 14 (columns 24 to 31): a swatch of the colour and what it is.  The colours
   are the ST palette entries plat_sam.asm's mm_tabs gives each view's eight. */
extern void plat_swatch(uint8_t col, uint8_t row, uint8_t cells, uint8_t index);

struct key_entry {
    uint8_t colour;
    const char *label;
};

static const struct key_entry key_city[] = {
    { 6, "LAND" }, { 1, "WATER" }, { 2, "TREES" }, { 15, "ROAD" }, { 10, "HOUSES" }, { 9, "SHOPS" }, { 14, "INDUS" }, { 12, "CIVIC" }
};
static const struct key_entry key_power[] = {
    { 6, "LAND" }, { 1, "WATER" }, { 14, "POWER" }, { 12, "NO PWR" }
};
static const struct key_entry key_transport[] = {
    { 15, "ROAD" }, { 1, "WATER" }
};
static const uint8_t ramp[7] = { 3, 11, 10, 14, 12, 13, 15 };    /* a density's levels 1 to 7 (none shows the city, dimmed) */

static void key_list(const struct key_entry *k, uint8_t n)
{
    uint8_t i;

    for (i = 0; i < n; ++i) {
        plat_swatch(24, (uint8_t)(6 + i), 1, k[i].colour);
        plat_text_puts(25, (uint8_t)(6 + i), k[i].label);
    }
}

void plat_minimap_key(uint8_t view)
{
    uint8_t i;

    for (i = 6; i < 16; ++i)
        plat_text_puts(24, i, "        ");
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
    default:                                    /* a density: low, the seven levels, high */
        plat_text_puts(24, 6, "LOW");
        for (i = 0; i < 7; ++i)
            plat_swatch(24, (uint8_t)(7 + i), 3, ramp[i]);
        plat_text_puts(24, 14, "HIGH");
        break;
    }
}
#endif
