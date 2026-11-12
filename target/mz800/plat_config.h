/* Sharp MZ-800 on a boot disc: the 320x200 mode of two bit planes (4 colours out of 16, programmable) as 40 x 25 cells of 8x8 pixels (target/mz800/plat_mz800.asm).
   The art is the PC-6001mkII's (four pens, a cell has an ink pen and a paper pen). */
#ifndef PLAT_CONFIG_H
#define PLAT_CONFIG_H

#define PLAT_FIXED_COLS 40
#define PLAT_FIXED_ROWS 25
#define MAX_VIEW_W 40
#define MAX_VIEW_H 25
#define MODAL_ROWS 24
#define HAVE_TILES
#define HAVE_POPUP_MENU
#define HAVE_BUDGET
#define HAVE_BUDGET_CAPS                /* the budget screen takes O P Q A in either case */
#define HAVE_EVALUATION
#define MODAL_NARROW                    /* the budget and evaluation screens in their 32 column arrangement, */
#define MODAL_X 4                       /* ... centred in the 40 columns */
#define NO_QUIT

#define HAVE_MINIMAP
#define HAVE_MINIMAP_NATIVE     /* the mini maps a row of tiles at a time (plat_put_minirow) ... */
#define HAVE_MINIMAP_SQUARE     /* ... every tile row, a tile 2x2 pixels: 192x192 (24 cells) and a sidebar of the other 16 columns */
#define MM_PIC_COL 0
#define MM_SIDE_COL 24
#define HAVE_TEXT_COLOUR        /* the budget and evaluation screens coloured, with bars (plat_text_attr, plat_bar: plat_text.c) */
#define HAVE_DEMAND_BARS        /* the R, C and I demand as bar charts (plat_demand) */
#define HAVE_SPRITES
#define HAVE_SPRITE_OVERLAY     /* the train, plane and tornado are drawn over the cell's tile, in red (plat_put_overlay) */
#define HAVE_FILES              /* city files on the disc (target/mz800/plat_files.c) */
#define HAVE_FILE_LIST          /* ... six slots to choose from */
#define FILE_NAME_MAX 12
#define BOX_TOP    "\1\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\2"
#define BOX_BOTTOM "\3\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\4"
#define BOX_SIDE   "\6                            \6"
#define HAVE_SOUND              /* the SN76489: the Atari ST's effects (target/mz800/plat_sound.asm) */
#define HAVE_ICONS              /* the tools as 16x16 pictures */
#define HAVE_ICONS_AFFORD       /* the icons of what there is no money for are dimmed (plat_afford) */
#define HAVE_POWER_ASK          /* a power station asks coal or nuclear when there is the money for both */
#define HAVE_ICONS_TOP          /* status panel across the top of the 40-column display */

#endif
