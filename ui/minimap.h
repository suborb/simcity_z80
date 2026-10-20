/* The mini maps: the whole city, two pixels a tile each way (192x192), drawn with plat_put_bitmap()
   as 8x8 pictures.  Compact targets show an 8-cell (64-pixel) high window and page it with up and down.
   A larger target can set MINIMAP_CELLS_H to show more, or all 24 cell rows, at once.  A pixel is one bit,
   so what a tile holds is
   shown by dithering: 0 to 4 of its 2x2 pixels lit for the city and power maps, and the density
   maps (pollution, traffic: 48x48; police and fire coverage: 24x24) in finer matrices. */
#ifndef MINIMAP_H
#define MINIMAP_H

#include <stdint.h>

#define MM_CITY      1      /* the land: water, trees, roads and wires, buildings */
#define MM_POLLUTION 2
#define MM_POLICE    3      /* covered by a police station */
#define MM_FIRE      4
#define MM_TRAFFIC   5
#define MM_POWER     6      /* the city, with what has power solid */
#define MM_TRANSPORT 7      /* roads and rails */
#define MM_CRIME     8      /* crime on the built-up tiles: far from the city's centre, less covered by police */
#define MM_VIEWS     8      /* views 1..MM_VIEWS */

#define MM_CELLS_W   24     /* the complete city picture is 24x24 cells: 192x192 pixels */
#ifndef MINIMAP_CELLS_H
#define MINIMAP_CELLS_H 8   /* the Z88-sized default */
#endif
#define MM_CELLS_H   MINIMAP_CELLS_H
#define MM_PIXELS_H  (MM_CELLS_H * 8)
#define MM_PICTURE_H (MM_CELLS_W * 8)

extern const char *const minimap_names[MM_VIEWS + 1];

/* The picture of cell (cx, cy) of view v with pixel row `top` at the top: 8 bytes, a byte a pixel
   row, bit 7 on the left.  The tile at (cur_x, cur_y) is shown as an inverted 2x2 if mark is set (and it is on the page). */
extern void minimap_cell(uint8_t v, uint8_t cx, uint8_t cy, uint8_t top, uint8_t cur_x, uint8_t cur_y,
                         uint8_t mark, uint8_t *art);

#endif
