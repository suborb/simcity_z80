/* The mini maps: the whole city, two pixels a tile each way (192x192), drawn with plat_put_bitmap()
   as 8x8 pictures.  The window is 64 pixels high, so 192x64 is shown: a third of the city, 32 tile
   rows, the one the cursor is in (see minimap_top()).  A pixel is one bit, so what a tile holds is
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
#define MM_VIEWS     6      /* views 1..MM_VIEWS */

#define MM_CELLS_W   24     /* the picture is 24x8 cells: 192x64 pixels */
#define MM_CELLS_H   8

extern const char *const minimap_names[MM_VIEWS + 1];

/* The first pixel row shown (0, 64 or 128) when the cursor is at map row cur_y. */
extern uint8_t minimap_top(uint8_t cur_y);

/* The picture of cell (cx, cy) of view v with pixel row `top` at the top: 8 bytes, a byte a pixel
   row, bit 7 on the left.  The tile at (cur_x, cur_y) is shown as an inverted 2x2 if mark is set. */
extern void minimap_cell(uint8_t v, uint8_t cx, uint8_t cy, uint8_t top, uint8_t cur_x, uint8_t cur_y,
                         uint8_t mark, uint8_t *art);

#endif
