/* Small portable pop-up selector.  Native-menu machines use their own menu system instead. */
#ifndef MENU_H
#define MENU_H

#include <stdint.h>

#ifdef HAVE_POPUP_MENU
struct menu_item {
    const char *text;
    uint8_t value;
};

/* Boxes (the menus and the dialogues of ui/prompt.c) are centred in `rows` rows starting at `row`: the map, so they never
   cover the status panel.  Without this call they are centred on the whole screen. */
void menu_area(uint8_t row, uint8_t rows);

/* Draw an empty centred box of `height` rows; its top left corner is menu_col, menu_row.  Text goes at column + 2, from
   row + 1. */
extern uint8_t menu_col, menu_row;
void menu_box(uint8_t height);

/* Draw a centred box, wait for a choice, and return the selected item's value.
   Q/A and cursor up/down move the marker; ENTER or SPACE selects; ESC cancels. */
uint8_t menu_choose(const char *title, const struct menu_item *items, uint8_t count);
#endif /* HAVE_POPUP_MENU */

#endif
