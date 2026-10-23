/* Bar charts for the 3 bit 640x200 targets (the Multi 8 and the PC-8801), made of what their placers have: a picture of the filled part
   in the ink colour (mp_tile1) and over it the white dots of a checkerboard on the part that is not (plat_put_overlay), so the track
   is a grey of sorts.  A cell is 8x8 pixels (each drawn twice across); a bar is six lines tall with a black line above and below.
   See HAVE_TEXT_COLOUR and HAVE_DEMAND_BARS in ui/platform.h. */
#include <stdint.h>
#include "platform.h"

#if defined(HAVE_TEXT_COLOUR) || defined(HAVE_DEMAND_BARS)
extern void mp_tile1(uint8_t col, uint8_t row, const uint8_t *art, uint8_t attr, uint8_t inverse);

/* One cell of a bar: `fill` is the pixels (bit 7 the left) in the ink, `zero` pixels that are white as well (the zero mark). */
static void chart_cell(uint8_t col, uint8_t row, uint8_t fill, uint8_t zero, uint8_t ink)
{
    uint8_t a[8], d[8], k;

    for (k = 0; k < 8; ++k) {
        a[k] = d[k] = 0;
        if (k && k < 7) {
            a[k] = fill;
            d[k] = (uint8_t)(~fill & ((k & 1) ? 0xAA : 0x55) | zero);
        }
    }
    mp_tile1(col, row, a, ink, 0);
    plat_put_overlay(col, row, d);
}
#endif

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
/* seven cells, 56 pixels: the zero mark at pixel 27, `level` pixels of green to the right or red to the left */
void plat_demand(uint8_t col, uint8_t row, char name, int8_t level)
{
    uint8_t k, b, fill, zero;
    int16_t x;

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
