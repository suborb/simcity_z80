; The sprite placer (HAVE_SPRITE_OVERLAY), in the game overlay with ui/sprites.c: the sprites are only drawn while the city is shown.  cptr and daddr are the placer's (plat_pc6001mk2.asm).
        SECTION OVERLAY_0
        PUBLIC  _plat_put_overlay
        EXTERN  cptr
        EXTERN  daddr
; void plat_put_overlay(uint8_t col, uint8_t row, const uint8_t *art) __smallc: the pixels set in the art (a sprite) go red (pen 3: both planes) over what the cell shows, which the
; cache then forgets
_plat_put_overlay:
        ld      hl,2
        add     hl,sp
        ld      e,(hl)
        inc     hl
        ld      d,(hl)                  ; the art
        inc     hl
        ld      c,(hl)                  ; the row
        inc     hl
        inc     hl
        ld      b,(hl)                  ; the column
        push    de
        call    cptr
        ld      (hl),$ff
        call    daddr
        pop     de
        ld      b,8
po_l:   ld      a,(de)
        inc     de
        ld      c,a
        or      (hl)
        ld      (hl),a
        ld      a,h
        add     a,$20
        ld      h,a
        ld      a,c
        or      (hl)
        ld      (hl),a
        ld      a,h
        sub     $20
        ld      h,a
        push    de
        ld      de,40
        add     hl,de
        pop     de
        djnz    po_l
        ret
