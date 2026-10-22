/* ZX Spectrum capabilities for the shared game UI. */
#ifndef PLAT_CONFIG_H
#define PLAT_CONFIG_H

#define HAVE_TILES
#define HAVE_BITMAP
#define PLAT_FIXED_COLS 32
#define PLAT_FIXED_ROWS 24
#define MAX_VIEW_W 32
#define MAX_VIEW_H 16

/* What the Spectrum's memory has room for: the budget screen (a 32 column layout, in the whole 24 rows) and the mini
   maps (16 cell rows of the 24, paged, with the cursor).  The sprites are not here yet, and nor is the evaluation
   screen (the mayor's approval, which informs and decides nothing): with it the program is 389 bytes more than the
   41,536 between $5DC0 and the top of memory; without it there are about 1,300 spare. */
#define HAVE_BUDGET
#define MODAL_ROWS 24
#define MODAL_COLS 32
#define FMT_WIDTH 32            /* a row of a table screen: the display's width (and -Ca-DFMT_WIDTH=32: the Makefile) */
#define HAVE_MINIMAP
#define HAVE_MINIMAP_CURSOR
#define MINIMAP_CELLS_H 16
#define MINIMAP_CHUNK_ROWS 4

#endif
