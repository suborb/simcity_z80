; NEC PC-6001mkII: the 320x200 mode of two bit planes, used as 40 x 25 cells of 8x8 pixels.
; Plane 0 is at $C000 and plane 1 at $E000 ($C1 = 0, $B0 = 2: VRAM at $C000, timer running; Takeda takes the VRAM base at the $B0 write, so $C1 goes first), 40 bytes a pixel row,
; 320 a cell row.  A pixel is a pen: its bit in plane 0 + 2 * its bit in plane 1; $C0 = 4 is the set green, yellow, blue, red (pens 0 to 3).
; A cell is a picture of one bit a pixel with an ink pen and a paper pen, one byte, ink in bits 0-1 and paper in bits 2-3 (tools/make_mk2_assets.py makes the art's attribute
; bytes so).  In each plane the ink and the paper are each a 0 or a 1, so the plane's eight bytes are one of four things: all 0 (both 0), all $FF (both 1), the art (ink 1, paper 0)
; or its complement (ink 0, paper 1): four routines (pl_zero, pl_ones, pl_copy, pl_comp), unrolled.
; A map cell that already shows the picture asked for is left alone: `cache` has a byte for each cell, the picture's number in the art table (its offset from _view_tile_art / 8,
; 0 to 254), or $FF if it shows something else (text, a bar, a cleared screen).  A picture that has no number (the cursor's inverse, the icons', the zone pieces from 255 on) is always drawn.
; The icons keep $F0 + their state in the cache entry of their first cell (plat_pc6001mk2.c).
        SECTION code_user
        PUBLIC  _pc_mode_bitmap
        PUBLIC  _plat_clear
        PUBLIC  _plat_text_clear
        PUBLIC  _plat_put
        PUBLIC  _plat_puts
        PUBLIC  _plat_text_puts
        PUBLIC  _plat_put_tile
        PUBLIC  _mk_cache
        PUBLIC  cptr
        PUBLIC  daddr
        EXTERN  _view_tile_art

        defc    PLANE0 = $c000
        defc    PLANE1 = $e000
        defc    TEXT_COLOUR = 1 | (2 << 2)      ; yellow on blue: plane 0 copies the glyph, plane 1 complements it
        defc    CELLS = 40 * 25

; void pc_mode_bitmap(void): the 320x200 mode, colour set 4
_pc_mode_bitmap:
        xor     a
        out     ($c1),a
        ld      a,4
        out     ($c0),a
        ld      a,2
        out     ($b0),a
        ret

; void plat_clear(void): both planes to the paper (blue: plane 0 0, plane 1 $FF), and nothing is remembered of the cells
_plat_clear:
_plat_text_clear:
        ld      hl,PLANE0
        ld      de,PLANE0+1
        ld      bc,7999
        ld      (hl),0
        ldir
        ld      hl,PLANE1
        ld      de,PLANE1+1
        ld      bc,7999
        ld      (hl),$ff
        ldir
        ld      hl,cache
        ld      de,cache+1
        ld      bc,CELLS - 1
        ld      (hl),$ff
        ldir
        ret

; cptr: b = column, c = row -> hl = the cell's entry in cache.  Keeps b and c; clobbers a, de.
cptr:   ld      h,0
        ld      l,c
        add     hl,hl
        add     hl,hl
        add     hl,hl                   ; 8 * row
        ld      d,h
        ld      e,l
        add     hl,hl
        add     hl,hl                   ; 32 * row
        add     hl,de                   ; 40 * row
        ld      e,b
        ld      d,0
        add     hl,de
        ld      de,cache
        add     hl,de
        ret

; daddr: b = column, c = row -> hl = the cell's address in plane 0: PLANE0 + 320 * row + column.  Keeps b and c; clobbers a, de.
daddr:  ld      h,0
        ld      l,c
        add     hl,hl
        add     hl,hl
        add     hl,hl
        add     hl,hl
        add     hl,hl
        add     hl,hl                   ; 64 * row
        ld      a,h
        add     a,c                     ; + 256 * row
        ld      h,a
        ld      a,l
        add     a,b
        ld      l,a
        jr      nc,da1
        inc     h
