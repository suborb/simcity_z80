/* Samsung SPC-1000 capabilities for the shared game UI: the MC6847's 256x192 mode (RG6), one bit a pixel, used as 32 columns of 8x8 cells
   (target/spc1000/plat_spc1000.asm).  The video RAM is behind I/O ports, as the X1's. */
#ifndef PLAT_CONFIG_H
#define PLAT_CONFIG_H

#define HAVE_TILES
#define HAVE_BITMAP
#define HAVE_POPUP_MENU     /* shared box + message selector over the bitmap */
/* the box's frame in the placer's line pieces: 1 and 2 the top corners, 3 and 4 the bottom ones, 5 across, 6 down */
#define BOX_TOP    "\1\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\2"
#define BOX_BOTTOM "\3\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\4"
#define BOX_SIDE   "\6                            \6"
#define HAVE_SOUND              /* the Atari ST game's effects on the AY-3-8910 (target/spc1000/plat_sound.asm, target/common/ay_sfx.asm) */
#define HAVE_FILES              /* saving and loading a city on the cassette (target/spc1000/plat_spc1000.c: z88dk's tape_save and tape_load_to) */
#define FILE_NAME_MAX 16        /* the tape's file names */
#define HAVE_BUDGET
#define HAVE_EVALUATION
#define MODAL_COLS 32          /* a 32 column display: the budget and evaluation screens use 32 columns of the 24 rows */
#define MODAL_ROWS 24
#define FMT_WIDTH 32            /* a row of a table screen: the display's width (and -Ca-DFMT_WIDTH=32: the Makefile) */
#define HAVE_DEMAND_BARS        /* the R, C and I demand as bar charts (plat_demand, target/spc1000/plat_spc1000.c) */
#define HAVE_SPRITES
#define HAVE_ICONS              /* the tools as the Spectrum's 16x16 pictures, with no colour (assets/udgs.bin) */
#define HAVE_ICONS_TOP          /* status panel across the top of the display */
#define HAVE_ICONS_AFFORD       /* the icons of what there is no money for are thinned to a checkerboard (plat_afford) */
#define HAVE_POWER_ASK          /* a power station asks coal or nuclear when there is the money for both */
#define HAVE_MINIMAP
#define HAVE_MINIMAP_NATIVE     /* the mini maps a row of tiles at a time (plat_put_minirow) ... */
#define HAVE_MINIMAP_SQUARE     /* ... every tile row, a tile a pixel wide and two lines tall in the CG6 mode: 96x192 pixels, 24 cells, and a sidebar of the other 8 */
#define HAVE_MINIMAP_4BPP       /* ... which is a mode of its own (plat_minimap_mode) */
#define HAVE_MINIMAP_FLAT_BASE  /* a density mini map shows the city through where there is none (ui/game.c) */
#define MM_PIC_COL 0
#define MM_SIDE_COL 24
#define PLAT_FIXED_COLS 32
#define PLAT_FIXED_ROWS 24
#define MAX_VIEW_W 32
#define MAX_VIEW_H 18

#endif
