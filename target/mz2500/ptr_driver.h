/* What target/common/pointer.c needs of the MZ-2500: the mouse on the SIO's channel B (mz_pointer.c), the arrow (a layer of its own: the second graphics screen drawn over the
   first, so nothing has to be put back), the keys. */
#define PTR_READ(b, x, y)   mz_mouse_read(b, x, y)
#define PTR_SETPOS(x, y)    mz_mouse_setpos(x, y)
#define PTR_HIDE()          plat_mouse_pointer_hide()

extern void mz_mouse_read(uint8_t *buttons, uint16_t *x, uint16_t *y);
extern void mz_mouse_setpos(uint16_t x, uint16_t y);
extern void plat_mouse_pointer_hide(void);
extern uint8_t plat_pointer_keys(void);         /* what is down: 1 left, 2 right, 4 up, 8 down, 16 fire, 32 fast (mz_pointer.c) */
extern uint8_t plat_keyboard_key(void);         /* the keyboard's key, once when it goes down (plat_key's, before the mouse is keys too) */

/* The game's loop does not wait for the frame (a pass takes a few of them), so the keys move the arrow by the frames that have gone by, not by the pass. */
#define PTR_FRAMES()        plat_frames()
extern uint8_t plat_frames(void);               /* a count of the display frames, from the timer (mz_pointer.c) */
