/* Rendering test for the ZX Spectrum platform (target/zx), run under z88dk-ticks by test/tiles/run.py.  It draws
   every one of the engine's 345 pictures through plat_put_tile, then the inverted cursor, then some text, and
   the harness compares the Spectrum's screen memory with the art (and with a font the harness puts in the ROM). */
#include <stdint.h>
#include "engine.h"
#include "platform.h"
#include "sprites.h"

#define PER_ROW 32

int main(void)
{
    uint16_t i;

    plat_init();
    plat_put_tile(31, 17, view_tile_art, 0x47, 0);              /* wiped by plat_clear: the screen is blank again */
    plat_clear();
    for (i = 0; i < NUM_TILE_ART + NUM_ZONE_ART; ++i)
        plat_put_tile((uint8_t)(i % PER_ROW), (uint8_t)(i / PER_ROW),
                      view_tile_art + i * 8u, (uint8_t)(i & 0x7F) | 0x08, 0);
    /* row 11: the cursor over three different pictures, then text, then a picture again */
    plat_put_tile(0, 12, view_tile_art + 5 * 8, 0x47, 1);
    plat_put_tile(1, 12, view_tile_art + 150 * 8, 0x47, 1);
    plat_puts(0, 14, "HELLO SIMCITY 123");
    plat_put_tile(0, 16, view_tile_art + 200 * 8, 0x46, 0);
    plat_puts(0, 18, "AFTER");
    plat_puts(28, 22, "ABCDEFGH");                            /* ABCD, then EFGH wrapped to the start of row 23 */
    plat_puts(30, 23, "XYZ");                                 /* XY, then the end of the screen: Z is not drawn */
    plat_puts(5, 19, "");
    plat_put(20, 19, '~');
    /* rows 20, 21: the five sprites, each over a road tile (even ones) or dirt (odd ones), 2x2 cells */
    {
        uint8_t id, q, art[8];
        for (id = 0; id < 5; ++id)
            for (q = 0; q < 4; ++q) {
                sprite_or(id, q & 1, q >> 1, view_tile_art + ((id & 1) ? 2 : 7) * 8, art);
                plat_put_bitmap((uint8_t)(id * 3 + (q & 1)), (uint8_t)(20 + (q >> 1)), art);
            }
    }
    return 0;
}
