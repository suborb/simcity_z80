; zx_place_sound: lines 3410-3424 of disassembly/sim_game.asm (zx)
play_place_sound:                                    ; $71E4 / 29156 - Play placement sound if A/Q/P/O keys all held (sound gate check)
.L71e4  ld      a,(keystore+1)
        and     1       ;'A'
        ret     z
        ld      a,(keystore+2)
        and     1       ;'Q'
        ret     z
        ld      a,(keystore+5)
        and     1       ;'P;
        ret     z
        ld      a,(keystore+5)
        and     2       ;'O'
        ret     z
        jp      soundfx2

