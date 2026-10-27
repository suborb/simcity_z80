/* MGT SAM Coupe capabilities for the shared game UI: screen mode 4, 256x192 pixels of 16 colours, used as 32 columns of 8x8
   cells (target/sam/plat_sam.asm). */
#ifndef PLAT_CONFIG_H
#define PLAT_CONFIG_H

#define HAVE_TILES
#define HAVE_BITMAP
#define HAVE_POPUP_MENU     /* shared box + message selector over the bitmap */
/* the box's frame in the placer's line pieces (plat_sam.asm): 1 and 2 the top corners, 3 and 4 the bottom ones, 5 across, 6 down */
#define BOX_TOP    "\1\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\2"
#define BOX_BOTTOM "\3\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\4"
#define BOX_SIDE   "\6                            \6"
#define HAVE_SOUND              /* the Atari ST game's effects on the SAA 1099 (target/common/ay_sfx.asm, target/sam/plat_sound.asm) */
#define HAVE_FILES          /* saving and loading a city as a SAMDOS file */
#define FILE_NAME_MAX 10    /* SAMDOS names are 10 characters */
#define HAVE_BUDGET
#define HAVE_EVALUATION
#define MODAL_COLS 32          /* a 32 column display: the budget and evaluation screens use 32 columns of the 24 rows */
#define MODAL_ROWS 24
#define HAVE_DATA_PAGING       /* the data is in a bank that the display code pages out: the UI calls plat_page_data() (ui/platform.h) */
#define FMT_WIDTH 32            /* a row of a table screen: the display's width (and -Ca-DFMT_WIDTH=32: the Makefile) */
#define HAVE_MINIMAP
#define HAVE_MINIMAP_NATIVE    /* the whole city in colour (plat_put_minirow) */
#define HAVE_MINIMAP_SQUARE    /* ... every tile row, 2x2 pixels a tile, 192x192 with a sidebar (the Makefile defines it for the assembler too) */
#define HAVE_CLEAR_MAP          /* a mini map clears the screen below the panel only (plat_clear_map) */
#define HAVE_DEMAND_BARS        /* the R, C and I demand as coloured bar charts (plat_demand) */
#define HAVE_TEXT_COLOUR        /* the budget and evaluation screens coloured, with bars (plat_text_attr, plat_bar) */
#define HAVE_SPRITES
#define HAVE_SPRITE_OVERLAY     /* the sprites go over the baked tiles, which have colours */
#define HAVE_ICONS              /* the tools as 16x16 pictures */
#define HAVE_ICONS_TOP          /* status panel across the top of the display */
#define HAVE_ICONS_AFFORD       /* the icons of what there is no money for are greyed out (plat_afford) */
#define HAVE_POWER_ASK          /* a power station asks coal or nuclear when there is the money for both */
#define HAVE_ICONS_2X7          /* ... with the icons in two rows of seven, 24x14 pixels each (ui/game.c) */
#define PLAT_FIXED_COLS 32
#define PLAT_FIXED_ROWS 24
#define MAX_VIEW_W 32
#define MAX_VIEW_H 17

#endif
