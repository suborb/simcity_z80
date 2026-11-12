; Sharp MZ-800: 320x200 in two bit planes, used as 40 x 25 cells of 8x8 pixels.
; The video RAM is paged in at $8000-$9FFF (IN ($E0); IN ($E1) takes it out) only while drawing, so this code is below $8000 and reads nothing above it meanwhile: the art and
; font are copied to abuf first, bit reversed (a byte's leftmost pixel is its bit 0; the art has it in bit 7).  Both planes are at the same addresses: the write format ($CC)
; picks one.  A pixel is a pen (plane I bit + 2 * plane II bit); pens 0-3 are green, yellow, blue, red, as on the PC-6001mkII, whose art this uses.
; A cell is an ink pen (bits 0-1) and a paper pen (bits 2-3) over a 1 bit picture, so in each plane its 8 bytes are all 0, all $FF, the picture or its complement: pl_zero,
; pl_ones, pl_copy, pl_comp.
; `cache` has a byte per map cell: the number of the picture it shows (offset in the art table / 8), or $FF for anything else; a cell that already shows the picture is left alone.
; The icons keep $F0 + their state in their first cell's entry (plat_mz800.c).
        SECTION code_driver
        PUBLIC  _mz_mode_bitmap
        PUBLIC  _plat_clear
        PUBLIC  _plat_text_clear
        PUBLIC  _plat_put
        PUBLIC  _plat_puts
        PUBLIC  _plat_text_puts
        PUBLIC  _plat_put_tile
        PUBLIC  _mz_cache
        PUBLIC  cptr
        PUBLIC  daddr
        PUBLIC  abuf
        PUBLIC  copy8rev
        EXTERN  _view_tile_art

        defc    PLANE0 = $8000
                defc    CELLS = 40 * 25

; void mz_mode_bitmap(void): RAM in at $0000 and $E000, the 320x200 4 colour mode with the video RAM paged in, the palette (pens 0 to 3: green, yellow, blue, red; the bright
; ones of the IGRB colours: 1 blue, 2 red, 4 green, 8 bright)
_mz_mode_bitmap:
        call    rev_init
        out     ($e0),a                 ; RAM at $0000-$0FFF
        out     ($e1),a                 ; RAM at $E000-$FFFF
        xor     a
        out     ($ce),a                 ; 320x200 4 colours, planes I and II
        ld      hl,pens
        ld      b,4
mb1:    ld      a,(hl)
        out     ($f0),a
        inc     hl
        djnz    mb1
        in      a,($e1)                 ; (the video RAM is out of the map between draws)
        IFDEF   HAVE_SOUND
        EXTERN  mz_time_init
        jp      mz_time_init            ; (the sound's clock)
        ELSE
        ret
        ENDIF
; the bit reversal table
rev_init:
        ld      hl,revtab
        ld      c,0
ri1:    ld      a,c
        ld      e,0
        ld      b,8
ri2:    rra
        rl      e
        djnz    ri2
        ld      (hl),e
        inc     hl
        inc     c
        jr      nz,ri1
        ret

; copy8rev: hl = 8 bytes of art -> abuf, each bit reversed.  Clobbers a, b, de, hl.
copy8rev:
        ld      de,abuf
        ld      b,8
cr1:    ld      a,(hl)
        inc     hl
        push    hl
        ld      hl,revtab
        add     a,l
        ld      l,a
        jr      nc,cr2
        inc     h
cr2:    ld      a,(hl)
        pop     hl
        ld      (de),a
        inc     de
        djnz    cr1
        ret
pens:   defb    $0c, $1e, $29, $3a      ; (index << 4) | colour: green $0C, yellow $0E, blue $09, red $0A

; void plat_clear(void): both planes to the paper (blue, pen 2: plane I 0, plane II $FF: one replace write: the planes of the format get the data, the others 0), and nothing is
; remembered of the cells
_plat_clear:
_plat_text_clear:
        in      a,($e0)
        ld      a,$82
        out     ($cc),a
        ld      a,2
        out     ($cd),a                 ; (the LDIR reads plane II, which has the $FF it copies on)
        ld      hl,PLANE0
        ld      de,PLANE0+1
        ld      bc,7999
        ld      (hl),$ff
        ldir
        in      a,($e1)
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
        push    bc
        call    copy8rev                ; the art, where the video RAM being paged in does not hide it, bit reversed
        pop     bc
        call    daddr
        pop     af                      ; the colour
        push    hl
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
        ld      (ci0),a                 ; plane I: 2 * (x bit 0) + (paper bit 0)
        ld      a,c
        and     2
        ld      d,a
        ld      a,b
        srl     a
        and     1
        or      d
        ld      (ci1),a                 ; plane II: the same with the bits 1
        pop     hl
        in      a,($e0)                 ; the video RAM in
        push    hl
        ld      de,abuf
        ld      bc,40
        ld      a,$01                   ; plane I
        out     ($cc),a
        ld      a,(ci0)
        call    plane
        pop     hl
        ld      de,abuf
        ld      bc,40
        ld      a,$02                   ; plane II
        out     ($cc),a
        ld      a,(ci1)
        call    plane
        in      a,($e1)
        ret

; void plat_put_tile(uint8_t col, uint8_t row, const uint8_t *art, uint8_t attr, uint8_t inverse) __smallc: the map's picture and its colour byte; inverse swaps ink and paper (the cursor)
_plat_put_tile:
        IFDEF   MZ_COUNT
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
        IFDEF   HAVE_SOUND
        EXTERN  ay_poll
        jp      ay_poll                 ; (the sound's ticks go on while the map is drawn)
        ELSE
        ret
        ENDIF

; glyph: a = the character, b = column, c = row: draws it in the text colours (plane I the glyph, plane II its complement)
glyph:
        IFDEF   MZ_COUNT
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
        ex      de,hl
        call    copy8rev                ; (the glyph copied, as for a cell)
        pop     hl
        in      a,($e0)
        push    hl
        ld      de,abuf
        ld      bc,40
        ld      a,$01
        out     ($cc),a
        call    pl_copy
        pop     hl
        ld      de,abuf
        ld      bc,40
        ld      a,$02
        out     ($cc),a
        call    pl_comp
        in      a,($e1)
        ret

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
        PUBLIC  _mz_icons
_mz_icons:                              ; the 14 tool icons: 4 cells of 8 bytes each, then the 56 colour bytes (tools/make_mk2_assets.py)
        BINARY  "assets/icons_mk2.bin"
blank:  defs    8

        SECTION bss_user
abuf:   defs    8
revtab: defs    256
ci0:    defb    0
ci1:    defb    0
pcol:   defb    0
psb:    defw    0
psn:    defb    0
prow:   defb    0
_mz_cache:
cache:  defs    CELLS
        IFDEF   MZ_COUNT
        PUBLIC  ctr_tile, ctr_glyph
ctr_tile:  defw 0
ctr_glyph: defw 0
        ENDIF
