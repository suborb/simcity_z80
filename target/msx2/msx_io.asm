; The MSX's own routines: the keyboard matrix (the PPI), the PSG's joystick connector lines and a DOS 2 console string.  (The V9938's are
; target/common/v9938/plat_v9938.asm.)
        MODULE  msx_io
        SECTION code_user

; uint8_t msx_keyrow(uint8_t row) __smallc
; The keyboard matrix row (0 to 10) from the PPI: a bit is 0 for a key that is down.
        PUBLIC  _msx_keyrow
_msx_keyrow:
        ld      hl,2
        add     hl,sp
        ld      c,(hl)
        di
        in      a,($AA)
        and     $F0
        or      c
        out     ($AA),a
        in      a,($A9)
        ei
        ld      l,a
        ld      h,0
        ret

; void v9938_fatal(const char *s) __smallc
; The V9938 platform's fatal error (target/common/v9938/plat_v9938.c: the atlas is missing): the string, ended by a $, on the console (DOS function 9), then back to DOS.
        PUBLIC  _v9938_fatal
        EXTERN  _msx_bye
_v9938_fatal:
        ld      hl,2
        add     hl,sp
        ld      e,(hl)
        inc     hl
        ld      d,(hl)
        ld      c,9
        call    5
        jp      _msx_bye                ; (does not come back)

; void msx_getc(void): DOS function 1, a key from the console
        PUBLIC  _msx_getc
_msx_getc:
        push    ix
        push    iy
        ld      c,1
        call    5
        pop     iy
        pop     ix
        ret

; void msx_psg15(uint8_t value) __smallc
; PSG register 15 (the joystick connectors' output: the mouse's strobe and the connector select): the BIOS leaves it at $CF.
        PUBLIC  _msx_psg15
_msx_psg15:
        ld      hl,2
        add     hl,sp
        ld      c,(hl)
        di
        ld      a,15
        out     ($A0),a
        ld      a,c
        out     ($A1),a
        ei
        ret
