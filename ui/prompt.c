#include <stdint.h>
#include "engine.h"
#include "platform.h"
#include "prompt.h"
#include "textfmt.h"
#if defined(HAVE_FILES) || defined(HAVE_APPNAME)

char city_name[CITY_NAME_LEN + 1] = "HERESVILLE";

/* The screen: a title, a label and the text typed so far (and a cursor), a message and what to press. */
static const char *title, *label, *shown, *message, *help;
static const struct field screen[] = {
    { 0,  0, F_STR,  0, &title },
    { 2,  0, F_STR,  0, &label },
    { 2, 11, F_STR,  0, &shown },
    { 4,  0, F_STR,  0, &message },
    { 7,  0, F_STR,  0, &help },
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
    uint8_t n = 0, k;

    title = t;
    label = l;
    shown = name;
    message = "";
    help = "ENTER OK  ESC CANCEL";
    name[0] = '_';
    name[1] = 0;
    for (;;) {
        show();
        do {
            k = plat_key();
            if (!k)
                plat_idle();
        } while (!k);
        if (k == KEY_ENTER || k == KEY_ESC || k == CMD_QUIT) {
            name[n] = 0;
            return k == KEY_ENTER ? n != 0 : k == KEY_ESC ? 0 : 2;
        }
        if ((k == KEY_LEFT || k == 127) && n)
            --n;
        else if (k >= (spaces ? ' ' : '!') && k < 127 && n < max)
            name[n++] = (char)k;
        name[n] = '_';
        name[n + 1] = 0;
    }
}

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
