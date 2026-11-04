; BDOS console output and nonblocking input.
        SECTION code_user
        PUBLIC  _cpm_conout, _cpm_conin

; void cpm_conout(uint8_t c) __z88dk_fastcall: BDOS 6, E = c
_cpm_conout:
        push    ix
        push    iy
        ld      e,l
        ld      c,6
        call    5
        pop     iy
        pop     ix
        ret

; uint8_t cpm_conin(void): BDOS 6, E = FF: the key, or 0
_cpm_conin:
        push    ix
        push    iy
        ld      c,6
        ld      e,$FF
        call    5
        ld      l,a
        ld      h,0
        pop     iy
        pop     ix
        ret

        PUBLIC  _cpm_print
; void cpm_print(const char *s) __z88dk_fastcall: BDOS 9, a '$' terminated string
_cpm_print:
        push    ix
        push    iy
        ex      de,hl
        ld      c,9
        call    5
        pop     iy
        pop     ix
        ret

        PUBLIC  _cpm_version
; uint8_t cpm_version(void): BDOS 12, the version: $22 for CP/M 2.2, $30 and up for CP/M Plus (and what is compatible: Z80DOS, DOS+)
_cpm_version:
        push    ix
        push    iy
        ld      c,12
        call    5
        ld      l,a
        ld      h,0
        pop     iy
        pop     ix
        ret

        PUBLIC  _cpm_seconds
; uint8_t cpm_seconds(void): BDOS 105, the time of day: the seconds (BCD) it returns in A
_cpm_seconds:
        push    ix
        push    iy
        ld      de,time_buffer
        ld      c,105
        call    5
        ld      l,a
        ld      h,0
        pop     iy
        pop     ix
        ret

        SECTION bss_user
time_buffer:    defs    4                       ; (the days, hours and minutes)
