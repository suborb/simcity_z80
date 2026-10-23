#include <stdint.h>
#include <string.h>
#include "engine.h"
#include "platform.h"
#include "cityfile.h"
#include "prompt.h"
#ifdef HAVE_FILES
#ifndef FILE_NAME_MAX                       /* the longest file name the platform can keep (plat_config.h) */
#define FILE_NAME_MAX 24
#endif
#define NAME_MAX FILE_NAME_MAX

static uint8_t header[CITY_HEADER];

uint8_t city_save(void)
{
    char name[NAME_MAX + 2];
    uint8_t r = prompt_ask("SAVE THIS CITY", "FILE NAME:", name, NAME_MAX, 0);

    if (r == 2)
        return CITY_QUIT;
    if (r != 1)
        return CITY_SAVED;
    for (r = 0; r < 12; ++r)                        /* the file name, padded with spaces as the Spectrum keeps it */
        header[r] = name[r] && (r == 0 || header[r - 1] != ' ') ? name[r] : ' ';
    prompt_status("SAVING...");
    memcpy(header + 12, V_money, 7);               /* money, the month and the year follow each other */
    city_name_to(header + 19);                      /* the city name */
    if (plat_file_save(name, header, CITY_HEADER, levelmap, MAP_W * MAP_H))
        prompt_say("COULD NOT SAVE THE CITY");
    else
        prompt_say("SAVED");
    return CITY_SAVED;
}

uint8_t city_load(void)
{
    char name[NAME_MAX + 2];
    uint8_t r = prompt_ask("LOAD A CITY", "FILE NAME:", name, NAME_MAX, 0);

    if (r == 2)
        return CITY_QUIT;
    if (r != 1)
        return CITY_SAVED;
    prompt_status("LOADING...");
    r = plat_file_load(name, header, CITY_HEADER, levelmap, MAP_W * MAP_H);
    if (r) {                                        /* 1: nothing read; 2: the map is half read */
        prompt_say("COULD NOT LOAD THE CITY");
        return r == 1 ? CITY_SAVED : CITY_BROKEN;
    }
    sim_loaded();                                   /* a clean simulation, then what the file holds */
    memcpy(V_money, header + 12, 7);
    city_name_from(header + 19);
#ifdef HAVE_APPNAME
    plat_set_name(city_name);
#endif
    return CITY_LOADED;
}

#endif
