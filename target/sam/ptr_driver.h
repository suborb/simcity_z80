/* What target/common/pointer.c needs of the SAM Coupe: z88dk's mouse (in_MouseSAM), the software arrow (plat_sam.c: erased to hide it), the keys.  The mouse driver's state and
   this code's are in the data bank, which the code that reads the mouse has to have mapped. */
#include <arch/sam.h>

#define PTR_READ(b, x, y)   in_MouseSAM(b, x, y)
#define PTR_SETPOS(x, y)    in_MouseSAMSetPos(x, y)
#define PTR_HIDE()          plat_mouse_pointer_erase()

/* The game's loop does not wait for the frame (a pass takes a few of them), so the keys move the arrow by the frames that have gone by, not by the pass. */
#define PTR_OWN_EDGE                            /* the edge scrolling is in assembler (plat_sam.asm) */
#define PTR_FRAMES()        plat_frames()

extern uint8_t plat_frames(void);               /* the 50 Hz interrupt's count (plat_sound.asm) */
extern void plat_mouse_pointer_erase(void);
extern uint8_t plat_pointer_keys(void);         /* what is down: 1 left, 2 right, 4 up, 8 down, 16 fire, 32 fast (plat_sam.asm) */
extern uint8_t plat_keyboard_key(void);         /* the keyboard's key, once when it goes down (plat_key's, before the mouse is keys too) */
