; rand: lines 343-373 of disassembly/sim_game.asm (engine)
V_random_seed: defw        $fc03        ; VAR $5CC4 / 23748 - random seed

; Random number generator?
get_random_number:                          ; $5CC6 / 23750
.L5cc6
        push    hl
        push    de
        push    bc
        ld      de,(V_random_seed)
        ld      h,e
        ld      l,253
.L5cd0  ld      a,d
        or      a
.L5cd2  ld      b,0
.L5cd4  sbc     hl,de
        sbc     a,b
        sbc     hl,de
        sbc     a,b
        ld      e,a
        ld      d,b
        sbc     hl,de
        jr      nc,L5ce1                ; (1)
        inc     hl
.L5ce1  ld      (V_random_seed),hl
        ld      a,h
        ld      a,(V_random_seed)
        pop     bc
        pop     de
        pop     hl
        ret     

