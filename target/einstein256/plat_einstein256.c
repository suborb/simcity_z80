/* The Einstein 256's parts of the V9938 platform (target/common/v9938/plat_v9938.c): the screen mode, the frame wait and the keys, which CP/M reads through the BDOS. */
#include <stdint.h>
#include "platform.h"

extern void v9938_vreg(uint8_t reg, uint8_t value);
extern void einstein_screen5(void);
extern void einstein_wait_frame(void);
extern void einstein_fatal(const char *message);
extern uint8_t einstein_getkey(void);
extern void einstein_dos_quiet(void);           /* (einstein_dos.c) */
extern void einstein_dos_loud(void);

static uint16_t clock_count;

void v9938_fatal(const char *dollar_string)
{
    einstein_fatal(dollar_string);
}

void v9938_screen5(void)
{
    einstein_dos_quiet();                       /* (a failed disc operation is an error for the game, not the DOS's prompt) */
    einstein_screen5();
    v9938_vreg(9, 0);                           /* 192 lines */
    v9938_vreg(8, 0x0A);                        /* V9938: sprites disabled */
}

void v9938_leave(void)
{
    einstein_dos_loud();
}

uint16_t plat_clock(void) { return clock_count; }
/* Once a pass of the game's loop, which waits for the next frame (the retrace flag: the vertical blank interrupt is off) */
void plat_idle(void)
{
    ++clock_count;
    einstein_wait_frame();
}
void plat_flush(void) {}

/* CP/M direct console input; Einstein keys are read as ASCII through BDOS. */
uint8_t plat_key(void)
{
    uint8_t k = einstein_getkey();

    if (k >= 'A' && k <= 'Z')
        k = (uint8_t)(k + ('a' - 'A'));
    if (k == 13)
        return KEY_ENTER;
    if (k == 27)
        return KEY_ESC;
    return k;
}
