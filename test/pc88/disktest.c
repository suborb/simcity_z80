/* Checks z88dk's PC-8801 disk routines against a real disk unit (test/pc88/disk.py runs it in MAME, which runs the unit's own
   ROM): a pattern is written across three tracks and read back, and the start of this program is read and compared with the
   copy in memory.  result[] is read back through the emulator. */
#include <stdint.h>
#include <arch/pc88.h>

#define N 40
static uint8_t out[N * 256], in[N * 256];
volatile uint8_t result[8];     /* done (0x55), write status, read status, mismatches (2 bytes), image read status, image mismatches (2) */

void main(void)
{
    uint16_t i, bad = 0;
    const uint8_t *img = (const uint8_t *)0x0000;

    __asm__("di");
    for (i = 0; i < N * 256; ++i)
        out[i] = (uint8_t)(i * 7 + (i >> 8) * 13 + 5);
    result[1] = (uint8_t)pc88_disk_write(0, 30, 5, N, out);         /* tracks 30, 31 and 32 */
    result[2] = (uint8_t)pc88_disk_read(0, 30, 5, N, in);
    for (i = 0; i < N * 256; ++i)
        if (in[i] != out[i])
            ++bad;
    result[3] = (uint8_t)bad;
    result[4] = (uint8_t)(bad >> 8);
    result[5] = (uint8_t)pc88_disk_read(0, 0, 2, 8, in);            /* the start of this program, as the bootstrap loaded it */
    bad = 0;
    for (i = 0; i < 8 * 256; ++i)
        if (in[i] != img[i])
            ++bad;
    result[6] = (uint8_t)bad;
    result[7] = (uint8_t)(bad >> 8);
    result[0] = 0x55;
    for (;;)
        ;
}
