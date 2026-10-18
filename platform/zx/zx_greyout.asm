; zx_greyout: lines 2733-2780 of disassembly/sim_game.asm (zx)
greyout_unaffordable_zones:                                    ; $6DDA / 28122 - Iterate all zone types; grey out each one the player cannot afford
.L6dda  ld      bc,$e00

.L6ddd  push    bc
        ld      a,c
        call    get_cost_for_zone
        ld      b,0
        ld      hl,(V_money)
        ld      a,(V_money+2)
        ld      c,a
        call    l_sub24
        ld      a,c
        and     a
        jp      p,L6df8
        pop     bc
        push    bc
        call    grey_out_zone_icon
.L6df8  pop     bc
        inc     c
        djnz    L6ddd                   ; (-31)
        ret     

; Marks the zone as unclickable - used when we haven't enough money
; ot pay for it
grey_out_zone_icon:
.L6dfd  sla     c
        inc     c
        inc     c
        ld      b,1
        call    xypos
        ld      d,170
        ld      b,16
.L6e0a  ld      c,2
        push    hl
.L6e0d  ld      a,(hl)
        and     d
        ld      (hl),a
        inc     l
        dec     c
        jr      nz,L6e0d                ; (-7)
        pop     hl
        ld      a,d
        cpl     
        ld      d,a
        call    drow
        djnz    L6e0a                   ; (-19)
        ret     

