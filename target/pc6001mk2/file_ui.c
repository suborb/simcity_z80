/* The file dialogues (ui/prompt.c, ui/cityfile.c) in the FILE overlay, with the disc code (plat_files.c), so that the game overlay does not have to hold them: one translation unit, the
   shared files included here (the Makefile leaves them out of the list).  They draw with menu_box, which is in the game overlay, so the overlay has a box routine of its own below (the same
   as ui/menu.c's, which says where the boxes go in area_row and area_rows). */
#define MK2_FILE_UNIT
#include <stdint.h>
#include "platform.h"
#define menu_box fmenu_box
#define menu_col fmenu_col
#define menu_row fmenu_row
#define menu_choose fmenu_choose
#include "menu.h"
PLAT_CODE_GAME_OVERLAY
PLAT_CONST_GAME_OVERLAY

extern uint8_t area_row, area_rows;
uint8_t menu_col, menu_row;

void menu_box(uint8_t height) __z88dk_fastcall
{
    uint8_t y, r = area_rows ? area_rows : plat_rows();

    menu_col = (uint8_t)((plat_cols() - 30) >> 1);
    menu_row = (uint8_t)(area_row + ((r - height) >> 1));
    plat_puts(menu_col, menu_row, BOX_TOP);
    for (y = 1; y + 1 < height; ++y)
        plat_puts(menu_col, (uint8_t)(menu_row + y), BOX_SIDE);
    plat_puts(menu_col, (uint8_t)(menu_row + height - 1), BOX_BOTTOM);
}

/* the list of saved cities (prompt_pick): a short chooser of its own, as menu_choose is in the game overlay */
uint8_t menu_choose(const char *title, const struct menu_item *items, uint8_t count)
{
    uint8_t i, s = 0, old, k;

    menu_box((uint8_t)(count + 4));
    plat_puts((uint8_t)(menu_col + 2), (uint8_t)(menu_row + 1), title);
    for (i = 0; i < count; ++i)
        plat_puts((uint8_t)(menu_col + 3), (uint8_t)(menu_row + 2 + i), items[i].text);
    plat_put((uint8_t)(menu_col + 2), (uint8_t)(menu_row + 2), '>');
    for (;;) {
        k = plat_key();
        if (!k) {
            plat_idle();
            continue;
        }
        if (k == KEY_ENTER || k == ' ')
            return items[s].value;
        if (k == 'x' || k == KEY_ESC)
            return 0;
        old = s;
        if (k == KEY_UP || k == 'q')
            s = s ? (uint8_t)(s - 1) : (uint8_t)(count - 1);
        else if (k == KEY_DOWN || k == 'a')
            s = s + 1 < count ? (uint8_t)(s + 1) : 0;
        else
            continue;
        plat_put((uint8_t)(menu_col + 2), (uint8_t)(menu_row + 2 + old), ' ');
        plat_put((uint8_t)(menu_col + 2), (uint8_t)(menu_row + 2 + s), '>');
    }
}

#include "prompt.c"
#include "cityfile.c"