da1:    ld      de,PLANE0
        add     hl,de
        ret

; The four plane routines: hl = the cell's address in the plane, de = the art, bc = 40 (a pixel row)
pl_zero: xor    a
        jr      pl_fill
pl_ones: ld     a,$ff
pl_fill:
        REPT    7
        ld      (hl),a
        add     hl,bc
        ENDR
        ld      (hl),a
        ret
pl_copy:
        REPT    7
        ld      a,(de)
        inc     de
        ld      (hl),a
        add     hl,bc
        ENDR
        ld      a,(de)
        ld      (hl),a
        ret
pl_comp:
        REPT    7
        ld      a,(de)
        inc     de
        cpl
        ld      (hl),a
        add     hl,bc
        ENDR
        ld      a,(de)
        cpl
        ld      (hl),a
        ret

; plane: a = 0 zero, 1 ones, 2 copy, 3 complement
plane:  or      a
        jr      z,pl_zero
        dec     a
        jr      z,pl_ones
        dec     a
        jr      z,pl_copy
        jr      pl_comp

; cell: a = colour (ink | paper << 2), b = column, c = row, hl = the art (8 bytes).  Draws the cell.
cell:   push    af
        push    hl
        call    daddr
        pop     de                      ; the art
        pop     af                      ; the colour
        push    hl
        push    de
        ld      c,a
        rrca
        rrca
        and     3
        ld      b,a                     ; the paper
        ld      a,c
        and     3                       ; the ink
        xor     b
        ld      c,a                     ; ink xor paper
        and     1
        add     a,a
        ld      d,a
        ld      a,b
        and     1
        or      d
        ld      (ci0),a                 ; plane 0: 2 * (x bit 0) + (paper bit 0)
        ld      a,c
        and     2
        ld      d,a
        ld      a,b
        srl     a
        and     1
        or      d
        ld      (ci1),a                 ; plane 1: the same with the bits 1
        pop     de
        pop     hl
        push    hl
        push    de
        ld      bc,40
        ld      a,(ci0)
        call    plane
        pop     de
        pop     hl
        ld      a,h
        add     a,$20                   ; plane 1 is $2000 on
        ld      h,a
        ld      bc,40
        ld      a,(ci1)
        jr      plane

; void plat_put_tile(uint8_t col, uint8_t row, const uint8_t *art, uint8_t attr, uint8_t inverse) __smallc: the map's picture and its colour byte; inverse swaps ink and paper (the cursor)
_plat_put_tile:
        IFDEF   MK2_COUNT
        ld      hl,(ctr_tile)
        inc     hl
        ld      (ctr_tile),hl
        ENDIF
        push    ix
        ld      ix,0
        add     ix,sp
        ld      a,$ff                   ; the picture's number: $FF for none
        ld      l,(ix+4)                ; inverse
        inc     l
        dec     l
        jr      nz,pt_key
        ld      l,(ix+8)
        ld      h,(ix+9)                ; the art
        ld      de,_view_tile_art
        or      a
        sbc     hl,de
        jr      c,pt_key
        ld      a,h
        cp      8
        ld      a,$ff
        jr      nc,pt_key
        srl     h
        rr      l
        srl     h
        rr      l
        srl     h
        rr      l
        ld      a,l                     ; (255 is the no-picture value too)
pt_key: push    af
        ld      b,(ix+12)
        ld      c,(ix+10)
        call    cptr                    ; hl = the cell's entry
        pop     af
        inc     a
        jr      z,pt3                   ; no number: draw it
        dec     a
        cp      (hl)
        jr      z,pthit                 ; already there
        ld      (hl),a
        jr      pt4
pt3:    ld      (hl),$ff
pt4:        ld      a,(ix+4)
        or      a
        ld      a,(ix+6)                ; the colour byte
        jr      z,noinv
        ld      c,a                     ; swap ink and paper
        rlca
        rlca
        and     $0c
        ld      d,a
        ld      a,c
        rrca
        rrca
        and     $03
        or      d
