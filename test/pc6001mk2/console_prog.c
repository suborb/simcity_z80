/* The program of console_test.py: z88dk's PC-6001mkII 320x200 console and graphics (mode 3 of the mc6847 console, pc6001mk2.lib) under the ticks model. */
#include <stdio.h>
#include <graphics.h>
#include <stdint.h>

extern void done(void);
extern uint16_t peek_char(uint8_t x, uint8_t y);   /* generic_console_vpeek: the character, or 0x100 for none */
extern void scroll_up(void);
volatile uint16_t result[16];

int main(void)
{
    clg();
    printf("HELLO");                          /* row 0, from column 0 */
    plot(10, 20);
    plot(319, 199);
    plot(320, 10);                            /* off the screen */
    plot(0, 0);
    unplot(0, 0);
    xorplot(120, 100);                        /* the paper pen with the ink xored in... */
    xorplot(120, 100);                        /* ... and out again */
    xorplot(130, 100);                        /* (once) */
    plot(5, 150);
    result[0] = point(5, 150);
    result[1] = point(6, 150);
    result[2] = getmaxx();
    result[3] = getmaxy();
    result[4] = peek_char(0, 0);
    result[5] = peek_char(4, 0);
    result[6] = peek_char(10, 5);             /* an empty cell: a space */
    scroll_up();
    result[7] = peek_char(0, 0);              /* what was row 1: empty */
    done();
    return 0;
}
