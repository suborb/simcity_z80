/* Host test of mz800_disk_rw (the library's MB8876 driver), built with zcc +mz800 and run on the ticks MZ-800 model (disk_test.py). */
#include <arch/mz800.h>

uint8_t  buf[9 * 256];
int      rc[16];
uint8_t  pat[256];
uint16_t secs[8] = { 0, 1, 15, 16, 17, 33, 79, 80 };
volatile uint8_t finished;

int main(void)
{
    int i;

#asm
    di
#endasm
    for (i = 0; i < 8; i++) {
        rc[i] = mz800_disk_rw(0, 0, secs[i], buf + i * 256);
    }
    /* write a sector on another cylinder and head, then read it back */
    for (i = 0; i < 256; i++) {
        pat[i] = i * 3 + 1;
    }
    rc[8] = mz800_disk_rw(1, 0, 200, pat);
    rc[9] = mz800_disk_rw(0, 0, 200, buf + 8 * 256);
    mz800_disk_off();
    finished = 1;
    for (;;) ;
}
