; zx_udgs: lines 11041-11202 of disassembly/sim_game.asm (zx)
; The UDGs for the images
; data of some description?
; at 59472
        BINARY        "assets/udgs.bin"


V_tickcount:        defb    0       ; VAR $F704 / 63236 - tickcount for taskswap
;f705
V_simulation_disabled: defb    1     ; VAR $F705 / 63237 - simulation enabled
                
                defb    0       ;Unused

V_task0_stack:  defw    0       ; VAR $F707 / 63239 - task 0 stack (ui)
V_task1_stack:  defw    0       ; VAR $F709 / 63241 - task 1 stack (simulator)

;f70b
.interrupt
        push    ix
        push    iy
        push    hl
        push    de
        push    bc
        push    af
        ex      af,af'
        exx     
        push    hl
        push    de
        push    bc
        push    af
        call    rdkeys
        ld      a,(V_simulation_disabled)
        and     a
        jr      nz,Lf73e                ; (28)
        ld      hl,V_tickcount
        ld      a,(hl)
        and     a
        jr      z,Lf733                 ; (10)
        ld      (V_task1_stack),sp
        ld      sp,(V_task0_stack)
        jr      task_switcher_toggle                   ; (8)

.Lf733  ld      (V_task0_stack),sp
        ld      sp,(V_task1_stack)

task_switcher_toggle:                                    ; $F73B / 63291 - Toggle task flag (XOR 1), restore all registers and return to switched-to task
.Lf73b  xor     1
        ld      (hl),a

.Lf73e  pop     af
        pop     bc
        pop     de
        pop     hl
        ex      af,af'
        exx     
        pop     af
        pop     bc
        pop     de
        pop     hl
        pop     iy
        pop     ix
        ei      
        ret     


; Vars for print routne
.V_digit_char_buf        defb        0       ; VAR $F74E / 63310 -
.textpos        defw        0        ;VAR - f74f text print address
.textxy                defw        0        ;VAR - text xy posn
.textcol        defb        0        ;VAR - text colour

; Print to screen at address specified by (textpos)
; And colour textcol
; Uses ROM plot routine

prchar:
Lf754:
        ld      l,a
        ld      h,0
        add     hl,hl
        add     hl,hl
        add     hl,hl
        ld      bc,15360
        add     hl,bc
        ex      de,hl
        ld      hl,(textpos)
        ld      b,8

.Lf764  ld      a,(de)
        ld      c,a
        srl     c
        or      c
        ld      (hl),a
        inc     de
        inc     h
        djnz    Lf764                   ; (-10)

.dotextcol  
        ld      a,(textcol)
        cp      255
        ret     z
.dotextcol_1  
        ld      c,a
        dec     h
        ld      a,h
        rrca    
        rrca    
        rrca    
        and     3
        or      88
        ld      h,a
        ld      (hl),c
        ret     

; Reads keyboard ports and dumps results
; at keystore

.rdkeys  
        ld      hl,keystore
        ld      bc,65278
        ld      d,8
.Lf789  in      a,(c)
        ld      (hl),a
        inc     l
        rlc     b
        dec     d
        jr      nz,Lf789                ; (-9)
        call    kempston_to_keystore
        jp      cursor_keys_sym_shift
        ret     

        jp      $fe0f
        jp      $fe0f

; Load tape file

.load  
        inc     d
        ex      af,af'
        dec     d
        ld      a,15
        out     (254),a
        call    zx_rom_tape_load
        ret     


restart_rom:                                    ; $F7AA / 63402 - Jump to ROM address $04C6 (warm restart / error handler entry)
.Lf7aa  jp      $04c6

; Pause 5000

.pause5000  
        push    bc
        ld      bc,5000
.Lf7b1  dec     bc
        ld      a,b
        or      c
        jp      nz,Lf7b1
        pop     bc
        djnz    pause5000                   ; (-13)
        ret     


