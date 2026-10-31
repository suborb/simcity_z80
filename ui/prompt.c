#include <stdint.h>
#include <string.h>
#include "engine.h"
#include "platform.h"
#include "prompt.h"
#include "textfmt.h"
#include "menu.h"
#if defined(HAVE_FILES) || defined(HAVE_APPNAME)

char city_name[CITY_NAME_LEN + 1] = "HERESVILLE";

#ifdef HAVE_POPUP_MENU
#ifdef HAVE_TEXT_LAYER
#define plat_puts plat_text_puts            /* a dialogue is on the text layer too */
#endif
/* The dialogues are boxes over the map, like the menus: a title, a label, the line being typed and the keys to press; or a
   message and "ANY KEY". */
static void line(uint8_t n, const char *s)
{
    plat_puts((uint8_t)(menu_col + 2), (uint8_t)(menu_row + n), s);
}

void prompt_say(const char *s)
{
    uint8_t k;

    menu_box(5);
    line(1, s);
    line(3, "ANY KEY");
    do {
        k = plat_key();
        if (!k)
            plat_idle();
    } while (!k);
}

void prompt_status(const char *status)
{
    line(5, "                          ");        /* blank the whole keys line first */
    line(5, status);
}

uint8_t prompt_ask(const char *t, const char *l, char *name, uint8_t max, uint8_t spaces)
{
    menu_box(7);
    line(1, t);
    line(2, l);
    line(5, "ENTER OK  ESC CANCEL");
    return plat_text_input((uint8_t)(menu_col + 2), (uint8_t)(menu_row + 3), name, max, spaces);
}

#ifdef HAVE_FILE_LIST
uint8_t prompt_pick(const char *t, uint8_t add, char *name)
{
    char names[FILE_LIST_MAX * FILE_LIST_ENTRY];
    struct menu_item items[FILE_LIST_MAX + 1];
    uint8_t n = plat_file_list(names), i, k = 0;

    if (n == FILE_LIST_NONE)
        return 3;                                   /* it cannot list: the name is typed */
    if (add) {
        items[0].text = "<NEW FILE>";
        items[0].value = 1;
        k = 1;
    }
    for (i = 0; i < n; ++i, ++k) {
        items[k].text = names + i * FILE_LIST_ENTRY;
        items[k].value = (uint8_t)(i + 2);
    }
    if (!k) {
        prompt_say("NO SAVED CITIES");
        return 0;
    }
    i = menu_choose(t, items, k);
    if (i > FILE_LIST_MAX + 1)
        return 2;                                   /* CMD_QUIT */
    if (i < 2)
        return i ? 3 : 0;                           /* the new file entry, or ESC */
    strcpy(name, names + (i - 2) * FILE_LIST_ENTRY);
    return 1;
}
#endif
#else
/* The screen: a title, a label and the text typed so far (and a cursor), a message and what to press. */
static const char *title, *label, *shown, *message, *help;
#ifdef HAVE_TEXT_BANNER
#define PR(n) ((n) > 6 ? 6 : (n))       /* seven rows */
#else
#define PR(n) (n)
#endif
static const struct field screen[] = {
    { 0,  0, F_STR,  0, &title },
    { 2,  0, F_STR,  0, &label },
    { 2, 11, F_STR,  0, &shown },
    { 4,  0, F_STR,  0, &message },
    { PR(7),  0, F_STR,  0, &help },
};

static void show(void)
{
    plat_text_clear();
    fmt_fields(screen, sizeof(screen) / sizeof(struct field));
    plat_flush();
}

void prompt_say(const char *s)
{
    uint8_t k;

    message = s;
    help = "ANY KEY";
    show();
    do {
        k = plat_key();
        if (!k)
            plat_idle();
    } while (!k);
}

uint8_t prompt_ask(const char *t, const char *l, char *name, uint8_t max, uint8_t spaces)
{
    title = t;
    label = l;
    shown = "";
    message = "";
    help = "ENTER OK  ESC CANCEL";
    show();
    return plat_text_input(11, 2, name, max, spaces);          /* the platform's own line editor */
}
#endif

void city_name_from(const uint8_t *padded)
{
    uint8_t n = CITY_NAME_LEN, i;

    while (n && padded[n - 1] == ' ')
        --n;
    for (i = 0; i < n; ++i)
        city_name[i] = (char)padded[i];
    city_name[n] = 0;
}

void city_name_to(uint8_t *padded)
{
    uint8_t i, end = 0;                             /* the name, then spaces */
    for (i = 0; i < CITY_NAME_LEN; ++i) {
        if (!city_name[i])
            end = 1;
        padded[i] = end ? ' ' : (uint8_t)city_name[i];
    }
}

#endif
