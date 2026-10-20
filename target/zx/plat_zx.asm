; ZX Spectrum renderer and console font/UDG pointer access.
        SECTION code_clib
        PUBLIC  _plat_std_font
        PUBLIC  _plat_set_font
        PUBLIC  _plat_set_udgs
        EXTERN  __zx_32col_font
        EXTERN  __zx_32col_udgs
_plat_std_font:
        ld      hl,(__zx_32col_font)
        ret
_plat_set_font:
        ld      (__zx_32col_font),hl
        ret
_plat_set_udgs:
        ld      (__zx_32col_udgs),hl
        ret

; void zx_blit8(uint8_t *screen, const uint8_t *art, uint8_t inverse) __smallc
; Copy an 8x8 picture directly to a Spectrum cell; rows are 256 bytes apart.
        PUBLIC  _zx_blit8
        PUBLIC  _zx_blit8_callee
_zx_blit8:
        pop     af
        pop     bc
        pop     hl
        pop     de
        push    de
        push    hl
        push    bc
        push    af
_zx_blit8_callee:
        ld      a,c
        neg
        sbc     a,a
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
