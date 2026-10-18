/* Rendering test for the ZX Spectrum tile drawing (platform/console), run under
   z88dk-ticks by test/tiles/run.py.  It draws every one of the engine's 345
   pictures through plat_put_tile, then the inverted cursor, then some text, and
   the harness compares the Spectrum's screen memory with the art. */
#include <stdint.h>
#include "engine.h"
#include "platform.h"

#define PER_ROW 32

int main(void)
{
    uint16_t i;

    plat_init();
    for (i = 0; i < NUM_TILE_ART + NUM_ZONE_ART; ++i)
        plat_put_tile((uint8_t)(i % PER_ROW), (uint8_t)(i / PER_ROW),
                      view_tile_art + i * 8u, (uint8_t)(i & 0x7F) | 0x08, 0);
    /* row 11: the cursor over three different pictures, then text, then a picture again */
    plat_put_tile(0, 12, view_tile_art + 5 * 8, 0x47, 1);
    plat_put_tile(1, 12, view_tile_art + 150 * 8, 0x47, 1);
    plat_puts(0, 14, "HELLO SIMCITY 123");
    plat_put_tile(0, 16, view_tile_art + 200 * 8, 0x46, 0);
    plat_puts(0, 18, "AFTER");
    return 0;
}
