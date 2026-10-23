/* NEC PC-8801 platform: the drawing, the screen set-up and the keyboard are in plat_pc88.asm; this has the tool icons, the
   frame counter and the files. */
#include <stdint.h>
#include "platform.h"

static uint16_t clock_count;

uint16_t plat_clock(void) { return clock_count; }
void plat_idle(void) { ++clock_count; }
void plat_flush(void) {}
