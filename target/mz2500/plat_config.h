/* Sharp MZ-2500 capabilities for the shared game UI: 320x200 in 16 colours (planar video RAM: four planes of 8 pixels a byte), used as 32 columns of 8x8 cells (the
   map and the status panel as the MSX2's), the Atari ST's art and 16 colours as the SAM Coupe's.  The pictures are a planar atlas in RAM pages 22-24 (tools/st_tiles_3bpp.py
   --mz2500) that the blit maps into window 2 a tile at a time (target/mz2500/plat_mz2500.asm).   */
#ifndef PLAT_CONFIG_H
#define PLAT_CONFIG_H

#define HAVE_TILES
#define HAVE_BITMAP
#define HAVE_POPUP_MENU     /* shared box + message selector over the bitmap */
/* the box's frame in the placer's line pieces (plat_mz2500.c): 1 and 2 the top corners, 3 and 4 the bottom ones, 5 across, 6 down */
#define BOX_TOP    "\1\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\2"
#define BOX_BOTTOM "\3\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\4"
#define BOX_SIDE   "\6                            \6"
#define HAVE_SOUND              /* the Atari ST game's effects on the YM2203's SSG (target/common/ay_sfx.asm, ay_hooks.asm, target/mz2500/plat_sound.asm) */
#define HAVE_FILES              /* save and load: raw slots on the boot disk (target/mz2500/mz_files.c) */
#define FILE_NAME_MAX 12
#define NO_QUIT                 /* the menu has no QUIT: there is nothing to quit to */
#define HAVE_BUDGET
#define HAVE_EVALUATION
#define MODAL_COLS 32          /* a 32 column display: the budget and evaluation screens use 32 columns of the 24 rows */
#define MODAL_ROWS 24
#define FMT_WIDTH 32            /* a row of a table screen: the display's width (and -Ca-DFMT_WIDTH=32: the Makefile) */
#define HAVE_MINIMAP
#define HAVE_MINIMAP_NATIVE    /* the whole city in colour (plat_put_minirow) */
#define HAVE_MINIMAP_SQUARE    /* ... every tile row, 2x2 pixels a tile, 192x192 with a sidebar */
#define HAVE_CLEAR_MAP          /* a mini map clears the screen below the panel only (plat_clear_map) */
#define HAVE_DEMAND_BARS        /* the R, C and I demand as coloured bar charts (plat_demand) */
#define HAVE_TEXT_COLOUR        /* the budget and evaluation screens coloured, with bars (plat_text_attr, plat_bar) */
#define HAVE_SCROLL             /* a scroll moves the map's pixels (plat_scroll) and the game draws only the cells that come into view */
#define HAVE_MOUSE              /* the mouse on the SIO (target/mz2500/mz_pointer.c): its position is read each pass ... */
#define HAVE_POINTER            /* ... and the pointer is always there: the keys move it too (QAOP, the cursor keys, Space or Enter its button) */
#define HAVE_MOUSE_SPRITE       /* the pointer is drawn in its own graphics screen: nothing to draw under it or to put back */
#define HAVE_SPRITES
#define HAVE_SPRITE_OVERLAY     /* the train, plane and tornado are drawn over the baked tiles (plat_put_overlay) */
#define HAVE_ICONS              /* the tools as 24x14 pictures */
#define HAVE_ICONS_TOP          /* status panel across the top of the display */
#define HAVE_ICONS_AFFORD       /* the icons of what there is no money for are greyed out (plat_afford) */
#define HAVE_POWER_ASK          /* a power station asks coal or nuclear when there is the money for both */
#define HAVE_ICONS_2X7          /* ... with the icons in two rows of seven (ui/game.c) */
#define PLAT_FIXED_COLS 32
#define PLAT_FIXED_ROWS 24
#define MAX_VIEW_W 32
#define MAX_VIEW_H 17

#endif
