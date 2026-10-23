/* NEC PC-8801 platform: the drawing, the screen set-up and the keyboard are in plat_pc88.asm; this has the tool icons, the
   frame counter and the files. */
#include <stdint.h>
#include "platform.h"

static uint16_t clock_count;

extern const uint8_t mp_icons[];

/* a 1 bit picture in the colours of an attribute */
extern void mp_tile1(uint8_t col, uint8_t row, const uint8_t *art, uint8_t attr, uint8_t inverse);

/* The tool icons: 16x16 pictures, four cells each. */
#define NUM_ICONS 14

void plat_icons(uint8_t selected)
{
    uint8_t i, r, c, cell;

    for (i = 0; i < NUM_ICONS; ++i)
        for (r = 0; r < 2; ++r)
            for (c = 0; c < 2; ++c) {
                cell = (uint8_t)(i * 4 + r * 2 + c);
                mp_tile1((uint8_t)(i * 2 + c), (uint8_t)(1 + r), mp_icons + cell * 8,
                         mp_icons[NUM_ICONS * 32 + cell], i == selected);
            }
}

uint16_t plat_clock(void) { return clock_count; }
void plat_idle(void) { ++clock_count; }
void plat_flush(void) {}
