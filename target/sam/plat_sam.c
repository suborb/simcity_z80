/* SAM Coupe platform: the drawing (the tool icons too), the screen set-up and the keyboard are in plat_sam.asm; this has the
   frame counter. */
#include <stdint.h>
#include "platform.h"

static uint16_t clock_count;

uint16_t plat_clock(void) { return clock_count; }
#ifdef SOUND_TEST
extern void snd_test(void);
void plat_idle(void) { ++clock_count; snd_test(); }      /* (the build for test/sam/sound_check.py) */
#else
void plat_idle(void) { ++clock_count; }
#endif
void plat_flush(void) {}
