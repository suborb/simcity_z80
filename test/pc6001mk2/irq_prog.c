/* The program of irq_test.py: the game's interrupt and sound code (target/pc6001mk2/plat_irq.asm, plat_sound.asm) under the ticks model of the mkII. */
#include <stdint.h>

extern void pc_irq_init(void);
extern uint8_t pc_key_take(void);
extern uint16_t pc_ticks(void);
extern void pc_wait_frame(void);
extern void play_place_sound(void);
extern void play_built_sound(void);
extern void done(void);
extern void timer_on(void);
volatile uint16_t result[8];

int main(void)
{
    uint8_t k;

    timer_on();
    pc_irq_init();
    pc_wait_frame();
    pc_wait_frame();
    pc_wait_frame();
    result[0] = pc_ticks();
    while (!(k = pc_key_take()))
        ;
    result[1] = k;
    result[2] = pc_ticks();
    result[3] = pc_key_take();                  /* (taken: 0) */
    play_place_sound();                         /* the refusal's beep: 12 ticks */
    while (pc_ticks() < result[2] + 30)
        pc_wait_frame();
    result[4] = pc_ticks();
    play_built_sound();                         /* two blips: 6 ticks */
    play_place_sound();                         /* (not restarted if busy: this one is a place sound, which is) */
    pc_wait_frame();
    done();
    return 0;
}
