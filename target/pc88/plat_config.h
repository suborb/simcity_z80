/* NEC PC-8801 capabilities for the shared game UI: the 640x200 three plane screen, used as 40 columns of 8x8 cells with
   every pixel doubled across (target/pc88/plat_pc88.asm). */
#ifndef PLAT_CONFIG_H
#define PLAT_CONFIG_H

#define HAVE_TILES
#define HAVE_BITMAP
#define HAVE_POPUP_MENU     /* shared box + message selector over the bitmap */
#define HAVE_BUDGET
#define HAVE_EVALUATION
#define MODAL_ROWS 24          /* budget and evaluation use the full 40x24 text area */
#define HAVE_MINIMAP
#define HAVE_MINIMAP_NATIVE    /* mini maps in native pixels: the whole city, every other row (plat_put_minirow) */
#define HAVE_MINIMAP_ART       /* the tiles' own pictures at a quarter of the size (the Makefile defines it for the assembler too) */
#define HAVE_SPRITES
#define HAVE_SPRITE_OVERLAY     /* the sprites go over the baked tiles, which have colours */
#define HAVE_ICONS              /* the tools as 16x16 pictures */
#define HAVE_ICONS_TOP          /* status panel across the top of the 40-column display */
#define PLAT_FIXED_COLS 40
#define PLAT_FIXED_ROWS 25
#define MAX_VIEW_W 40
#define MAX_VIEW_H 19

#endif
