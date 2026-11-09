/* Bar charts for the 3 bit 640x200 targets (the Multi 8 and the PC-8801), made of what their placers have: a picture of the filled part
   in the ink colour (mp_tile1) and over it the white dots of a checkerboard on the part that is not (plat_put_overlay), so the track
   is a grey of sorts (a platform that says NO_BAR_TRACK leaves the track out).  A cell is 8x8 pixels (each drawn twice across); a bar is six lines tall with a black line above and below.
   See HAVE_TEXT_COLOUR and HAVE_DEMAND_BARS in ui/platform.h. */
#include <stdint.h>
#include "platform.h"

#if defined(HAVE_TEXT_COLOUR) || defined(HAVE_DEMAND_BARS)
extern void mp_tile1(uint8_t col, uint8_t row, const uint8_t *art, uint8_t attr, uint8_t inverse);
#ifdef HAVE_CHART_CELL
/* A platform that cannot read its screen back, and would flash between the two draws below, says HAVE_CHART_CELL and draws a cell at once. */
extern void mp_chart_cell(uint8_t col, uint8_t row, const uint8_t *fill, const uint8_t *dots, uint8_t ink);
#endif

/* One cell of a bar: `fill` is the pixels (bit 7 the left) in the ink, `zero` pixels that are white as well (the zero mark). */
static void chart_cell(uint8_t col, uint8_t row, uint8_t fill, uint8_t zero, uint8_t ink)
{
#ifdef CHART_FAST
    uint8_t a[8], d[8];

    a[0] = a[7] = d[0] = d[7] = 0;                          /* (the first and last lines are blank) */
    a[1] = a[2] = a[3] = a[4] = a[5] = a[6] = fill;
#ifdef NO_BAR_TRACK
    d[1] = d[2] = d[3] = d[4] = d[5] = d[6] = zero;         /* (no checkerboard track: only the zero mark) */
#else
    {
        uint8_t k;

        for (k = 1; k < 7; ++k)
            d[k] = (uint8_t)(~fill & ((k & 1) ? 0xAA : 0x55) | zero);
    }
#endif
#else
    uint8_t a[8], d[8], k;

    for (k = 0; k < 8; ++k) {
        a[k] = d[k] = 0;
        if (k && k < 7) {
            a[k] = fill;
#ifdef NO_BAR_TRACK
            d[k] = zero;                                    /* (no checkerboard track: only the zero mark) */
#else
            d[k] = (uint8_t)(~fill & ((k & 1) ? 0xAA : 0x55) | zero);
#endif
        }
    }
#endif
#ifdef HAVE_CHART_CELL
    mp_chart_cell(col, row, a, d, ink);
#else
    mp_tile1(col, row, a, ink, 0);
    plat_put_overlay(col, row, d);
#endif
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
/* (CHART_FAST, which a platform that is slow at it says: the same cells by arithmetic, not by loops over the pixels: the Pasopia 7's status redraw)
   seven cells, 56 pixels: the zero mark at pixel 27, `level` pixels of green to the right or red to the left */
#ifdef CHART_FAST
/* the pixels of cell k (bit 7 the left) that are in lo <= x < hi */
static uint8_t span(int16_t lo, int16_t hi, uint8_t k)
{
    int16_t s = lo - 8 * k, e = hi - 8 * k;

    if (s < 0)
        s = 0;
    if (e > 8)
        e = 8;
    if (e <= s)
        return 0;
    return (uint8_t)((0xFF >> s) & (0xFF << (8 - e)));
}

void plat_demand(uint8_t col, uint8_t row, char name, int8_t level)
{
    uint8_t k, fill, zero;

    plat_put(col, row, (uint8_t)name);
    for (k = 0; k < 7; ++k) {
        zero = k == 3 ? 0x10 : 0;                           /* pixel 27 */
        fill = level > 0 ? span(28, (int16_t)(28 + level), k) : level < 0 ? span((int16_t)(27 + level), 27, k) : 0;
        chart_cell((uint8_t)(col + 1 + k), row, fill, zero, level > 0 ? COL_GREEN : COL_RED);
    }
}
#else
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
#endif
