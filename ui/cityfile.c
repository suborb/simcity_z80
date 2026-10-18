#include <stdint.h>
#include <string.h>
#include "engine.h"
#include "platform.h"
#include "cityfile.h"

#define NAME_MAX 24

static uint8_t header[CITY_HEADER];

/* Show a line of the screen: the title, the name typed so far and what to press. */
static void show(const char *title, const char *name, const char *help)
{
    char line[41];
    uint8_t n = 0;

    plat_text_clear();
    plat_text_puts(0, 0, title);
    memset(line, ' ', sizeof(line) - 1);
    line[sizeof(line) - 1] = 0;
    plat_text_puts(0, 2, "FILE NAME:");
    while (name[n] && n < 30) {
        line[n] = name[n];
        ++n;
    }
    line[n] = '_';
    line[n + 1] = 0;
    plat_text_puts(11, 2, line);
    plat_text_puts(0, 7, help);
    plat_flush();
}

static void say(const char *s)
{
    uint8_t k;

    plat_text_puts(0, 4, s);
    plat_text_puts(0, 7, "ANY KEY                                 ");
    plat_flush();
    do {
        k = plat_key();
        if (!k)
            plat_idle();
    } while (!k);
}

/* The name of the file, typed in the text area.  Returns 1 for a name, 0 if cancelled, 2 to quit. */
static uint8_t ask(const char *title, char *name)
{
    uint8_t n = 0, k;

    name[0] = 0;
    show(title, name, "ENTER OK  ESC CANCEL");
    for (;;) {
        k = plat_key();
        if (!k) {
            plat_idle();
            continue;
        }
        if (k == KEY_ENTER)
            return n ? 1 : 0;
        if (k == KEY_ESC)
            return 0;
        if (k == CMD_QUIT)
            return 2;
        if (k == CMD_REDRAW)
            ;
        else if ((k == KEY_LEFT || k == 127) && n)
            name[--n] = 0;
        else if (k > ' ' && k < 127 && n < NAME_MAX) {
            name[n++] = (char)k;
            name[n] = 0;
        }
        show(title, name, "ENTER OK  ESC CANCEL");
    }
}

uint8_t city_save(void)
{
    char name[NAME_MAX + 1];
    uint8_t r = ask("SAVE THIS CITY", name);

    if (r == 2)
        return CITY_QUIT;
    if (r != 1)
        return CITY_SAVED;
    memset(header, ' ', 12);                        /* the file name, as the Spectrum keeps it */
    memcpy(header, name, strlen(name) < 12 ? strlen(name) : 12);
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
    char name[NAME_MAX + 1];
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
