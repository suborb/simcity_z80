/* Small portable pop-up selector.  Native-menu machines use their own menu system instead. */
#ifndef MENU_H
#define MENU_H

#include <stdint.h>

#ifdef HAVE_POPUP_MENU
struct menu_item {
    const char *text;
    uint8_t value;
};

/* Draw a centred box, wait for a choice, and return the selected item's value.
   Q/A and cursor up/down move the marker; ENTER or SPACE selects; ESC cancels. */
uint8_t menu_choose(const char *title, const struct menu_item *items, uint8_t count);
#endif /* HAVE_POPUP_MENU */

#endif
