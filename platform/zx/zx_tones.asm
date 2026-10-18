; zx_tones: lines 8348-8372 of disassembly/sim_game.asm (zx)


play_rising_tone:                                    ; $9108 / 37128 - Play 127-step rising-pitch sound effect (soundfx1 with increasing pitch)
.L9108  ld      b,127
.L910a  push    bc
        ld      a,b
        and     63
        ld      e,a
        call    soundfx1
        pop     bc
        djnz    L910a                   ; (-11)
        ret     


play_falling_tone:                                    ; $9116 / 37142 - Play 127-step falling-pitch sound effect (soundfx1 with decreasing pitch)
.L9116  ld      b,127
.L9118  push    bc
        ld      a,b
        cpl     
        and     127
        ld      e,a
        call    soundfx1
        pop     bc
        djnz    L9118                   ; (-12)
        ret     
