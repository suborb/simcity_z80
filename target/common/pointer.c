/* The pointer for the targets that always have one (HAVE_POINTER): an arrow that the keys move (plat_pointer_keys: Q A O P, the cursor keys; Space or Enter is its
   button) and a mouse moves too, the two added together.  The target (ptr_driver.h) says how its mouse is read, set and positioned (PTR_READ and PTR_SETPOS: absolute
   coordinates 0..255 by 0..191, buttons 00000MRL), how its arrow is hidden (PTR_HIDE), and gives the keys (plat_pointer_keys, plat_keyboard_key); the arrow's drawing, the
   icons' places and the view's edge scrolling are its own.  This is what the main loop's plat_mouse_input is, and the keys every other screen reads (plat_key): there the mouse
   is a set of keys, so a mouse alone can drive a menu.  A mouse that is not there adds nothing (the SAM's driver reports none until it finds one). */
#include <stdint.h>
#include "platform.h"
#include "engine.h"
#include "ptr_driver.h"

#ifdef HAVE_POINTER

#ifndef PTR_MAX_X                               /* the screen in pixels: the target's ptr_driver.h can say otherwise (the Aquarius+ is 320x200) */
#define PTR_MAX_X   255
#define PTR_MAX_Y   191
#endif
#ifndef PTR_START_X                             /* where the pointer starts, and where a modal screen counts the mouse from */
#define PTR_START_X 128
#define PTR_START_Y 128
#endif
#define MID_X       (PTR_MAX_X / 2)
#define MID_Y       (PTR_MAX_Y / 2)
#define STEP        2                           /* pixels a frame (the map's cells and the mini map's tiles are 8 and 2) */
#define MAX_FRAMES  8                           /* of the frames a slow pass took */
#define STEP_FAST   4
#define ROW         8                           /* pixels of mouse movement to a key in a modal screen: a menu's row */

volatile int16_t plat_mouse_x, plat_mouse_y;
volatile uint8_t plat_mouse_buttons;

static int16_t sent_x, sent_y;                  /* the position as the driver has it: the keys move the pointer too, and it is told before the next read */
static uint8_t last_buttons, seen;
#ifdef PTR_FRAMES
static uint8_t last_frames;                     /* the frame count when plat_mouse_input last looked */
#endif
static uint8_t esc_pending;                     /* the right button went down: the main loop's Esc */
static uint8_t armed = 1;                       /* 0 after a key or button ended a modal screen: the main loop's fire waits until it is released */
static uint8_t modal;                           /* the mouse is being read as keys (plat_modal_key), its position counted from the middle of the screen */
static uint8_t modal_buttons;
static int16_t acc_x, acc_y;

/* The pointer starts in the middle of the map; the target has started its mouse. */
void pointer_start(void)
{
    plat_page_data();
    plat_mouse_x = PTR_START_X;
    plat_mouse_y = PTR_START_Y;
    PTR_SETPOS(PTR_START_X, PTR_START_Y);
    sent_x = PTR_START_X;
    sent_y = PTR_START_Y;
}

/* Read the mouse and the keys, then return bit 0 for movement, bit 1 for a new press of the left button (or fire) and bit 2 while it is held. */
uint8_t plat_mouse_input(void)
{
    uint8_t buttons, keys, step, events = 0;
    uint16_t x, y;
    int16_t nx, ny;

    plat_page_data();                           /* (the driver's state and this code's are in the data, on the SAM) */
    modal = 0;
    if (plat_mouse_x != sent_x || plat_mouse_y != sent_y)
        PTR_SETPOS(plat_mouse_x, plat_mouse_y);    /* the keys moved it (or a modal screen counted the mouse from the middle) */
    PTR_READ(&buttons, &x, &y);
    sent_x = nx = (int16_t)x;
    sent_y = ny = (int16_t)y;
    keys = plat_pointer_keys();
    step = (keys & 32) ? STEP_FAST : STEP;
#ifdef PTR_FRAMES                               /* a target whose loop does not wait for the frame: the step is for each frame that went by */
    {
        uint8_t now = PTR_FRAMES(), frames = (uint8_t)(now - last_frames);

        last_frames = now;
        if (frames > MAX_FRAMES)
            frames = MAX_FRAMES;
        step = (uint8_t)(step * frames);
    }
#endif
    if (keys & 1)
        nx -= step;
    if (keys & 2)
        nx += step;
    if (keys & 4)
        ny -= step;
    if (keys & 8)
        ny += step;
    if (nx < 0)
        nx = 0;
    if (nx > PTR_MAX_X)
        nx = PTR_MAX_X;
    if (ny < 0)
        ny = 0;
    if (ny > PTR_MAX_Y)
        ny = PTR_MAX_Y;
    if (!seen || nx != plat_mouse_x || ny != plat_mouse_y)
        events |= 1;
    seen = 1;
    plat_mouse_x = nx;
    plat_mouse_y = ny;
    if (keys & 16)
        buttons |= 1;
    if ((buttons & 2) && !(last_buttons & 2))
        esc_pending = 1;
    if (!armed) {                               /* what ended a modal screen (Enter, a click) is still down: not a press here */
        if (buttons & 1)
            buttons &= (uint8_t)~1;
        else
            armed = 1;
    }
    plat_mouse_buttons = buttons;
    if (buttons & 1) {
        events |= 4;
        if (!(last_buttons & 1))
            events |= 2;
    }
    last_buttons = buttons;
    return events;
}

