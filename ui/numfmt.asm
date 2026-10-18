; 24 bit binary to packed decimal, without a division: shift the value left into a BCD number a bit
; at a time (DAA keeps the BCD digits right).  About 40 bytes, against 170 for the C library's 32 bit
; divide and modulo that printing a number with /10 and %10 pulls in.
;
;     void bcd24(uint8_t *p) __z88dk_fastcall
;
; p[0..2] is the value, little endian; on return p[3..6] hold its 8 decimal digits, two to a byte,
; p[6] the most significant.
        SECTION code_compiler
        PUBLIC  _bcd24

_bcd24:
        ld      e,(hl)
        inc     hl
        ld      d,(hl)
        inc     hl
        ld      c,(hl)                  ;c:d:e = the value
        inc     hl                      ;hl -> the digits, cleared
        xor     a
        ld      (hl),a
        inc     hl
        ld      (hl),a
        inc     hl
        ld      (hl),a
        inc     hl
        ld      (hl),a
        dec     hl
        dec     hl
        dec     hl                      ;back to the first digit byte
        ld      b,24
bcd24_bit:
        sla     e                       ;the value's top bit goes into the carry...
        rl      d
        rl      c
        push    hl
        ld      a,(hl)                  ;...and into the digits, doubling them: a = a + a + carry
        adc     a,a
        daa
        ld      (hl),a
        inc     hl
        ld      a,(hl)
        adc     a,a
        daa
        ld      (hl),a
        inc     hl
        ld      a,(hl)
        adc     a,a
        daa
        ld      (hl),a
        inc     hl
        ld      a,(hl)
        adc     a,a
        daa
        ld      (hl),a
        pop     hl
        djnz    bcd24_bit
        ret
