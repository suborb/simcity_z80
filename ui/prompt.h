/* A line of text asked for in the text area (a file name, a city's name) and a message with "any key".
   The city's own name is kept here, as the Spectrum kept it: 12 characters. */
#ifndef PROMPT_H
#define PROMPT_H

#include <stdint.h>

#define CITY_NAME_LEN 12

extern char city_name[CITY_NAME_LEN + 1];   /* the city's name, not padded */

/* Ask for text with the title and label shown, into name (max + 2 bytes: it shows a cursor while typing); spaces
   are allowed in it if `spaces` is set (a city's name: not a file's).
   Returns 1 for a name, 0 if cancelled or empty, 2 if the platform asked to quit. */
extern uint8_t prompt_ask(const char *title, const char *label, char *name, uint8_t max, uint8_t spaces);

/* Show a message and wait for a key. */
extern void prompt_say(const char *message);

/* Set city_name from 12 characters padded with spaces, as the file header keeps it; or 12 characters made of it. */
extern void city_name_from(const uint8_t *padded);
extern void city_name_to(uint8_t *padded);

#endif
