/* SPC-1000 platform, the parts in C: the demand bars. */
#include <stdint.h>
#include "platform.h"

#ifdef HAVE_DEMAND_BARS
/* plat_demand() draws a demand indicator (see ui/platform.h): the letter, then seven cells, 56 pixels, with a zero mark (a tall tick) at pixel 27 and `level`
   (-27 to 27) pixels of bar from it, six lines tall: to the right if more is wanted and to the left if there is too much.  The empty part of the track is a
   dotted line.  A cell is drawn as it is (plat_put_tile with inverse set: light on dark), which is how the panel is. */
void plat_demand(uint8_t col, uint8_t row, char name, int8_t level)
{
    uint8_t k, b, m, y, a[8];
    int16_t x;

    plat_put(col, row, (uint8_t)name);
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