/* The right button as the main loop's Esc, once. */
static uint8_t take_esc(void)
{
    uint8_t e = esc_pending;

    esc_pending = 0;
    return e;
}

/* The main loop's keys: the keyboard, or a right click as Esc. */
uint8_t plat_key_game(void)
{
    uint8_t k = plat_keyboard_key();

    plat_page_data();
    if (!k && take_esc())
        k = KEY_ESC;
    return k;
}

/* The key a modal screen reads: the keyboard's, or else the mouse as keys: 8 pixels up, down, left or right are those cursor keys, the left button is Enter and the
   right Esc.  The mouse's steps are counted from the middle of the screen (it is put back there at each look, so the edge of the screen is no limit), and the first look in a
   screen starts from there with the buttons as they are.  The arrow is hidden; the main loop puts it where it was (plat_mouse_input sees it differs from the driver's). */
uint8_t plat_key(void)
{
    uint8_t k = plat_keyboard_key(), buttons, down;
    uint16_t x, y;

    plat_page_data();
    PTR_HIDE();
    if (modal) {
        PTR_READ(&buttons, &x, &y);
        acc_x += (int16_t)x - MID_X;
        acc_y += (int16_t)y - MID_Y;
    } else {
        modal = 1;
        acc_x = acc_y = 0;
        PTR_SETPOS(MID_X, MID_Y);
        PTR_READ(&buttons, &x, &y);
        modal_buttons = buttons;
    }
    PTR_SETPOS(MID_X, MID_Y);
    sent_x = MID_X;
    sent_y = MID_Y;
    down = buttons & (uint8_t)~modal_buttons;
    modal_buttons = buttons;
    if (!k) {
        if (down & 1)
            k = KEY_ENTER;
        else if (down & 2)
            k = KEY_ESC;
        else if (acc_y >= ROW) {
            acc_y -= ROW;
            k = KEY_DOWN;
        } else if (acc_y <= -ROW) {
            acc_y += ROW;
            k = KEY_UP;
        } else if (acc_x >= ROW) {
            acc_x -= ROW;
            k = KEY_RIGHT;
        } else if (acc_x <= -ROW) {
            acc_x += ROW;
            k = KEY_LEFT;
        }
    }
    if (k)
        armed = 0;
    return k;
}

#ifndef PTR_OWN_EDGE                            /* (the SAM's is in assembler, plat_sam.asm) */
extern uint8_t cur_x, cur_y, origin_x, origin_y, frame, view_w, view_h, map_row;

/* Move the view by one cell while the pointer rests on its edge (the game asks only when the pointer is over the map).  Returns 1 if it moved.
   It looks every fourth pass: the city would otherwise fly past. */
uint8_t plat_mouse_edge_scroll(void)
{
    uint8_t col, row;

    if (frame & 3)
        return 0;
    col = (uint8_t)((uint16_t)plat_mouse_x >> 3);
    row = (uint8_t)((uint16_t)plat_mouse_y >> 3);
    if (col == 0) {
        if (cur_x) {
            --cur_x;
            --origin_x;
            return 1;
        }
    } else if (col == view_w - 1) {
        if (cur_x != MAP_W - 1) {
            ++cur_x;
            ++origin_x;
            return 1;
        }
    }
    if (row == map_row) {
        if (cur_y) {
            --cur_y;
            --origin_y;
            return 1;
        }
    } else if (row == map_row + view_h - 1) {
        if (cur_y != MAP_H - 1) {
            ++cur_y;
            ++origin_y;
            return 1;
        }
    }
    return 0;
}
#endif

#endif /* HAVE_POINTER */
