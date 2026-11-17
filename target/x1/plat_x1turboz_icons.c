/* The Amiga toolbar, scaled into the X1's existing 16x16 icon slots.
   Each button is four 8x8 pictures after the map and animation atlas. */
#include <stdint.h>
#include "engine.h"
#include "platform.h"

void plat_icon_stored(uint8_t icon, uint8_t selected, uint8_t affordable)
{
    uint8_t r, c;
    uint16_t first = (uint16_t)(547 + (affordable ? 0 : 56) + icon * 4);

    for (r = 0; r != 2; ++r)
        for (c = 0; c != 2; ++c)
            plat_put_tile((uint8_t)(icon * 2 + c), (uint8_t)(1 + r),
                          view_tile_art + (uint16_t)((first + r * 2 + c) * 8),
                          0, selected);
}
