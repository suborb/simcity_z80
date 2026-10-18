/* The budget screen: tax rate and the three funding levels, with the figures that follow from
   them.  Modal; drawn in the text area with plat_text_*, up to 8 rows of 40 columns. */
#ifndef BUDGET_H
#define BUDGET_H

#include <stdint.h>

/* Show the budget and let the player change it; returns when they accept it.  Returns 1 if the
   platform asked to quit meanwhile, else 0.  The caller redraws the screen afterwards. */
extern uint8_t budget_screen(void);

#endif
