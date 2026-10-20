; zx_crash_sound: lines 4593-4605 of disassembly/sim_game.asm (zx)

play_crash_sound:                                    ; $78BD / 30909 - Play crash sound effect (127 iterations of soundfx1 with ramping pitch)
.L78bd  ld      b,255
        ld      e,0

.L78c1  push    bc
        call    soundfx1
        pop     bc
        inc     e
        djnz    L78c1                   ; (-8)
        ret     


