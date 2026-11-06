/* Generic CP/M: a character terminal, no pictures.  The map is drawn with a character a square (glyph() in ui/game.c). */
#ifndef PLAT_CONFIG_H
#define PLAT_CONFIG_H

#define PLAT_FIXED_COLS 80
#define PLAT_FIXED_ROWS 24
#define MAX_VIEW_W 80
#define MAX_VIEW_H 24
#define MODAL_ROWS 24
#define HAVE_POPUP_MENU
#define HAVE_BUDGET
#define HAVE_BUDGET_CAPS                /* the budget screen takes O P Q A in either case */
#define HAVE_EVALUATION
#define HAVE_FILES
#define FILE_NAME_MAX 8
#define FILE_RECORD 128                 /* CP/M keeps a file in whole 128 byte records (see target/common/v9938/plat_v9938.c) */
#define NO_QUIT                         /* the game is left by resetting to the DOS */

#endif
