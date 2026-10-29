/* Sharp X1 capabilities for the shared game UI: the 40 column mode's 320x200 screen of three planes (8 colours), used as 40 columns of 8x8
   cells, a cell a byte wide (target/x1/plat_x1.asm).  The screen is reached through I/O ports, not memory. */
#ifndef PLAT_CONFIG_H
#define PLAT_CONFIG_H

#define HAVE_TILES
#define HAVE_BITMAP
#define HAVE_POPUP_MENU     /* shared box + message selector over the bitmap */
/* the box's frame in the placer's line pieces: 1 and 2 the top corners, 3 and 4 the bottom ones, 5 across, 6 down */
#define BOX_TOP    "\1\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\2"
#define BOX_BOTTOM "\3\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\4"
#define BOX_SIDE   "\6                            \6"
#define HAVE_BUDGET
#define HAVE_EVALUATION
#define MODAL_ROWS 24          /* budget and evaluation use the full 40x24 text area */
#define HAVE_MINIMAP
#define HAVE_MINIMAP_NATIVE    /* the mini maps a row of tiles at a time, a tile a flat colour (plat_put_minirow) */
#define HAVE_MINIMAP_SQUARE    /* ... every tile row, a tile 2x2 pixels: 192x192 (24 cells) and a sidebar of the other 16 columns */
#define MM_PIC_COL 0            /* the picture's 24 cells, then the sidebar's 16 */
#define MM_SIDE_COL 24
#define HAVE_SOUND              /* the Atari ST game's effects on the PSG (target/x1/plat_sound.asm, target/common/ay_sfx.asm) */
#define HAVE_SPRITES
#define HAVE_SPRITE_OVERLAY     /* the sprites go over the baked tiles, which have colours */
#define HAVE_ICONS              /* the tools as 16x16 pictures */
#define HAVE_TEXT_COLOUR        /* the budget and evaluation screens coloured, with bars (plat_text_attr, plat_bar) */
#define MODAL_NARROW            /* ... in their 32 column arrangement, */
#define MODAL_X 4               /* ... centred in the 40 columns */
#define HAVE_DEMAND_BARS        /* the R, C and I demand as coloured bar charts (plat_demand) */
#define HAVE_ICONS_AFFORD       /* the icons of what there is no money for are dimmed (plat_afford) */
#define HAVE_POWER_ASK          /* a power station asks coal or nuclear when there is the money for both */
#define HAVE_ICONS_TOP          /* status panel across the top of the 40-column display */
#define PLAT_FIXED_COLS 40
#define PLAT_FIXED_ROWS 25
#define MAX_VIEW_W 40
#define MAX_VIEW_H 19
#define HAVE_MINIMAP_FLAT_BASE  /* a density mini map shows the city through where there is none, as a checker (ui/game.c) */

#endif
