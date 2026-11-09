/* The tool icons, 16x16 pictures of four cells: the Amstrad CPC game's own (assets/cpc_icons.bin, tools/extract_cpc_icons.py) in
   black, red, cyan (the face, which each icon has in its own colour) and white: a cell is 8 rows of the pixels with blue and green, and of
   those with red. */
#include <stdint.h>
#include "platform.h"

#ifdef ICONS_FETCH
/* A platform that keeps the icons where the Z80 cannot read them directly says ICONS_FETCH and has mp_icon_fetch(): the 16 bytes of cell n */
extern void mp_icon_fetch(uint8_t *dest, uint8_t n);
#else
extern const uint8_t mp_icons[];
#endif

/* a cell from 24 bytes: a plane (blue, red, green) of eight rows after another */
extern void mp_planar(uint8_t col, uint8_t row, const uint8_t *planes, uint8_t inverse);

#define NUM_ICONS 14

#ifdef HAVE_ICON_CACHE
/* A platform whose cells are slow to work out (the FP-1100's) says HAVE_ICON_CACHE and has plat_icon_same(): it remembers how each icon was last drawn (selected or not, affordable or not) and
   says 1 if this is the same and the icon is still on the screen. */
extern uint8_t plat_icon_same(uint8_t icon, uint8_t selected, uint8_t affordable);
#endif

/* the colour of each icon's face (bit 0 blue, 1 red, 2 green): green for the residential zone, cyan for the commercial (blue is
   too dark under the black), yellow for the industrial, magenta for the police and the fire station, cyan for the networks */
#ifndef HAVE_ICONS_STORED
static const uint8_t face_colour[NUM_ICONS] = { 6, 5, 5, 5, 4, 4, 5, 6, 3, 3, 6, 6, 5, 5 };
#endif

/* the tools there is the money for, bit i for tool i (plat_afford): the icons of the others are thinned to a checkerboard (each byte
   of the picture AND %01010101 on the even rows, %10101010 on the odd ones) */
static uint16_t afford = 0xFFFF;

void plat_afford(uint16_t mask)
{
    afford = mask;
}

#ifdef HAVE_ICONS_STORED
/* A platform that keeps the icons' cells (both the normal and the dimmed) as pictures of its own says HAVE_ICONS_STORED and draws an icon itself. */
extern void plat_icon_stored(uint8_t icon, uint8_t selected, uint8_t affordable);

void plat_icons(uint8_t selected)
{
    uint8_t i;

    for (i = 0; i < NUM_ICONS; ++i) {
#ifdef HAVE_ICON_CACHE
        if (plat_icon_same(i, i == selected, (uint8_t)((afford >> i) & 1)))
            continue;
#endif
        plat_icon_stored(i, i == selected, (uint8_t)((afford >> i) & 1));
    }
}
#else
void plat_icons(uint8_t selected)
{
    uint8_t i, r, c, y, bg, red, face, white, m, fb, fr, fg;
    const uint8_t *src;
    uint8_t planes[24];
#ifdef ICONS_FETCH
    uint8_t cell[16];
#endif

    for (i = 0; i < NUM_ICONS; ++i) {
#ifdef HAVE_ICON_CACHE
        if (plat_icon_same(i, i == selected, (uint8_t)((afford >> i) & 1)))
            continue;
#endif
        fb = (face_colour[i] & 1) ? 0xFF : 0;               /* the face's planes */
        fr = (face_colour[i] & 2) ? 0xFF : 0;
        fg = (face_colour[i] & 4) ? 0xFF : 0;
        for (r = 0; r < 2; ++r)
            for (c = 0; c < 2; ++c) {
#ifdef ICONS_FETCH
                mp_icon_fetch(cell, (uint8_t)(i * 4 + r * 2 + c));
                src = cell;
#else
                src = mp_icons + (uint16_t)(i * 4 + r * 2 + c) * 16;
#endif
                for (y = 0; y < 8; ++y) {
                    bg = src[y * 2];
                    red = src[y * 2 + 1];
                    face = bg & (uint8_t)~red;              /* the button's face: cyan in the data, white is both */
                    white = bg & red;
                    m = ((afford >> i) & 1) ? 0xFF : (y & 1) ? 0xAA : 0x55;
                    planes[y] = (white | (face & fb)) & m;              /* blue, red, green */
                    planes[8 + y] = (red | (face & fr)) & m;
                    planes[16 + y] = (white | (face & fg)) & m;
                }
                mp_planar((uint8_t)(i * 2 + c), (uint8_t)(1 + r), planes, i == selected);
            }
    }
}
#endif
