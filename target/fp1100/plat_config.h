/* Casio FP-1100 (CP/M 2.2) capabilities for the shared game UI: a 320x200 screen of three planes (8 colours) used as 40x25 cells of 8x8, with
   the planes in the sub-CPU's video RAM, which the Z80 reaches through a small program running there (target/fp1100/sub.s.in, fp_sub.asm).  Like
   the Sharp X1's (target/x1) but smaller: the program has to fit CP/M's 52 KB, and the map's pictures are not in it: they are a file on the disk
   (TILES.DAT), read at the start into the sub-CPU's spare video RAM. */
#ifndef PLAT_CONFIG_H
#define PLAT_CONFIG_H

#define HAVE_TILES
#define HAVE_BITMAP
#define HAVE_POPUP_MENU
/* the box's frame in line pieces: 1 and 2 the top corners, 3 and 4 the bottom ones, 5 across, 6 down */
#define BOX_TOP    "\1\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\2"
#define BOX_BOTTOM "\3\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\4"
#define BOX_SIDE   "\6                            \6"
#define HAVE_FILES                      /* a city is saved in one of 8 slots on the boot disc (plat_fp1100_files.asm, asm_fp1100_disk_rw) */
#define HAVE_FILE_LIST                  /* the slots are listed (plat_file_list), so the player picks one */
#define NO_QUIT                         /* the game is left by resetting */
#define HAVE_BUDGET
#define HAVE_EVALUATION
#define MODAL_ROWS 24
#define HAVE_SPRITES
#define HAVE_SPRITE_OVERLAY             /* the train, plane and tornado over the picture (plat_put_overlay) */
#define HAVE_ICONS                      /* the tools as 16x16 pictures */
#define HAVE_TEXT_COLOUR                /* the budget and evaluation screens coloured, with bars (plat_text_attr, plat_bar) */
#define MODAL_NARROW                    /* ... in their 32 column arrangement, */
#define MODAL_X 4                       /* ... centred in the 40 columns */
#define HAVE_DEMAND_BARS                /* the R, C and I demand as coloured bar charts (plat_demand) */
#define HAVE_ICONS_STORED               /* ... from pictures in the sub program's store (plat_icon_stored) */
#define HAVE_ICON_CACHE                 /* plat_icons draws only the icons that changed (plat_icon_same, plat_fp1100.c) */
#define HAVE_ICONS_AFFORD               /* the icons of what there is no money for are dimmed (plat_afford) */
#define HAVE_POWER_ASK                  /* a power station asks coal or nuclear when there is the money for both */
#define HAVE_MINIMAP
#define HAVE_MINIMAP_NATIVE             /* the mini maps a row of tiles at a time, a tile a flat colour (plat_put_minirow) */
#define HAVE_MINIMAP_SQUARE             /* ... every tile row, a tile 2x2 pixels: 192x192 (24 cells) and a sidebar of the other 16 columns */
#define MM_PIC_COL 0
#define MM_SIDE_COL 24
#define HAVE_MINIMAP_FLAT_BASE          /* a density mini map shows the city through where there is none, as a checker (ui/game.c) */
#define HAVE_ICONS_TOP                  /* status panel across the top of the 40-column display */
#define PLAT_FIXED_COLS 40
#define PLAT_FIXED_ROWS 25
#define MAX_VIEW_W 40
#define MAX_VIEW_H 19

#endif
