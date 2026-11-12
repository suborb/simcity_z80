; The sprite placer (HAVE_SPRITE_OVERLAY): sprites are drawn only while the city shows.  cptr and daddr are plat_mz800.asm's.
        SECTION code_driver
        PUBLIC  _plat_put_overlay
        EXTERN  cptr
        EXTERN  daddr
        EXTERN  abuf
        EXTERN  copy8rev
; void plat_put_overlay(uint8_t col, uint8_t row, const uint8_t *art) __smallc: the art's set pixels go red (pen 3) over the cell, which the cache then forgets.
; One OR-format write ($CC = $43) sets the bits in both planes.
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
        push    bc
        ex      de,hl
        call    copy8rev                ; the art, where the video RAM being paged in does not hide it, bit reversed
        pop     bc
        call    cptr
        ld      (hl),$ff
        call    daddr
        ld      de,abuf
        in      a,($e0)                 ; the video RAM in
        ld      a,$43
        out     ($cc),a                 ; OR into planes I and II
        ld      c,8
po_l:   ld      a,(de)
        inc     de
        ld      (hl),a
        push    de
        ld      de,40
        add     hl,de
        pop     de
        dec     c
        jr      nz,po_l
        in      a,($e1)
        ret
