/* Saving and loading a city.  The file is what the Spectrum writes to tape, without the tape
   framing: a 31 byte header (the 12 character file name, 7 bytes of money, month and year from the
   engine's variables, and the 12 character city name) and then the map (MAP_W * MAP_H bytes: 9216 at 96x96). */
#ifndef CITYFILE_H
#define CITYFILE_H

#include <stdint.h>

#define CITY_HEADER 31
#define CITY_SAVED  0           /* what the two calls below return: nothing happened, or it was saved */
#define CITY_LOADED 1           /* a city was loaded: the game starts it afresh */
#define CITY_QUIT   2           /* the platform asked to quit */
#define CITY_BROKEN 3           /* a file was half read, and the map with it: the game starts a new city */

/* Ask for a file name in the text area and save the city to it. */
extern uint8_t city_save(void);

/* Ask for a file name and load a city from it.  Returns CITY_LOADED if it did, CITY_SAVED if there was
   nothing to load (the city goes on), CITY_BROKEN if the file ended in the middle of the map. */
extern uint8_t city_load(void);

#endif
