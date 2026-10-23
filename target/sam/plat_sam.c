/* SAM Coupe platform: the drawing (the tool icons too), the screen set-up and the keyboard are in plat_sam.asm; this has the
   frame counter. */
#include <stdint.h>
#include "platform.h"

static uint16_t clock_count;

uint16_t plat_clock(void) { return clock_count; }
void plat_idle(void) { ++clock_count; }
void plat_flush(void) {}
