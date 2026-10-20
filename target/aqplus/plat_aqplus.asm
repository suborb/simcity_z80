; Aquarius+ bitmap renderer and direct character output.
        EXTERN  generic_console_printc

; The 14 tool icons, four 8x8 cells each (tools/make_z88_icons.py writes assets/icons.bin).
        SECTION rodata_user
        PUBLIC  _aq_icons
_aq_icons:
        BINARY  "assets/icons.bin"

        SECTION code_clib
; void aq_blit8(uint8_t col, uint8_t row, const uint8_t *art, uint8_t colour, uint8_t inverse) __smallc
; Video RAM is paged into bank 3 only while storing: the engine's buffers live there too.
        EXTERN  __aquarius_video_base
        EXTERN  CLIB_VIDEO_PAGE_PORT
        PUBLIC  _aq_blit8
_aq_blit8:
        in      a,(CLIB_VIDEO_PAGE_PORT)
        push    af
        ld      a,20
        out     (CLIB_VIDEO_PAGE_PORT),a
        ld      hl,4
        add     hl,sp
        ld      a,(hl)
        add     a,255
        sbc     a,a
        ld      c,a
        inc     hl
        inc     hl
        ld      a,(hl)
        ex      af,af'
        inc     hl
        inc     hl
        ld      e,(hl)
        inc     hl
        ld      d,(hl)
        inc     hl
        ld      a,(hl)
        inc     hl
        inc     hl
        ld      b,(hl)
        push    de
        ld      l,a
        ld      h,0
        add     hl,hl
        add     hl,hl
        add     hl,hl
        ld      d,h
        ld      e,l
        add     hl,hl
        add     hl,hl
        add     hl,de
        push    hl
        ld      e,b
        ld      d,0
        add     hl,de
        ld      de,(__aquarius_video_base)
        add     hl,de
        ld      a,h
        add     a,$20
        ld      h,a
        ex      af,af'
        ld      (hl),a
        pop     hl
        add     hl,hl
        add     hl,hl
        add     hl,hl
        ld      e,b
        ld      d,0
        add     hl,de
        ld      de,(__aquarius_video_base)
        add     hl,de
        pop     de
        ld      a,c
        or      a
        ld      bc,40
        jr      nz,aq_blit_inv
        REPT    7
        ld      a,(de)
        ld      (hl),a
        inc     de
        add     hl,bc
        ENDR
        ld      a,(de)
        ld      (hl),a
        jr      aq_blit_end
aq_blit_inv:
        REPT    7
        ld      a,(de)
        cpl
        ld      (hl),a
        inc     de
        add     hl,bc
        ENDR
        ld      a,(de)
        cpl
        ld      (hl),a
aq_blit_end:
        pop     af
        out     (CLIB_VIDEO_PAGE_PORT),a
        ret

; void plat_aq_printc(uint8_t col, uint8_t row, uint8_t ch) __smallc
; Draw without moving the console cursor or allowing it to scroll.
        PUBLIC  _plat_aq_printc
_plat_aq_printc:
        ld      hl,2
        add     hl,sp
        ld      d,(hl)
        inc     hl
        inc     hl
        ld      b,(hl)
        inc     hl
        inc     hl
        ld      c,(hl)
        ld      e,0
        jp      generic_console_printc
