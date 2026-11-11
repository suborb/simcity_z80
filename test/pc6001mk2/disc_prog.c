/* The program of disc_test.py: the z88dk disc routines against the ticks model of the mkII (lib/ticks/memory/pc6001mk2.lua). */
#include <arch/pc6001mk2.h>
#include <stdint.h>
#include <string.h>

#define WINDOW ((uint8_t *)0x9000)
volatile uint8_t result[32];
extern void done(void);

int main(void)
{
    uint8_t buf[256];
    uint16_t i;
    uint8_t ok;

    result[0] = (uint8_t)pc6001mk2_data_track();
    result[1] = (uint8_t)pc6001mk2_overlay_load(0);
    ok = 1;
    for (i = 0; i < 5000; ++i)
        if (WINDOW[i] != (uint8_t)(0xA0 + (i & 7)))
            ok = 0;
    result[2] = ok;
    result[3] = (uint8_t)pc6001mk2_overlay_load(2);
    ok = 1;
    for (i = 0; i < 100; ++i)
        if (WINDOW[i] != 0xC2)
            ok = 0;
    result[4] = ok;
    result[5] = (uint8_t)pc6001mk2_overlay_load(1);
    ok = 1;
    for (i = 0; i < 300; ++i)
        if (WINDOW[i] != 0xB1)
            ok = 0;
    result[6] = ok;
    for (i = 0; i < 256; ++i)
        buf[i] = (uint8_t)(i ^ 0x5A);
    result[7] = (uint8_t)pc6001mk2_disk_write(result[0], 1, 1, buf);
    memset(buf, 0, 256);
    result[8] = (uint8_t)pc6001mk2_disk_read(result[0], 1, 1, buf);
    ok = 1;
    for (i = 0; i < 256; ++i)
        if (buf[i] != (uint8_t)(i ^ 0x5A))
            ok = 0;
    result[9] = ok;
    /* three sectors across a write and a read */
    for (i = 0; i < 256; ++i)
        buf[i] = (uint8_t)(i + 1);
    result[10] = (uint8_t)pc6001mk2_disk_write(result[0] + 1, 14, 1, buf);
    result[11] = (uint8_t)pc6001mk2_disk_read(result[0] + 1, 14, 1, buf);
    result[12] = buf[200];
    /* a sector that is not there */
    result[13] = (uint8_t)pc6001mk2_disk_read(200, 1, 1, buf);
    done();
    return 0;
}
