/* A character-cell counterpart to the Spectrum utilities' box + messag pop-ups.
   It deliberately knows only about the common platform console. */
#include <stdint.h>
#include "platform.h"
#include "menu.h"

#ifdef HAVE_POPUP_MENU
#ifdef HAVE_TEXT_LAYER
#define plat_puts plat_text_puts            /* a popup is on the text layer */
#define plat_put plat_text_put
#endif
#define MENU_WIDTH 30                   /* wide enough for a file name's 24 characters (ui/prompt.c) */
#ifdef BOX_TOP                          /* a platform with line drawing characters says what the frame is made of (plat_config.h) */
static const char top[] = BOX_TOP;
static const char bottom[] = BOX_BOTTOM;
static const char side[] = BOX_SIDE;
#else
static const char top[] = "+----------------------------+";
static const char side[] = "|                            |";
#define bottom top
#endif

/* The rows the boxes are centred in: the map, which the game says (menu_area); else the whole screen. */
static uint8_t area_row, area_rows;

void menu_area(uint8_t row, uint8_t rows)
{
    area_row = row;
    area_rows = rows;
}

uint8_t menu_col, menu_row;

void menu_box(uint8_t height)
{
    uint8_t y, r = area_rows ? area_rows : plat_rows();

#ifdef HAVE_TEXT_LAYER
    plat_text_screen(1);
#endif
    menu_col = (uint8_t)((plat_cols() - MENU_WIDTH) >> 1);
    menu_row = (uint8_t)(area_row + ((r - height) >> 1));
    plat_puts(menu_col, menu_row, top);
    for (y = 1; y + 1 < height; ++y)
        plat_puts(menu_col, (uint8_t)(menu_row + y), side);
    plat_puts(menu_col, (uint8_t)(menu_row + height - 1), bottom);
}

static void item(uint8_t col, uint8_t row, const struct menu_item *entry, uint8_t selected)
{
    plat_put(col, row, selected ? '>' : ' ');
    plat_puts((uint8_t)(col + 1), row, entry->text);
}

uint8_t menu_choose(const char *title, const struct menu_item *items, uint8_t count)
{
    uint8_t col, row, i, selected = 0, old, k;

    menu_box((uint8_t)(count + 4));
    col = menu_col;
    row = menu_row;
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
