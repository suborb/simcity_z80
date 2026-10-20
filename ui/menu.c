/* A character-cell counterpart to the Spectrum utilities' box + messag pop-ups.
   It deliberately knows only about the common platform console. */
#include <stdint.h>
#include "platform.h"
#include "menu.h"

#ifdef HAVE_POPUP_MENU
#define MENU_WIDTH 26
static const char top[] = "+------------------------+";
static const char side[] = "|                        |";

static void box(uint8_t col, uint8_t row, uint8_t height)
{
    uint8_t y;

    plat_puts(col, row, top);
    for (y = 1; y + 1 < height; ++y)
        plat_puts(col, (uint8_t)(row + y), side);
    plat_puts(col, (uint8_t)(row + height - 1), top);
}

static void item(uint8_t col, uint8_t row, const struct menu_item *entry, uint8_t selected)
{
    plat_put(col, row, selected ? '>' : ' ');
    plat_puts((uint8_t)(col + 1), row, entry->text);
}

uint8_t menu_choose(const char *title, const struct menu_item *items, uint8_t count)
{
    uint8_t col, row, height, i, selected = 0, old, k;

    height = (uint8_t)(count + 4);
    col = (uint8_t)((plat_cols() - MENU_WIDTH) >> 1);
    row = (uint8_t)((plat_rows() - height) >> 1);
    box(col, row, height);
    plat_puts((uint8_t)(col + 2), (uint8_t)(row + 1), title);
    for (i = 0; i < count; ++i)
        item((uint8_t)(col + 2), (uint8_t)(row + i + 2), &items[i], i == selected);

    for (;;) {
        k = plat_key();
        if (!k) {
            plat_idle();
            continue;
        }
        if (k == KEY_ENTER || k == ' ')
            return items[selected].value;
        if (k == 'x'
#ifndef TARGET_AQPLUS
            || k == KEY_ESC
#endif
           )
            return 0;
#ifndef TARGET_AQPLUS
        if (k == CMD_QUIT)
            return k;
#endif
        if (k != KEY_UP && k != KEY_DOWN && k != 'q' && k != 'Q' && k != 'a' && k != 'A')
            continue;
        old = selected;
        if (k == KEY_UP || k == 'q' || k == 'Q')
            selected = selected ? (uint8_t)(selected - 1) : (uint8_t)(count - 1);
        else
            selected = selected + 1 < count ? (uint8_t)(selected + 1) : 0;
        /* Only the marker changed; the label is already in the box. */
        plat_put((uint8_t)(col + 2), (uint8_t)(row + old + 2), ' ');
        plat_put((uint8_t)(col + 2), (uint8_t)(row + selected + 2), '>');
    }
}
#endif /* HAVE_POPUP_MENU */
