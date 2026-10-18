; Fast tile blit for the ZX Spectrum screen.
;
;     void zx_blit8(uint8_t *screen, const uint8_t *art, uint8_t inverse) __smallc
;
; Copies 8 bytes of art to the 8 pixel rows of a character cell; 'screen' is the
; address of the cell's top row (zx_cxy2saddr) and the rows are 256 bytes apart.
; With inverse non-zero the pixels are inverted.  About 300 T-states, against
; about 7000 for printing the same cell through the console.

        SECTION code_clib
        PUBLIC  _zx_blit8
        PUBLIC  _zx_blit8_callee

_zx_blit8:
        pop     af                      ;return address
        pop     bc                      ;inverse (c)
        pop     hl                      ;art
        pop     de                      ;screen
        push    de
        push    hl
        push    bc
        push    af
_zx_blit8_callee:
        ld      a,c
        neg                             ;a = 0 or non-zero
        sbc     a,a                     ;a = $00 normal, $FF inverse
        ld      c,a
        ld      b,8
zx_blit8_loop:
        ld      a,(hl)
        xor     c
        ld      (de),a
        inc     hl
        inc     d
        djnz    zx_blit8_loop
        ret
