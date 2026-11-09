/* Camputers Lynx 128K capabilities for the shared game UI: the 512x252 screen of three one bit planes (8 colours), used as 32 columns of 8x8
   cells with every pixel doubled across and two rows of each picture drawn twice (the hardware pixels are tall: a cell is 16x10 hardware
   pixels, nearly square), 25 rows (target/lynx/plat_lynx.asm).  The planes are written through
   a window with the user RAM's writes off, and cannot be read back. */
#ifndef PLAT_CONFIG_H
#define PLAT_CONFIG_H

#define NO_QUIT                         /* the menu has no QUIT */

#define HAVE_TILES
#define HAVE_BITMAP
#define HAVE_POPUP_MENU     /* shared box + message selector over the bitmap */
#define HAVE_SOUND          /* the Atari ST game's effects, rendered into the DAC (target/lynx/plat_sound.asm) */
/* the box's frame in the placer's line pieces: 1 and 2 the top corners, 3 and 4 the bottom ones, 5 across, 6 down */
#define BOX_TOP    "\1\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\2"
#define BOX_BOTTOM "\3\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\4"
#define BOX_SIDE   "\6                            \6"
#define HAVE_FILES          /* saving and loading a city on the disk (target/lynx/plat_lynx_files.asm, lynx_disk.asm) */
#define HAVE_FILE_LIST      /* the slots on the disk are listed (plat_file_list), so the player picks one */
#define HAVE_BUDGET
#define HAVE_EVALUATION
#define MODAL_COLS 32          /* a 32 column display: the budget and evaluation screens use 32 columns of 24 rows */
#define MODAL_ROWS 24
#define FMT_WIDTH 32            /* a row of a table screen: the display's width (and -Ca-DFMT_WIDTH=32: the Makefile) */
#define HAVE_MINIMAP
#define HAVE_MINIMAP_NATIVE    /* the mini maps a row of tiles at a time, a tile a flat colour (plat_put_minirow) */
#define HAVE_MINIMAP_SQUARE    /* ... every tile row, a tile 4 pixels by 2 lines (which are tall), 384x192: a picture of 24 cells and a sidebar of 8 */
#define MM_PIC_COL 0
#define MM_SIDE_COL 24
#define HAVE_SPRITES
#define HAVE_SPRITE_OVERLAY     /* the sprites go over the baked tiles, which have colours */
#define HAVE_ICONS              /* the tools as 16x16 pictures */
#define ICONS_FETCH             /* ... which are in the alternate green plane (mp_icon_fetch) */
#define HAVE_TEXT_COLOUR        /* the budget and evaluation screens coloured, with bars (plat_text_attr, plat_bar) */
#define NO_BAR_TRACK            /* the bars have no checkerboard track (a grey of sorts): just the fill and the zero mark */
#define HAVE_CHART_CELL         /* the bars' cells are drawn at once (mp_chart_cell): the screen cannot be read to draw their dots over the fill */
#define HAVE_DEMAND_BARS        /* the R, C and I demand as coloured bar charts (plat_demand) */
#define HAVE_ICONS_AFFORD       /* the icons of what there is no money for are dimmed (plat_afford) */
#define HAVE_POWER_ASK          /* a power station asks coal or nuclear when there is the money for both */
#define HAVE_ICONS_TOP          /* status panel across the top of the display */
#define HAVE_ICON_CACHE         /* plat_icons draws only the icons that changed (plat_icon_same) */
#define HAVE_STATUS_SLICE       /* the status panel is drawn a part a pass, so the cursor does not stop while it is (ui/game.c) */
#define PLAT_FIXED_COLS 32
#define PLAT_FIXED_ROWS 25
#define MAX_VIEW_W 32
#define MAX_VIEW_H 19
#define HAVE_MINIMAP_FLAT_BASE  /* a density mini map shows the city through where there is none, as a checker (ui/game.c) */

#endif
