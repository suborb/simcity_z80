/* What every generic CP/M platform shares (target/cpm/plat_cpm.c draws on a terminal, target/pcw/ on the PCW's bitmap): the BDOS keys, the frame delay, the line
   editor and the files. */
#include <stdint.h>
#include <fcntl.h>
#include <unistd.h>
#include "platform.h"

#ifndef CPM_DELAY
#define CPM_DELAY 20                /* the chunks of plat_idle's frame, if there is no clock to measure it by */
#endif

extern uint8_t cpm_conin(void);
static uint16_t clock_count;

/* Keys: the BDOS gives ASCII.  The cursor keys are the WordStar diamond (^S ^D ^E ^X) as well as Q A O P, since terminals differ. */
uint8_t plat_key(void)
{
    uint8_t k;

    plat_flush();
    k = cpm_conin();
    switch (k) {
    case 19: return KEY_LEFT;           /* ^S */
    case 4:  return KEY_RIGHT;          /* ^D */
    case 5:  return KEY_UP;             /* ^E */
    case 24: return KEY_DOWN;           /* ^X */
    case 127: return KEY_LEFT;
    }
    if (k >= 'A' && k <= 'Z' && k != 'O' && k != 'P' && k != 'Q' && k != 'A')   /* (shift with O P Q A moves the cursor eight cells) */
        k = (uint8_t)(k + ('a' - 'A'));
    return k;
}

uint16_t plat_clock(void) { return clock_count; }

/* A frame.  There is no timer a program can read, so the first call measures one: a chunk is a few turns of a loop and a read of the time of day (BDOS 105, whose
   seconds change once a second), and a fiftieth of the chunks of a second is a frame.  If the clock does not tick the frame is what CPM_DELAY says. */
extern uint8_t cpm_seconds(void);
static uint8_t frame_chunks;

static uint8_t chunk(void)
{
    volatile uint8_t i;

    for (i = 0; i < 4; ++i)
        ;
    return cpm_seconds();
}

static void calibrate(void)
{
    uint8_t s0, s;
    uint16_t n = 0, guard = 0;

    frame_chunks = CPM_DELAY;
    s0 = cpm_seconds();
    while ((s = chunk()) == s0)
        if (++guard == 0)
            return;                                 /* the clock does not tick */
    s0 = s;
    do {
        ++n;
        s = chunk();
    } while (s == s0 && n != 0xFFFF);
    if (s != s0 && n >= 50)
        frame_chunks = (uint8_t)(n / 50 > 255 ? 255 : n / 50);
}

void plat_idle(void)
{
    uint8_t i;

    if (!frame_chunks)
        calibrate();
    ++clock_count;
    for (i = 0; i < frame_chunks; ++i)
        chunk();
}

/* The line editor: ENTER ends, ESC cancels, backspace takes a letter back. */
uint8_t plat_text_input(uint8_t col, uint8_t row, char *buf, uint8_t max, uint8_t spaces)
{
    uint8_t n = 0, k;

    buf[0] = 0;
    for (;;) {
        k = plat_key();
        if (!k) {
            plat_idle();
            continue;
        }
        if (k == KEY_ENTER)
            return n != 0;
        if (k == KEY_ESC)
            return 0;
        if ((k == KEY_LEFT || k == 8) && n) {
            buf[--n] = 0;
            plat_put((uint8_t)(col + n), row, ' ');
        } else if (k >= (spaces ? ' ' : '!') && k < 127 && n < max) {
            buf[n++] = (char)k;
            buf[n] = 0;
            plat_put((uint8_t)(col + n - 1), row, k);
        }
    }
}

uint8_t plat_file_save(const char *name, const uint8_t *a, uint16_t alen, const uint8_t *b, uint16_t blen)
{
    int fd = open(name, O_WRONLY | O_CREAT | O_TRUNC, 0);
    uint8_t r = 1;

    if (fd == -1)                       /* (the handle is the FCB's address: negative as an int when it is above $8000) */
        return 1;
    if (write(fd, (void *)a, alen) == (int)alen && write(fd, (void *)b, blen) == (int)blen)
        r = 0;
    close(fd);
    return r;
}

uint8_t plat_file_load(const char *name, uint8_t *a, uint16_t alen, uint8_t *b, uint16_t blen)
{
    int fd = open(name, O_RDONLY, 0);
    uint8_t r = 0;
    char extra[FILE_RECORD];

    if (fd == -1)
        return 1;
    if (read(fd, a, alen) != (int)alen)
        r = 1;
    else if (read(fd, b, blen) != (int)blen)
        r = 2;
    else if (read(fd, extra, FILE_RECORD) > FILE_RECORD - 1)    /* more than the record's padding: a bigger map */
        r = 2;
    close(fd);
    return r;
}
