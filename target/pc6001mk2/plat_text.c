/* The coloured budget and evaluation screens (HAVE_TEXT_COLOUR: ui/budget.c, ui/evaluation.c): recolouring text already drawn, and bar charts.  In the modal overlay with them.
   The attributes are the Spectrum's (ink bits 0-2, paper bits 3-5: black, blue, red, magenta, green, cyan, yellow, white), and there are four pens (0 green, 1 yellow, 2 blue,
   3 red), so: black is blue (the text's own paper: yellow on blue is the normal text), blue, red and magenta are red, green and cyan are green, yellow and white are yellow. */
#include <stdint.h>
#include "platform.h"
PLAT_CODE_MODAL_OVERLAY
PLAT_CONST_MODAL_OVERLAY

#ifdef HAVE_TEXT_COLOUR
static const uint8_t pen_of[8] = { 2, 3, 3, 3, 0, 0, 1, 1 };

/* n cells from (col, row): the glyph's pixels take the ink and the rest the paper.  Whatever pens a cell has, its background is the pen of its top left pixel (the font keeps the left
   column and the top row of a glyph clear), so the glyph is the pixels that differ from that in either plane. */
void plat_text_attr(uint8_t col, uint8_t row, uint8_t n, uint8_t attr)
{
    uint8_t ink = pen_of[attr & 7], paper = pen_of[(attr >> 3) & 7];
    uint8_t i0 = (ink & 1) ? 0xFF : 0, i1 = (ink & 2) ? 0xFF : 0, p0 = (paper & 1) ? 0xFF : 0, p1 = (paper & 2) ? 0xFF : 0;
    uint8_t *a = (uint8_t *)(0xC000u + (uint16_t)row * 320 + col), *b, y, bg0, bg1, m;

    for (; n; --n, ++a) {
        b = a + 0x2000;
        bg0 = (*a & 0x80) ? 0xFF : 0;
        bg1 = (*b & 0x80) ? 0xFF : 0;
        for (y = 0; y < 8; ++y, a += 40, b += 40) {
            m = (uint8_t)((*a ^ bg0) | (*b ^ bg1));
            *a = (uint8_t)((i0 & m) | (p0 & ~m));
            *b = (uint8_t)((i1 & m) | (p1 & ~m));
        }
        a -= 320;
    }
}

/* a bar `cells` wide (a cell: a picture of six lines of the fill with a blank line above and below): the first `fill` pixels in the ink, the rest in the paper */
void plat_bar(uint8_t col, uint8_t row, uint8_t cells, uint8_t fill, uint8_t attr)
{
    uint8_t i, k, f, art[8];
    int16_t px;
    uint8_t colour = (uint8_t)(pen_of[attr & 7] | (pen_of[(attr >> 3) & 7] << 2));

    art[0] = art[7] = 0;
    for (i = 0; i < cells; ++i) {
        px = (int16_t)fill - 8 * i;
        f = px >= 8 ? 0xFF : px <= 0 ? 0 : (uint8_t)(0xFF << (8 - px));
        for (k = 1; k < 7; ++k)
            art[k] = f;
        plat_put_tile((uint8_t)(col + i), row, art, colour, 0);     /* (the buffer is not in the art table: the placer always draws it) */
    }
}
#endif
