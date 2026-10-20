; zx_demolish_wait: lines 3551-3568 of disassembly/sim_game.asm (zx)
; If V_demolish_wait is set, wait for SPACE key release or timeout before continuing
.wait_if_demolish_pending
.L72ed  ld      a,(V_demolish_wait)
        and     a
        ret     z

        ld      de,40000

.L72f5  ld      a,(keystore+7)
        and     1       ;'SPACE'
        ret     nz

        dec     de
        ld      a,d
        or      e
        jr      nz,L72f5                ; (-11)
        ret     

