/* The evaluation screen: how the mayor is doing.  Modal; drawn in the text area, 8 rows of 40. */
#ifndef EVALUATION_H
#define EVALUATION_H

#include <stdint.h>

/* The approval: percent of the people who would say "yes, the mayor is doing a good job" (100 votes). */
struct evaluation {
    uint8_t problem[7];                 /* traffic, pollution, crime, fire, taxes, house prices, unemployment: 0..100 % */
    uint16_t score;                     /* city score, 0..1000 */
    uint8_t yes, no;                    /* approval, percent */
    uint8_t city_class;                 /* 0 village .. 5 megalopolis */
    uint8_t has_people;                 /* there is somebody to ask */
};

/* Work out the evaluation from the engine's state. */
extern void evaluate(struct evaluation *e);

/* Show it and wait for the player to dismiss it.  Returns 1 if the platform asked to quit. */
extern uint8_t evaluation_screen(void);

#endif
