/* Aquarius+ capabilities for the shared game UI. */
#ifndef PLAT_CONFIG_H
#define PLAT_CONFIG_H

#define HAVE_TILES
#define HAVE_BITMAP
#define HAVE_POPUP_MENU     /* shared box + message selector over the bitmap console */
#define HAVE_FILES          /* Aquarius+ ESP filesystem */
#define HAVE_BUDGET
#define HAVE_EVALUATION
#define MODAL_ROWS 24          /* budget and evaluation use the full 40x24 text area */
#define HAVE_MINIMAP
#define HAVE_MINIMAP_COLOUR
#define MINIMAP_CELLS_H 19     /* use all 19 bitmap rows beneath the six-row status panel */
#define MINIMAP_CHUNK_ROWS 4
#define HAVE_SPRITES
#define HAVE_ICONS              /* the tools as 16x16 pictures */
#define HAVE_ICONS_TOP          /* status panel across the top of the 40-column display */
#define PLAT_FIXED_COLS 40
#define PLAT_FIXED_ROWS 25
#define MAX_VIEW_W 40
#define MAX_VIEW_H 19

#endif
