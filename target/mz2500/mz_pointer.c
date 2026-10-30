/* MZ-2500: the pointer's own parts (the rest is target/common/pointer.c, with ptr_driver.h).  The mouse is on the SIO's channel B: the YM2203's port A bit 3 selects it and DTR
   going low makes it send three bytes (the buttons and overflow bits, then the x and y movements: Takeda's mouse.cpp), which are collected here a frame at a time.  The
   arrow is drawn in the second graphics screen (mode $14: screen B over A, where the pixel value 0 is transparent), so it never touches the map or the cell cache: it is
   cleared where it was and drawn where it is.  The keys that move it are Q A O P and the cursor keys, Space or Enter its button, Shift for fast.  Resident code. */
#include <stdint.h>
#include <string.h>
#include "platform.h"
#include "engine.h"
#include "ptr_driver.h"

#pragma codeseg BANK_12

#ifdef HAVE_MOUSE

extern void pointer_start(void);                /* (target/common/pointer.c) */
extern void mz_arrow(uint8_t y, uint8_t xb, const uint8_t *buf) __smallc;
extern void mz_clearb(void);
extern void mz_mouse_init(void);
extern uint8_t mz_sio_ready(void);
extern uint8_t mz_sio_data(void);
extern void mz_sio_trigger(void);
extern uint8_t mz_keycol(uint8_t column) __smallc;
extern void mz_pit_init(void);
extern uint16_t mz_pit_read(void);

#define XB0     4                               /* the byte column of the map's column 0 (plat_mz2500.asm) */
#define MAXX    255                             /* the game's 256 x 192 pixels */
#define MAXY    191

/* A count of the frames, from the timer's 31250 Hz clock (520 ticks a frame at 60 Hz): the elapsed ticks are added up and counted off.  Called at least every two seconds.
   A "frame" here is two display frames (1040 ticks): the pointer's step of 2 pixels a frame would otherwise be 120 pixels a second, which jumps cells on a slow pass. */
#define TICKS_FRAME 1040

static uint16_t last_t, acc_t;
static uint8_t frame_count;

uint8_t plat_frames(void)
{
    uint16_t t = mz_pit_read();

    acc_t += (uint16_t)(last_t - t);            /* (it counts down) */
    last_t = t;
    while (acc_t >= TICKS_FRAME) {
        acc_t -= TICKS_FRAME;
        ++frame_count;
    }
    return frame_count;
}

static int16_t mx, my;                          /* the mouse's position */
static uint8_t mbtn;
static uint8_t mbuf[3], mcnt;
static int16_t shown_x = -1, shown_y;           /* where the arrow is drawn, or -1 if it is not */
static uint16_t rows[16];                       /* the arrow's rows, bit 0 the leftmost pixel */
static uint16_t outline[16];

/* The arrow: 14 rows, a bit a column from the left (the tip is the top left); bit 15 is the leftmost */
static const uint16_t arrow[14] = {
    0x8000, 0xC000, 0xE000, 0xF000, 0xF800, 0xFC00, 0xFE00, 0xFF00, 0xFF80, 0xF800, 0xDC00, 0x9C00, 0x1C00, 0x0C00
};

static uint16_t reverse16(uint16_t v)
{
    uint16_t r = 0;
    uint8_t i;

    for (i = 0; i < 16; ++i) {
        r = (uint16_t)((r << 1) | (v & 1));
        v >>= 1;
    }
    return r;
}

/* The mouse's bytes of the frames that have gone by, added to the position (a packet is three bytes: if fewer are there at the next look they are dropped). */
static void mouse_poll(void)
{
    uint8_t got = 0;
    int16_t dx, dy;

    while (mz_sio_ready()) {
        mbuf[mcnt++] = mz_sio_data();
        got = 1;
        if (mcnt == 3) {
            mcnt = 0;
            dx = (int8_t)mbuf[1];
            dy = (int8_t)mbuf[2];
            if (mbuf[0] & 0x10)
                dx = 127;
            else if (mbuf[0] & 0x20)
                dx = -128;
            if (mbuf[0] & 0x40)
                dy = 127;
            else if (mbuf[0] & 0x80)
                dy = -128;
            mx += dx;
            my += dy;
            mbtn = mbuf[0] & 3;
        }
    }
    if (!got)
        mcnt = 0;
    mz_sio_trigger();                           /* the next movement, for the next look */
    if (mx < 0)
        mx = 0;
    if (mx > MAXX)
        mx = MAXX;
    if (my < 0)
        my = 0;
    if (my > MAXY)
        my = MAXY;
}

