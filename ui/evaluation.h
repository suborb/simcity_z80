/* The evaluation screen: how the mayor is doing.  Modal; drawn in MODAL_ROWS rows of 40 columns. */
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

/* The number of zones without power, as it was when the last tick finished: the engine counts it afresh from
   0 in each tick, so V_unPwrdZCnt is only part of the answer while the simulation is halfway.  The game sets this
   when a tick completes. */
extern uint16_t eval_unpowered;

/* Work out the evaluation from the engine's state. */
extern void evaluate(struct evaluation *e);

/* Show it and wait for the player to dismiss it.  Returns 1 if the platform asked to quit. */
extern uint8_t evaluation_screen(void);

#endif
