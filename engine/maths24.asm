; maths24: lines 1535-1640 of disassembly/sim_game.asm (engine)
; 24 bit arithmetic routines
; operators: chl = chl - bde

.l_sub24  
        and     a
        sbc     hl,de
        ld      a,c
        sbc     a,b
        ld      c,a
        ret     

; chl = chl + bde
.l_add24  
        add     hl,de
        ld      a,c
        adc     a,b
        ld      c,a
        ret     

; Multiply 16x16 -> 24
; c'hl' =  hl * de ?

L_mult_24_16x16:
.L668c  push    de
        exx     
        pop     de
        ld      hl,0
        ld      c,l
        exx     
        ld      c,h
        ld      a,l
        ld      b,16
.L6698  exx     
        add     hl,hl
        rl      c
        exx     
        sla     a
        rl      c
        jr      nc,L66ad                ; (10)
        exx     
        ex      af,af'
        add     hl,de
        ld      a,c
        adc     a,0
        ld      c,a
        ex      af,af'
        exx     
        add     hl,de
.L66ad  djnz    L6698                  ; (-23)
        exx     
        push    hl
        push    bc
        exx     
        pop     bc
        pop     hl
        ret     

; Divide?
div24_chl_by_a:                                    ; $66B6 / 26294 - 24-bit divide C:HL by A, result in C:HL; used for tax/population percentages
.L66b6  ld      e,c
        ld      b,24
        ld      c,a
        xor     a
.L66bb  add     hl,hl
        rl      e
        rla     
        jr      c,L66c4                 ; (3)
        cp      c
        jr      c,L66cc                 ; (8)
.L66c4  sub     c
        ld      d,a
        inc     hl
        ld      a,e
        adc     a,0
        ld      e,a
        ld      a,d
.L66cc  djnz    L66bb                  ; (-19)
        ld      c,e
        ret     

; Division routine?
; hl = hl / de, de = hl % de

L_div16x16:
.L66d0  ld      a,d
        or      e
        jr      z,L66ee                 ; (26)
        ld      b,h
        ld      c,l
        ld      hl,0
        ld      a,16
.L66db  scf     
        rl      c
        rl      b
        adc     hl,hl
        sbc     hl,de
        jr      nc,L66e8                ; (2)
        add     hl,de
        dec     c
.L66e8  dec     a
        jr      nz,L66db                ; (-16)
        ld      h,b
        ld      l,c
        ret     
.L66ee  ld      hl,0
        ret     