void mz_mouse_read(uint8_t *buttons, uint16_t *x, uint16_t *y)
{
    mouse_poll();
    *buttons = mbtn;
    *x = (uint16_t)mx;
    *y = (uint16_t)my;
}

void mz_mouse_setpos(uint16_t x, uint16_t y)
{
    mx = (int16_t)x;
    my = (int16_t)y;
}

/* Starts the mouse, puts the pointer in the middle of the map and makes the arrow: its rows with the bits turned round for the planes, and the outline of it (the rows and the
   cells next to them: colour 8, dark grey, since black is transparent). */
void plat_mouse_init(void)
{
    uint8_t r;
    uint16_t o;

    mz_pit_init();
    last_t = mz_pit_read();
    mz_mouse_init();
    mz_clearb();
    memset(rows, 0, sizeof(rows));
    for (r = 0; r < 14; ++r)
        rows[r + 1] = reverse16(arrow[r]) << 1;
    for (r = 0; r < 16; ++r) {
        o = rows[r] | (r ? rows[r - 1] : 0) | (r < 15 ? rows[r + 1] : 0);
        outline[r] = (uint16_t)(o | (o << 1) | (o >> 1));
    }
    pointer_start();
    shown_x = -1;
}

static void erase_arrow(void)
{
    if (shown_x >= 0) {
        mz_arrow((uint8_t)shown_y, (uint8_t)(XB0 + (shown_x >> 3)), 0);
        shown_x = -1;
    }
}

/* The pointer, once a frame: where it is now.  The arrow is one up and one left of the position, as the MSX2's (its outline has room). */
void plat_mouse_pointer_refresh(void)
{
    static uint8_t buf[96];
    uint8_t r, sh, i;
    uint32_t f, o;
    int16_t x = plat_mouse_x, y = plat_mouse_y;

    if (x == shown_x && y == shown_y)
        return;
    erase_arrow();
    sh = (uint8_t)(x & 7);
    for (r = 0; r < 16; ++r) {
        f = (uint32_t)rows[r] << sh;
        o = f | ((uint32_t)outline[r] << sh);
        for (i = 0; i < 3; ++i) {
            buf[r * 6 + i] = (uint8_t)(f >> (8 * i));
            buf[r * 6 + 3 + i] = (uint8_t)(o >> (8 * i));
        }
    }
    mz_arrow((uint8_t)y, (uint8_t)(XB0 + (x >> 3)), buf);
    shown_x = x;
    shown_y = y;
}

/* Hidden while a menu is up, which the keys use (the next refresh shows it again). */
void plat_mouse_pointer_hide(void)
{
    erase_arrow();
}

/* The tool icon under the pointer (0 to 13), or $FF: they are 24 pixels wide and 16 high, in two rows of seven from y=8 (plat_icons). */
uint8_t plat_mouse_icon_hit(void)
{
    uint8_t x = (uint8_t)plat_mouse_x, y = (uint8_t)plat_mouse_y;

    if (y < 8 || y >= 40 || x >= 168)
        return 0xFF;
    return (uint8_t)((y >= 24 ? 7 : 0) + x / 24);
}

/* The keys that move the arrow, as target/common/pointer.c wants them: 1 left (O, or the cursor key), 2 right (P), 4 up (Q), 8 down (A), 16 fire (Space or Enter), 32 fast (Shift).
   The matrix: column 3 has Space (bit 1), Enter (2) and the cursor keys (up 3, down 4, left 5, right 6), column 4 has A (1), column 5 O (7), column 6 P (0) and Q (1), column 11 Shift (2);
   a key that is down is a 0 bit. */
uint8_t plat_pointer_keys(void)
{
    uint8_t c3 = (uint8_t)~mz_keycol(3), c4 = (uint8_t)~mz_keycol(4), c5 = (uint8_t)~mz_keycol(5), c6 = (uint8_t)~mz_keycol(6), c11 = (uint8_t)~mz_keycol(11);
    uint8_t k = 0;

    if ((c5 & 0x80) || (c3 & 0x20))
        k |= 1;
    if ((c6 & 0x01) || (c3 & 0x40))
        k |= 2;
    if ((c6 & 0x02) || (c3 & 0x08))
        k |= 4;
    if ((c4 & 0x02) || (c3 & 0x10))
        k |= 8;
    if (c3 & 0x06)
        k |= 16;
    if (c11 & 0x04)
        k |= 32;
    return k;
}

#endif /* HAVE_MOUSE */
