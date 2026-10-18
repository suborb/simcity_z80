; zx_ui1b: lines 1371-1534 of disassembly/sim_game.asm (zx)

V_print_end_pos:    defw    $40bd          ; VAR $65A3 / 26019 - saved screen address after last printed number (textpos at end of prt24bit_cde)


; Print a 16 bit number with sign
; Uses 24 bit routine
; Entry: hl=number to print
;         bc=xypos

.prt16bit  
        push    hl
        call    xypos
        ld      (textpos),hl
        pop     hl
        ld      c,0
        call    prt24bit_cde
        ret     

; I think this prints a 24 bit number...but perhaps not...
; Entry: bc = xypos
;          hl = pointer to number to print

.prt24bit  
        push    hl
        call    xypos
        ld      (textpos),hl
        pop     hl
        ld      e,(hl)
        inc     hl
        ld      d,(hl)
        inc     hl
        ld      c,(hl)
        ex      de,hl

prt24bit_cde:
.L65c1  xor     a
        ld      (V_num_print_state),a
        ld      (V_num_print_state+1),a
        call    prneg24
        push    hl
        push    bc
        exx     
        pop     bc
        pop     hl
        ld      b,240                ;-1000000
        ld      de,48576
        exx     
        call    print_24bit_digit
        exx     
        ld      b,254                ;-100000
        ld      de,31072
        exx     
        call    print_24bit_digit
        exx     
        ld      b,255                ;-10000
        ld      de,55536
        exx     
        call    print_24bit_digit
        exx     
        ld      b,255                ;-1000
        ld      de,64536
        exx     
        call    print_24bit_digit
        exx     
        ld      b,255                ;-100
        ld      de,65436
        exx     
        call    print_24bit_digit
        exx     
        ld      b,255                ;-10
        ld      de,65526
        exx     
        call    print_24bit_digit
        exx     
        push    hl
        exx     
        pop     hl
        ld      b,l
        call    print_digit_nonzero
        ld      hl,(textpos)
        ld      (V_print_end_pos),hl
        ld      a,(V_num_print_state+1)
        and     a
        ret     z

        ld      b,a

.L661f  push    bc
        ld      a,32
        call    prchar
        call    incprpos
        pop     bc
        djnz    L661f                   ; (-12)
        ret     

; If a number is negative, print a - sign and cpl (to positive)
; So we can then print as number

.prneg24  
        bit     7,c
        ret     z
        ld      a,c
        cpl     
        ld      c,a
        ld      a,h
        cpl     
        ld      h,a
        ld      a,l
        cpl     
        ld      l,a
        ld      de,1
        add     hl,de
        ld      a,c
        adc     a,0
        ld      c,a
        push    hl
        push    bc
        ld      a,'-'
.L6644
        call    replace_with_direct_prchar_call
        call    incprpos
        pop     bc
        pop     hl
        ret     

V_num_print_state:        defw       $0202       ; VAR $664D / 26189 - number printing state: byte 0 = leading-zero suppression flag (0=still suppressing); byte 1 = count of suppressed leading zeros (printed as trailing spaces)


print_24bit_digit:                                    ; $664F / 26191 - Extract one decimal digit from 24-bit C':HL' via repeated addition; print via print_digit_nonzero
.L664f  ld      b,0
.L6651  inc     b
        exx     
        add     hl,de
        ld      a,c
        adc     a,b
        ld      c,a
        exx     
        jr      c,L6651                 ; (-9)
        exx     
        sbc     hl,de
        ld      a,c
        sbc     a,b
        ld      c,a
        exx     
        dec     b
        ld      a,(V_num_print_state)
        and     a
        jr      nz,print_digit_nonzero                ; (7)
        ld      a,b
        and     a
        jr      z,L667b                 ; (15)
        ld      (V_num_print_state),a

print_digit_nonzero:                                    ; $666F / 26223 - Print digit in B if non-zero, else advance suppress-leading-zero state
.L666f  ld      a,b
        add     a,48
        ld      (V_digit_char_buf),a
        call    replace_with_direct_prchar_call
        jp      incprpos

.L667b  ld      hl,V_num_print_state+1
        inc     (hl)
        ret     

