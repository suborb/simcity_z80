/* Amstrad PCW (CP/M Plus): the 720x256 monochrome bitmap as a 40x32 grid of 16x8 pixel cells, centred in the 720 pixels (a margin of 40 each side).  The PCW's pixels are about twice as tall as they are wide, so a
   tile's 8x8 pixels are drawn twice across and the cell comes out square.  See target/pcw/plat_pcw.asm. */
#ifndef PLAT_CONFIG_H
#define PLAT_CONFIG_H

#define PLAT_FIXED_COLS 40
#define PLAT_FIXED_ROWS 32
#define MAX_VIEW_W 40
#define MAX_VIEW_H 32
#define MODAL_COLS 40
#define MODAL_ROWS 24
#define FMT_WIDTH 40                    /* (and -Ca-DFMT_WIDTH=40 for the assembler: the Makefile) */
#define HAVE_TILES
#define HAVE_BITMAP
#define HAVE_POPUP_MENU
/* the box's frame in line pieces that plat_put() draws (codes 1 to 6): 1 and 2 the top corners, 3 and 4 the bottom ones, 5 across, 6 down */
#define BOX_TOP    "\1\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\2"
#define BOX_BOTTOM "\3\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\4"
#define BOX_SIDE   "\6                            \6"
#define HAVE_BUDGET
#define HAVE_EVALUATION
#define HAVE_TEXT_COLOUR                /* shades: plat_text_attr() inverts the selection, plat_bar() fills with a dither (the colour chooses it) */
#define HAVE_DEMAND_BARS
#define HAVE_ICONS                      /* the tools as the Spectrum's 16x16 pictures (assets/udgs.bin), drawn twice across */
#define HAVE_ICONS_TOP                  /* the status panel across the top, as the Spectrum's */
#define HAVE_ICONS_AFFORD               /* the icons of what there is no money for are thinned to a checkerboard */
#define HAVE_POWER_ASK                  /* a power station asks coal or nuclear when there is the money for both */
#define HAVE_SPRITES                    /* the train, plane and tornado: tile and sprite ORed, by plat_put_bitmap() */
#define HAVE_MINIMAP
#define HAVE_MINIMAP_NATIVE             /* the mini maps a row of tiles at a time (plat_put_minirow) ... */
#define HAVE_MINIMAP_SQUARE             /* ... a tile 4x2 pixels, 96x96 tiles: 24 cells by 24 rows, and a sidebar of the other 16 columns */
#define HAVE_MINIMAP_FLAT_BASE          /* a density mini map shows the city dimly where there is none (ui/game.c) */
#define MM_PIC_COL 0
#define MM_SIDE_COL 24
#define HAVE_SCROLL                     /* the map's bytes moved on the screen (plat_scroll), only the cells that come into view drawn */
#define HAVE_FILES
#define FILE_NAME_MAX 8
#define FILE_RECORD 128                 /* CP/M keeps a file in whole 128 byte records (see target/common/v9938/plat_v9938.c) */
#define NO_QUIT                         /* the game is left by resetting to the DOS */

#endif
