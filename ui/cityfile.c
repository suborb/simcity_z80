#include <stdint.h>
#include <string.h>
#include "engine.h"
#include "platform.h"
#include "cityfile.h"
#include "textfmt.h"

#define NAME_MAX 24

static uint8_t header[CITY_HEADER];

/* The screen: a title, the name typed so far (and a cursor), a message and what to press. */
static const char *title, *shown, *message, *help;
static const struct field screen[] = {
    { 0,  0, F_STR,  0, &title },
    { 2,  0, F_TEXT, 0, "FILE NAME:" },
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

static void say(const char *s)
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

/* The name of the file, typed in the text area.  Returns 1 for a name, 0 if cancelled, 2 to quit. */
static uint8_t ask(const char *t, char *name)
{
    uint8_t n = 0, k;

    title = t;
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
        else if (k > ' ' && k < 127 && n < NAME_MAX)
            name[n++] = (char)k;
        name[n] = '_';
        name[n + 1] = 0;
    }
}

uint8_t city_save(void)
{
    char name[NAME_MAX + 2];
    uint8_t r = ask("SAVE THIS CITY", name);

    if (r == 2)
        return CITY_QUIT;
    if (r != 1)
        return CITY_SAVED;
    for (r = 0; r < 12; ++r)                        /* the file name, padded with spaces as the Spectrum keeps it */
        header[r] = name[r] && (r == 0 || header[r - 1] != ' ') ? name[r] : ' ';
    memcpy(header + 12, V_money, 7);               /* money, the month and the year follow each other */
    memcpy(header + 19, "HERESVILLE  ", 12);        /* the city name */
    if (plat_file_save(name, header, CITY_HEADER, levelmap, MAP_W * MAP_H))
        say("COULD NOT SAVE THE CITY");
    else
        say("SAVED");
    return CITY_SAVED;
}

uint8_t city_load(void)
{
    char name[NAME_MAX + 2];
    uint8_t r = ask("LOAD A CITY", name);

    if (r == 2)
        return CITY_QUIT;
    if (r != 1)
        return CITY_SAVED;
    r = plat_file_load(name, header, CITY_HEADER, levelmap, MAP_W * MAP_H);
    if (r) {                                        /* 1: nothing read; 2: the map is half read */
        say("COULD NOT LOAD THE CITY");
        return r == 1 ? CITY_SAVED : CITY_BROKEN;
    }
    sim_loaded();                                   /* a clean simulation, then what the file holds */
    memcpy(V_money, header + 12, 7);
    return CITY_LOADED;
}