noinv:  ld      l,(ix+8)
        ld      h,(ix+9)
        ld      b,(ix+12)
        ld      c,(ix+10)
        call    cell
pthit:  pop     ix
        ret

; glyph: a = the character, b = column, c = row: draws it in the text colours (plane 0 the glyph, plane 1 its complement)
glyph:
        IFDEF   MK2_COUNT
        ld      hl,(ctr_glyph)
        inc     hl
        ld      (ctr_glyph),hl
        ENDIF
        cp      32
        jr      nc,gtext
        or      a                       ; a line piece of the boxes' frames: codes 1 to 6
        jr      z,gblank
        cp      7
        jr      nc,gblank
        ld      l,a
        ld      h,0
        add     hl,hl
        add     hl,hl
        add     hl,hl
        ld      de,box - 8
        add     hl,de
        jr      gdraw
gtext:  sub     32
        cp      96
        jr      nc,gblank
        ld      l,a
        ld      h,0
        add     hl,hl
        add     hl,hl
        add     hl,hl
        ld      de,font
        add     hl,de
        jr      gdraw
gblank: ld      hl,blank
gdraw:  push    hl                      ; the glyph
        call    cptr
        ld      (hl),$ff                ; the cell shows text now
        call    daddr
        pop     de
        push    hl
        push    de
        ld      bc,40
        call    pl_copy
        pop     de
        pop     hl
        ld      a,h
        add     a,$20
        ld      h,a
        ld      bc,40
        jp      pl_comp

; void plat_put(uint8_t col, uint8_t row, uint8_t ch) __smallc
_plat_put:
        push    ix
        ld      ix,0
        add     ix,sp
        ld      a,(ix+4)
        ld      b,(ix+8)
        ld      c,(ix+6)
        call    glyph
        pop     ix
        ret

; void plat_puts(uint8_t col, uint8_t row, const char *s) __smallc: (the row and column are kept in memory)
_plat_puts:
_plat_text_puts:
        push    ix
        ld      ix,0
        add     ix,sp
        ld      l,(ix+4)
        ld      h,(ix+5)
        ld      a,(ix+6)
        ld      (prow),a
        ld      a,(ix+8)
        ld      (pcol),a
puts1:  ld      a,(hl)
        or      a
        jr      z,putsx
        inc     hl
        push    hl
        ld      e,a
        ld      a,(pcol)
        ld      b,a
        inc     a
        ld      (pcol),a
        ld      a,(prow)
        ld      c,a
        ld      a,e
        call    glyph
        pop     hl
        jr      puts1
putsx:  pop     ix
        ret

        SECTION rodata_user
; The line pieces of the boxes' frames, pipes two pixels thick with rounded corners: 1 top left, 2 top right, 3 bottom left, 4 bottom right, 5 across, 6 down
; (the codes of BOX_TOP, BOX_BOTTOM and BOX_SIDE in plat_config.h)
box:    defb    $00,$00,$00,$0F,$1F,$18,$18,$18
        defb    $00,$00,$00,$F0,$F8,$18,$18,$18
        defb    $18,$18,$18,$1F,$0F,$00,$00,$00
        defb    $18,$18,$18,$F8,$F0,$00,$00,$00
        defb    $00,$00,$00,$FF,$FF,$00,$00,$00
        defb    $18,$18,$18,$18,$18,$18,$18,$18
font:   BINARY  "assets/font_8x8_bbc_system.bin"
        PUBLIC  _mk_icons
_mk_icons:                              ; the 14 tool icons: 4 cells of 8 bytes each, then the 56 colour bytes (tools/make_mk2_assets.py)
        BINARY  "assets/icons_mk2.bin"
blank:  defs    8

        SECTION bss_user
ci0:    defb    0
ci1:    defb    0
pcol:   defb    0
psb:    defw    0
psn:    defb    0
prow:   defb    0
_mk_cache:
cache:  defs    CELLS
        IFDEF   MK2_COUNT
        PUBLIC  ctr_tile, ctr_glyph
ctr_tile:  defw 0
ctr_glyph: defw 0
        ENDIF
