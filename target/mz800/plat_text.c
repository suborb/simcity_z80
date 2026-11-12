/* The coloured budget and evaluation screens (HAVE_TEXT_COLOUR): recolouring drawn text, and bar charts.  Attributes are the Spectrum's (ink bits 0-2, paper 3-5); the four pens
   (0 green, 1 yellow, 2 blue, 3 red) take: black blue, blue/red/magenta red, green/cyan green, yellow/white yellow. */
#include <stdint.h>
#include "platform.h"
extern void mz_recolour(uint8_t *cell, uint8_t n, uint8_t ink, uint8_t paper) __smallc;

#ifdef HAVE_TEXT_COLOUR
static const uint8_t pen_of[8] = { 2, 3, 3, 3, 0, 0, 1, 1 };

/* n cells from (col, row): the glyph's pixels take the ink and the rest the paper (mz_recolour, in assembler: 80cc compiled the per-pixel loop of this with the index register
   clobbered, so the plane II byte came from the wrong place) */
void plat_text_attr(uint8_t col, uint8_t row, uint8_t n, uint8_t attr)
{
    mz_recolour((uint8_t *)(0x8000u + (uint16_t)row * 320 + col), n, pen_of[attr & 7], pen_of[(attr >> 3) & 7]);
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
