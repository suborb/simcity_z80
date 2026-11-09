; Camputers Lynx 128K platform (z88dk +lynx, the program at $0100 in the user RAM, nothing of the BASIC or the DOS used): the game draws pictures
; and text itself.
;
; The screen is three one bit planes (red, blue and green) of 64 bytes to a pixel row, 512 pixels across and 252 rows, which the 6845 shows
; from offset $100 of each plane (the first 4 rows of a plane are not shown): a pixel row y is at $100 + 64 * y, and the planes are at the CPU
; addresses $0000 (red), $4000 (blue) and $8000 (green), in the same addresses as the user RAM.  The hardware pixels are about one and a half
; times as tall as they are wide, so the game's 8x8 cells are drawn with every pixel doubled across and two of the eight rows drawn twice
; (rows 2 and 5): a cell is 16x10 hardware pixels, two bytes by ten rows, nearly square, and the screen is 32 columns by 25 rows.  A cell's
; first byte in the red plane is
;     $100 + row * 640 + col * 2          and the rest of its pixel rows are 64 bytes apart, the blue and green planes $4000 and $8000 on.
;
; Port $82 chooses which memory the CPU reads and writes.  $08 is the normal state: the user RAM is read and written.  $C8 is the drawing
; window: the user RAM is read as before but the stores go only to the video planes, so the cell's 48 bytes (red, blue and green, 16 each)
; are copied to the three planes.  In the window the stack is not usable (a push goes to the planes and the return address would be read
; from the user RAM): the window's code has no CALL, PUSH or RET, and interrupts are off.  The planes cannot be read at all (reading a
; plane means running from it), so the text of the screen is kept in mp_shadow, for plat_text_attr, and a sprite is drawn over its cell's
; picture again, which the map cell cache knows.
;
; The interrupt (IM 1, the 6845's VSYNC) is held for a few scan lines: the handler counts a frame and returns with interrupts still off, and
; plat_idle turns them on only to wait (EI, HALT), so that a frame is counted once.
;
; The keyboard is a matrix of ten lines: IN A,(C) with BC = $0n80 gives line n, a pressed key a 0 bit.
;
; Arguments are the game's C calling convention (smallc).  A cell's attribute is the Spectrum's: ink in bits 0-2 (blue 1, red 2, green 4),
; paper in bits 3-5.  A plane's byte for a row g of the glyph is (g AND (ink XOR paper)) XOR paper, each of those a bit of the attribute
; made into a mask.

        SECTION code_user
        EXTERN  _view_tile_art          ; picture n is at 8 * n from it

        defc    PORT_BANK = $82
        defc    NORMAL = $08
        defc    DRAW = $C8
        defc    ATLAS = $C000           ; the map's pictures, 24 bytes each, in the alternate green plane: read with VCOPY (tools/lynx_art.py)
        defc    FONT = ATLAS + 8280     ; the 96 glyphs, 8 bytes each
        defc    ICONS = FONT + 768      ; the tool icons: four cells of 16 bytes each
        defc    VCOPY = $FC00           ; the stub in the RAM here and the plane: hl = a video RAM address, de = where in the RAM, bc = the count
        defc    DBL = $F800             ; 512 bytes: the doubled high nibble of a byte, then the low
        defc    DBL_HI = DBL / 256
        defc    TEXT_ATTR = 7           ; white on black
        defc    MAP_ROW = 6             ; the map's cell rows: the only ones with a cache entry
        defc    MAP_ROWS = 19
        defc    SHADOW_ROWS = 24        ; the rows of text that mp_shadow remembers
        defc    SHADOW_SIZE = 32 * SHADOW_ROWS

        SECTION rodata_user
; a nibble doubled across into a byte (each pixel twice)
mp_dn:
        defb    $00,$03,$0C,$0F,$30,$33,$3C,$3F,$C0,$C3,$CC,$CF,$F0,$F3,$FC,$FF

; The 6845's registers (those of the Lynx 128K's BASIC): 64 characters wide, 63 rows of 4 lines, the display starting at $0040 characters
mp_crtc:
        defb    $5F,$40,$4C,$37,$46,$1C,$3F,$44,$00,$03,$03,$03,$00,$40,$0F,$FF

; The mini map's nibbles: six tables (red, blue and green, a plane's two lines each) indexed by the colour (bit 0 blue, 1 red, 2 green, 3 dim)
mm_nib:
        defb    $0,$0,$F,$F,$0,$0,$F,$F,$0,$0,$A,$A,$0,$0,$A,$A
        defb    $0,$0,$F,$F,$0,$0,$F,$F,$0,$0,$5,$5,$0,$0,$5,$5
        defb    $0,$F,$0,$F,$0,$F,$0,$F,$0,$A,$0,$A,$0,$A,$0,$A
        defb    $0,$F,$0,$F,$0,$F,$0,$F,$0,$5,$0,$5,$0,$5,$0,$5
        defb    $0,$0,$0,$0,$F,$F,$F,$F,$0,$0,$0,$0,$A,$A,$A,$A
        defb    $0,$0,$0,$0,$F,$F,$F,$F,$0,$0,$0,$0,$5,$5,$5,$5

; The keys: line n bit b is mp_keys[8 * n + b], the game's key codes (the cursor keys are 8 left, 9 right, 10 down and 11 up, and 28 to 31
; with the shift key: eight cells), 0 for no key
mp_keys:
        defb    '1',0,0,0,11,10,27,0            ; line 0: ... up, down, escape, shift
        defb    '3','4','e','x','d','c',0,0
        defb    '2','q','w','z','s','a',0,0     ; (line 2 bit 6 is control)
        defb    '5','r','t','v','g','f',0,0
        defb    '6','y','h',' ','n','b',0,0
        defb    '7','8','u','m',0,'j',0,0
        defb    '9','i','o',',',0,'k',0,0
        defb    '0','p','l','.',0,';',0,0
        defb    '-','@','[','/',0,':',0,0
        defb    8,']',8,13,0,9,0,0              ; line 9: delete, ], left, return, (end), right

        SECTION code_user

; a = row, b = col: hl and mp_scr = the cell's offset in the red plane, $100 + row * 640 + col * 2.  Uses a, de, hl.
mp_scraddr:
        ld      l,a
        ld      h,0
        ld      e,l
        ld      d,h
        add     hl,hl
        add     hl,hl
        add     hl,de                   ; row * 5 (under 128)
        ld      a,l
        srl     a
        ld      h,a
        ld      a,0
        rra                             ; the bit shifted out is the 128s
        ld      l,a                     ; hl = row * 5 * 128
        ld      de,$0100
        add     hl,de
        ld      a,b
        add     a,a
        ld      e,a
        ld      d,0
        add     hl,de
        ld      (mp_scr),hl
        ret

; hl = 8 bytes: de gets them doubled across (16 bytes); hl and de go on.  Uses a, b, c.
mp_dbl8:
        ld      b,8
mp_dbl_lp:
        ld      c,(hl)
        inc     hl
        push    hl
        ld      l,c
        ld      h,DBL_HI
        ld      a,(hl)                  ; the high nibble doubled: the left byte
        ld      (de),a
        inc     de
        inc     h
        ld      a,(hl)                  ; the low nibble: the right byte
        ld      (de),a
        inc     de
        pop     hl
        djnz    mp_dbl_lp
        ret

; The 48 bytes of mp_pix to the three planes at the cell mp_scr (red, blue and green, eight rows of two bytes each, rows 2 and 5 twice: ten rows).
; The drawing window: the code between the two OUTs has no stack.
mp_draw:
        ld      hl,mp_pix
        ld      de,(mp_scr)
        ld      bc,$0100                ; (LDI's count, which never runs out here)
        ld      a,DRAW
        out     (PORT_BANK),a
        ldi
        ldi
        ld      a,e
        add     a,62
        ld      e,a
        jr      nc,$ + 3
        inc     d
        ldi
        ldi
        ld      a,e
        add     a,62
        ld      e,a
        jr      nc,$ + 3
        inc     d
        ldi
        ldi
        ld      a,e
        add     a,62
        ld      e,a
        jr      nc,$ + 3
        inc     d
        dec     hl
        dec     hl
        ldi
        ldi
        ld      a,e
        add     a,62
        ld      e,a
        jr      nc,$ + 3
        inc     d
        ldi
        ldi
        ld      a,e
        add     a,62
        ld      e,a
        jr      nc,$ + 3
        inc     d
        ldi
        ldi
        ld      a,e
        add     a,62
        ld      e,a
        jr      nc,$ + 3
        inc     d
        ldi
        ldi
        ld      a,e
        add     a,62
        ld      e,a
        jr      nc,$ + 3
        inc     d
        dec     hl
        dec     hl
        ldi
        ldi
        ld      a,e
        add     a,62
        ld      e,a
        jr      nc,$ + 3
        inc     d
        ldi
        ldi
        ld      a,e
        add     a,62
        ld      e,a
        jr      nc,$ + 3
        inc     d
        ldi
        ldi
        ld      a,e
        add     a,62
        ld      e,a
        jr      nc,$ + 3
        inc     d
        ld      de,(mp_scr)
        ld      a,d
        add     a,$40
        ld      d,a
        ldi
        ldi
        ld      a,e
        add     a,62
        ld      e,a
        jr      nc,$ + 3
        inc     d
        ldi
        ldi
        ld      a,e
        add     a,62
        ld      e,a
        jr      nc,$ + 3
        inc     d
        ldi
        ldi
        ld      a,e
        add     a,62
        ld      e,a
        jr      nc,$ + 3
        inc     d
        dec     hl
        dec     hl
        ldi
        ldi
        ld      a,e
        add     a,62
        ld      e,a
        jr      nc,$ + 3
        inc     d
        ldi
        ldi
        ld      a,e
        add     a,62
        ld      e,a
        jr      nc,$ + 3
        inc     d
        ldi
        ldi
        ld      a,e
        add     a,62
        ld      e,a
        jr      nc,$ + 3
        inc     d
        ldi
        ldi
        ld      a,e
        add     a,62
        ld      e,a
        jr      nc,$ + 3
        inc     d
        dec     hl
        dec     hl
        ldi
        ldi
        ld      a,e
        add     a,62
        ld      e,a
        jr      nc,$ + 3
        inc     d
        ldi
        ldi
        ld      a,e
        add     a,62
        ld      e,a
        jr      nc,$ + 3
        inc     d
        ldi
        ldi
        ld      a,e
        add     a,62
        ld      e,a
        jr      nc,$ + 3
        inc     d
        ld      de,(mp_scr)
        ld      a,d
        add     a,$80
        ld      d,a
        ldi
        ldi
        ld      a,e
        add     a,62
        ld      e,a
        jr      nc,$ + 3
        inc     d
        ldi
        ldi
        ld      a,e
        add     a,62
        ld      e,a
        jr      nc,$ + 3
        inc     d
        ldi
        ldi
        ld      a,e
        add     a,62
        ld      e,a
        jr      nc,$ + 3
        inc     d
        dec     hl
        dec     hl
        ldi
        ldi
        ld      a,e
        add     a,62
        ld      e,a
        jr      nc,$ + 3
        inc     d
        ldi
        ldi
        ld      a,e
        add     a,62
        ld      e,a
        jr      nc,$ + 3
        inc     d
        ldi
        ldi
        ld      a,e
        add     a,62
        ld      e,a
        jr      nc,$ + 3
        inc     d
        ldi
        ldi
        ld      a,e
        add     a,62
        ld      e,a
        jr      nc,$ + 3
        inc     d
        dec     hl
        dec     hl
        ldi
        ldi
        ld      a,e
        add     a,62
        ld      e,a
        jr      nc,$ + 3
        inc     d
        ldi
        ldi
        ld      a,e
        add     a,62
        ld      e,a
        jr      nc,$ + 3
        inc     d
        ldi
        ldi
        ld      a,e
        add     a,62
        ld      e,a
        jr      nc,$ + 3
        inc     d
        ld      a,NORMAL
        out     (PORT_BANK),a
        ret

; de = a picture: 24 bytes, a plane (blue, red, green) of eight rows after another.  mp_pix gets it doubled across: red, blue, green, 16 bytes each.
mp_bake:
        ld      (mp_bs),de
        ld      hl,8
        add     hl,de
        ld      de,mp_pix
        call    mp_dbl8                 ; red
        ld      hl,(mp_bs)
        call    mp_dbl8                 ; blue
        ld      hl,(mp_bs)
        ld      bc,16
        add     hl,bc
        jp      mp_dbl8                 ; green

; mp_pix = its complement
mp_cpl_pix:
        ld      hl,mp_pix
        ld      b,48
mp_cpl_lp:
        ld      a,(hl)
        cpl
        ld      (hl),a
        inc     hl
        djnz    mp_cpl_lp
        ret

; void plat_put_tile(uint8_t col, uint8_t row, const uint8_t *art, uint8_t attr, uint8_t inverse) __smallc
; A map picture: art is _view_tile_art + 8 * n, drawn from mp_tiles (24 bytes a picture).  The attribute is not used; `inverse` draws the
; complement (the cursor).
        PUBLIC  _plat_put_tile
_plat_put_tile:
        ld      hl,2
        add     hl,sp
        ld      c,(hl)                  ; inverse (0 or 1)
        inc     hl
        inc     hl
        inc     hl
        inc     hl                      ; (past the attribute)
        ld      e,(hl)
        inc     hl
        ld      d,(hl)
        inc     hl
        ld      a,(hl)
        inc     hl
        inc     hl
        ld      b,(hl)
        call    mp_cached
        ret     c
        call    mp_noshadow             ; (a picture over any text there was)
        ; a = row, b = col, c = inverse, de = art
        push    af
        push    bc
        ex      de,hl
        ld      de,_view_tile_art
        or      a
        sbc     hl,de                   ; 8 * n
        ld      d,h
        ld      e,l
        add     hl,hl
        add     hl,de                   ; 24 * n
        ld      de,ATLAS
        add     hl,de
        ld      de,mp_t24
        ld      bc,24
        call    VCOPY                   ; the picture out of the plane
        ld      de,mp_t24
        call    mp_bake
        pop     bc
        pop     af
mp_pl_go:
        bit     0,c
        jr      z,mp_pl_draw
        push    af
        push    bc                      ; (mp_cpl_pix counts with b)
        call    mp_cpl_pix
        pop     bc
        pop     af
mp_pl_draw:
        call    mp_scraddr
        jp      mp_draw

; void mp_planar(uint8_t col, uint8_t row, const uint8_t *planes, uint8_t inverse) __smallc
; A cell from 24 bytes: a plane (blue, red, green) of eight rows after another (the complement if `inverse`).  Not cached: the icons are
; not in the map.
        PUBLIC  _mp_planar
_mp_planar:
        ld      hl,2
        add     hl,sp
        ld      c,(hl)                  ; inverse (0 or 1)
        inc     hl
        inc     hl
        ld      e,(hl)
        inc     hl
        ld      d,(hl)                  ; de = the planes
        inc     hl
        ld      a,(hl)                  ; row
        inc     hl
        inc     hl
        ld      b,(hl)                  ; col
        push    af
        push    bc
        call    mp_bake
        pop     bc
        pop     af
        jr      mp_pl_go

; void mp_tile1(uint8_t col, uint8_t row, const uint8_t *art, uint8_t attr, uint8_t inverse) __smallc
; 8 bytes of art in the colours of attr (swapped if `inverse`): the icons, the bars.
        PUBLIC  _mp_tile1
_mp_tile1:
        ld      hl,2
        add     hl,sp
        ld      a,(hl)
        inc     hl
        inc     hl
        ld      c,(hl)
        or      a
        call    nz,mp_swap
        ld      a,c
        and     $3F                     ; the colours
        ld      c,a
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
        call    mp_forget
        call    mp_noshadow
        jp      mp_cell_nc

; A map cell that already shows this picture is left alone: mp_cache has a word for each cell of the map, its art address xor the inverse
; flag (art addresses differ by 8 or more), or $FFFF if it shows something else.  a = row, b = col, c = inverse, de = art.  Carry if it is
; as wanted; else the entry is updated.  Keeps a, b, c, de.
mp_cached:
        push    af
        push    de
        call    mp_entry
        jr      c,mp_nocache
        ld      a,e
        xor     c
        ld      e,a                     ; de = the word
        ld      a,(hl)
        cp      e
        jr      nz,mp_miss
        inc     hl
        ld      a,(hl)
        cp      d
        jr      nz,mp_miss1
        pop     de
        pop     af
        scf
        ret
mp_miss:
        ld      (hl),e
        inc     hl
mp_miss1:
        ld      (hl),d
mp_nocache:
        pop     de
        pop     af
        or      a
        ret

; hl = the cache entry of cell a = row, b = column; carry if the cell is not in the map.  Keeps a, b, c, de.
mp_entry:
        push    af
        push    de
        sub     MAP_ROW
        jr      c,mp_outside
        cp      MAP_ROWS
        jr      nc,mp_outside
        ld      l,a
        ld      h,0
        add     hl,hl
        add     hl,hl
        add     hl,hl
        add     hl,hl
        add     hl,hl                   ; row * 32
        ld      e,b
        ld      d,0
        add     hl,de
        add     hl,hl                   ; * 2
        ld      de,mp_cache
        add     hl,de
        pop     de
        pop     af
        or      a
        ret
mp_outside:
        pop     de
        pop     af
        scf
        ret

; The cell shows something the cache does not know: forget it (and if it is under the tool icons, they are no longer as they were drawn).
; Keeps a, b, c, de.
mp_forget:
        push    af
        dec     a
        cp      2
        jr      nc,mp_fg_no             ; rows 1 and 2, columns 0 to 27: the tool icons
        ld      a,b
        cp      28
        jr      nc,mp_fg_no
        push    hl
        srl     a
        ld      l,a
        ld      h,0
        ld      a,mp_istate % 256
        add     a,l
        ld      l,a
        ld      a,mp_istate / 256
        adc     a,h
        ld      h,a
        ld      (hl),0
        pop     hl
mp_fg_no:
        pop     af
        call    mp_entry
        ret     c
        ld      (hl),$FF
        inc     hl
        ld      (hl),$FF
        ret

; Text is kept in a shadow screen (mp_shadow: a character a cell, bit 7 set while the cell is not drawn yet; mp_shadow + 768: its attribute) and drawn
; by mp_flush, once, in its final colours: plat_put and plat_text_attr only note what the cell is to show, and a cell that already shows it is not
; drawn at all.  The cell is (0, 0) when it shows no text (a black cell after a clear, or a picture).
; a = row, b = col (row under SHADOW_ROWS): hl = the cell's character in mp_shadow.  Uses de.
mp_shptr:
        ld      l,a
        ld      h,0
        add     hl,hl
        add     hl,hl
        add     hl,hl
        add     hl,hl
        add     hl,hl                   ; row * 32
        ld      e,b
        ld      d,0
        add     hl,de
        ld      de,mp_shadow
        add     hl,de
        ret

; a = row, b = col: the cell is not text any more (a picture was drawn in it).  Keeps a, b, c, de.
mp_noshadow:
        cp      SHADOW_ROWS
        ret     nc
        push    af
        push    hl
        push    de
        call    mp_shptr
        ld      (hl),0                  ; no character,
        ld      de,SHADOW_SIZE
        add     hl,de
        ld      (hl),$FF                ; and an attribute that says there is a picture (a black cell, after a clear, is 0 and 0)
        pop     de
        pop     hl
        pop     af
        ret

; Other drawing in a cell: the cache no longer applies.  a = row, b = col, c = attribute, de = 8 bytes of art.
mp_cell:
        call    mp_forget
mp_cell_nc:
        ld      (mp_src),de
        ld      d,a
        ld      a,c
        ld      (mp_attr),a
        ld      a,d
        call    mp_scraddr
        call    mp_build
        jp      mp_draw

; The art at mp_src in the colours of mp_attr, doubled across, as the cell mp_pix: for each plane a row of the glyph g is (g AND A) XOR B,
; A = a mask of ink xor paper and B = one of paper.
mp_build:
        ld      hl,(mp_src)
        ld      de,mp_g16
        call    mp_dbl8
        ld      a,(mp_attr)
        ld      d,a
        ld      hl,mp_pix
        ; red: ink bit 1, paper bit 4
        ld      b,0
        bit     4,d
        jr      z,mp_r1
        dec     b
mp_r1:  ld      c,b
        bit     1,d
        jr      z,mp_r2
        ld      a,c
        cpl
        ld      c,a
mp_r2:  call    mp_pl16
        ; blue: ink bit 0, paper bit 3
        ld      b,0
        bit     3,d
        jr      z,mp_b1
        dec     b
mp_b1:  ld      c,b
        bit     0,d
        jr      z,mp_b2
        ld      a,c
        cpl
        ld      c,a
mp_b2:  call    mp_pl16
        ; green: ink bit 2, paper bit 5
        ld      b,0
        bit     5,d
        jr      z,mp_g1
        dec     b
mp_g1:  ld      c,b
        bit     2,d
        jr      z,mp_g2
        ld      a,c
        cpl
        ld      c,a
mp_g2:                                  ; fall into mp_pl16

; 16 bytes of a plane at hl from the doubled glyph mp_g16: (g AND c) XOR b; hl goes on.  Uses a, e, d... keeps b, c and d's caller value
mp_pl16:
        push    de
        ld      de,mp_g16
        REPT    16
        ld      a,(de)
        inc     de
        and     c
        xor     b
        ld      (hl),a
        inc     hl
        ENDR
        pop     de
        ret

; c = the attribute with ink and paper swapped.  Uses a, b.
mp_swap:
        ld      a,c
        and     7
        add     a,a
        add     a,a
        add     a,a
        ld      b,a                     ; the ink, as paper
        ld      a,c
        rrca
        rrca
        rrca
        and     7                       ; the paper, as ink
        or      b
        ld      c,a
        ret

; void plat_text_attr(uint8_t col, uint8_t row, uint8_t n, uint8_t attr) __smallc
; Recolours n cells of text already drawn: the cell's attribute in mp_shadow is changed, and it is drawn again (once) by mp_flush.
        PUBLIC  _plat_text_attr
_plat_text_attr:
        ld      hl,2
        add     hl,sp
        ld      a,(hl)
        ld      (mp_ta + 3),a           ; attr
        inc     hl
        inc     hl
        ld      a,(hl)
        ld      (mp_ta),a               ; n
        inc     hl
        inc     hl
        ld      a,(hl)
        ld      (mp_ta + 1),a           ; row
        inc     hl
        inc     hl
        ld      a,(hl)
        ld      (mp_ta + 2),a           ; col
ta_cell:
        ld      a,(mp_ta + 1)
        cp      SHADOW_ROWS
        ret     nc
        ld      a,(mp_ta + 2)
        ld      b,a
        ld      a,(mp_ta + 1)
        call    mp_shptr
        ld      a,(hl)
        and     $7F
        jr      nz,ta_have
        ld      a,' '                   ; (a cell with no text: a blank one in the colours)
ta_have:
        ld      (mp_ch),a
        push    hl
        ld      de,SHADOW_SIZE
        add     hl,de
        ld      a,(mp_ta + 3)
        cp      (hl)
        pop     hl
        jr      nz,ta_set
        ld      a,(hl)                  ; the same attribute: nothing to do if the cell has text
        and     $7F
        jr      nz,ta_next
ta_set:
        ld      a,(mp_ta + 2)           ; the cell shows something else now: forget what the cache or the icons knew of it
        ld      b,a
        ld      a,(mp_ta + 1)
        call    mp_forget
        ld      a,(mp_ta + 2)
        ld      b,a
        ld      a,(mp_ta + 1)
        call    mp_shptr
        ld      a,(mp_ch)
        or      $80
        ld      (hl),a
        ld      de,SHADOW_SIZE
        add     hl,de
        ld      a,(mp_ta + 3)
        ld      (hl),a
        ld      a,1
        ld      (mp_dirty),a
ta_next:
        ld      hl,mp_ta + 2
        inc     (hl)
        ld      hl,mp_ta
        dec     (hl)
        jr      nz,ta_cell
        ret

; a = a character: de = the 8 bytes of its glyph (a blank one for none)
mp_glyph_ch:
        ld      de,mp_zero8
        cp      32
        jr      nc,mp_gl_font
        or      a
        ret     z
        cp      7
        ret     nc
        ld      l,a                     ; a line piece for the boxes' frames
        ld      h,0
        add     hl,hl
        add     hl,hl
        add     hl,hl
        ld      de,mp_box - 8
        add     hl,de
        ex      de,hl
        ret
mp_gl_font:
        ld      l,a
        ld      h,0
        add     hl,hl
        add     hl,hl
        add     hl,hl
        ld      de,FONT - 32 * 8
        add     hl,de
        ld      de,mp_g8t
        ld      bc,8
        call    VCOPY                   ; the glyph out of the plane
        ld      de,mp_g8t
        ret

; Draws the cells of text that are not drawn yet (mp_dirty says there are some), in the order of the screen.
mp_flush:
        ld      a,(mp_dirty)
        or      a
        ret     z
        xor     a
        ld      (mp_dirty),a
        ld      hl,mp_shadow
        ld      (mp_fp),hl
        ld      (mp_fr),a
mp_fl_row:
        xor     a
        ld      (mp_fc),a
mp_fl_col:
        ld      hl,(mp_fp)
        ld      a,(hl)
        bit     7,a
        jr      z,mp_fl_next
        res     7,(hl)
        and     $7F
        ld      (mp_fch),a
        ld      de,SHADOW_SIZE
        add     hl,de
        ld      c,(hl)                  ; its attribute (the fetch of the glyph uses bc)
        ld      a,c
        ld      (mp_fa),a
        ld      a,(mp_fch)
        call    mp_glyph_ch             ; de = its glyph
        ld      a,(mp_fa)
        ld      c,a
        ld      a,(mp_fc)
        ld      b,a
        ld      a,(mp_fr)
        call    mp_cell_nc
mp_fl_next:
        ld      hl,(mp_fp)
        inc     hl
        ld      (mp_fp),hl
        ld      hl,mp_fc
        inc     (hl)
        ld      a,(hl)
        cp      32
        jr      nz,mp_fl_col
        ld      hl,mp_fr
        inc     (hl)
        ld      a,(hl)
        cp      SHADOW_ROWS
        jr      nz,mp_fl_row
        ret

; void plat_put_overlay(uint8_t col, uint8_t row, const uint8_t *art) __smallc
; The pixels set in 8 bytes of art, white, over the cell: a sprite.  The cell's own picture is baked again (the cache knows it) and the
; sprite ORed over it.
        PUBLIC  _plat_put_overlay
_plat_put_overlay:
        ld      hl,2
        add     hl,sp
        ld      e,(hl)
        inc     hl
        ld      d,(hl)
        inc     hl
        ld      a,(hl)
        inc     hl
        inc     hl
        ld      b,(hl)
        ld      (mp_src),de
        ld      (mp_ov),a               ; the row and column
        ld      a,b
        ld      (mp_ov + 1),a
        ld      a,(mp_ov)
        call    mp_entry
        jr      c,mp_ov_blank
        ld      e,(hl)
        inc     hl
        ld      d,(hl)                  ; the word: art xor the inverse flag
        ld      a,e
        and     d
        cp      $FF
        jr      z,mp_ov_blank
        ld      a,e
        and     1
        ld      (mp_ov + 2),a           ; inverse
        res     0,e
        ex      de,hl
        ld      de,_view_tile_art
        or      a
        sbc     hl,de                   ; 8 * n
        ld      d,h
        ld      e,l
        add     hl,hl
        add     hl,de                   ; 24 * n
        ld      de,ATLAS
        add     hl,de
        ld      de,mp_t24
        ld      bc,24
        call    VCOPY
        ld      de,mp_t24
        call    mp_bake
        ld      a,(mp_ov + 2)
        or      a
        call    nz,mp_cpl_pix
        jr      mp_ov_or
mp_ov_blank:
        ld      hl,mp_pix
        ld      b,48
mp_ov_z:
        ld      (hl),0
        inc     hl
        djnz    mp_ov_z
mp_ov_or:
        ld      hl,(mp_src)
        call    mp_orsprite
        ld      a,(mp_ov + 1)
        ld      b,a
        ld      a,(mp_ov)
        call    mp_forget
        call    mp_noshadow
        call    mp_scraddr
        jp      mp_draw

; hl = 8 bytes of sprite art: mp_pix gets its pixels ORed in, doubled across, in all three planes (white).  Uses all but IX.
mp_orsprite:
        ld      de,mp_g16
        call    mp_dbl8                 ; the sprite doubled across
        ld      hl,mp_pix
        ld      c,3
mp_ov_pl:
        ld      de,mp_g16
        ld      b,16
mp_ov_b:
        ld      a,(de)
        inc     de
        or      (hl)
        ld      (hl),a
        inc     hl
        djnz    mp_ov_b
        dec     c
        jr      nz,mp_ov_pl
        ret

; void mp_chart_cell(uint8_t col, uint8_t row, const uint8_t *fill, const uint8_t *dots, uint8_t ink) __smallc   (plat_charts.c, HAVE_CHART_CELL)
; A cell of a bar chart: 8 bytes of art in the colour ink on black, and the white pixels of 8 more over it, drawn once (drawn as two cells,
; it would flash between them, and the cell's fill is not readable from the screen to draw the dots over).
        PUBLIC  _mp_chart_cell
_mp_chart_cell:
        ld      hl,2
        add     hl,sp
        ld      a,(hl)
        and     7
        ld      (mp_attr),a             ; the ink, on black paper
        inc     hl
        inc     hl
        ld      e,(hl)
        inc     hl
        ld      d,(hl)
        ld      (mp_ovp),de
        inc     hl
        ld      e,(hl)
        inc     hl
        ld      d,(hl)
        ld      (mp_src),de
        inc     hl
        ld      a,(hl)                  ; row
        inc     hl
        inc     hl
        ld      b,(hl)                  ; col
        call    mp_forget
        call    mp_noshadow
        call    mp_scraddr
        call    mp_build
        ld      hl,(mp_ovp)
        call    mp_orsprite
        jp      mp_draw

; void mp_icon_fetch(uint8_t *dest, uint8_t n) __smallc
; The 16 bytes of the icon cell n (0 to 55) out of the plane.
        PUBLIC  _mp_icon_fetch
_mp_icon_fetch:
        ld      hl,2
        add     hl,sp
        ld      a,(hl)
        inc     hl
        inc     hl
        ld      e,(hl)
        inc     hl
        ld      d,(hl)                  ; de = dest
        ld      l,a
        ld      h,0
        add     hl,hl
        add     hl,hl
        add     hl,hl
        add     hl,hl
        ld      bc,ICONS
        add     hl,bc
        ld      bc,16
        jp      VCOPY

; void plat_put_bitmap(uint8_t col, uint8_t row, const uint8_t *art) __smallc
; The 8 bytes of art, white on black.
        PUBLIC  _plat_put_bitmap
_plat_put_bitmap:
        ld      hl,2
        add     hl,sp
        ld      e,(hl)
        inc     hl
        ld      d,(hl)
        inc     hl
        ld      a,(hl)
        inc     hl
        inc     hl
        ld      b,(hl)
        ld      c,TEXT_ATTR
        call    mp_noshadow
        jp      mp_cell

; void plat_put(uint8_t col, uint8_t row, uint8_t ch) __smallc
; The character's glyph, white on black.
        PUBLIC  _plat_put
_plat_put:
        ld      hl,2
        add     hl,sp
        ld      a,(hl)
        inc     hl
        inc     hl
        ld      c,(hl)
        inc     hl
        inc     hl
        ld      b,(hl)
        ; a = ch, b = col, c = row
mp_char:
        ld      (mp_ch),a
        ld      a,c
        cp      SHADOW_ROWS
        jr      nc,mp_char_now          ; (a row below the shadow's: drawn at once)
        call    mp_shptr
        ld      a,(hl)
        and     $7F
        ld      d,a                     ; the character the cell has (or will have)
        ld      a,(mp_ch)
        cp      d
        jr      nz,mp_ch_set
        push    hl
        ld      de,SHADOW_SIZE
        add     hl,de
        ld      a,(hl)
        pop     hl
        cp      TEXT_ATTR
        ret     z                       ; it has this character in these colours
mp_ch_set:
        ld      a,(mp_ch)
        cp      ' '
        jr      nz,mp_ch_do
        ld      a,(hl)                  ; a space where there is no text and the cell is black: nothing to draw
        or      a
        jr      nz,mp_ch_do
        push    hl
        ld      de,SHADOW_SIZE
        add     hl,de
        ld      a,(hl)
        pop     hl
        or      a
        ret     z
mp_ch_do:
        ld      a,c                     ; the cell shows something else: forget what the cache or the icons knew of it
        call    mp_forget
        ld      a,c
        call    mp_shptr
        ld      a,(mp_ch)
        or      $80
        ld      (hl),a                  ; the character, not drawn yet,
        ld      de,SHADOW_SIZE
        add     hl,de
        ld      (hl),TEXT_ATTR          ; in the plain colours
        ld      a,1
        ld      (mp_dirty),a
        ret
mp_char_now:
        ld      a,(mp_ch)
        cp      32
        jr      nc,mp_ch_font
        ld      l,a                     ; a line piece for the boxes' frames: codes 1 to 6
        ld      h,0
        add     hl,hl
        add     hl,hl
        add     hl,hl
        ld      de,mp_box - 8
        add     hl,de
        ex      de,hl
        ld      a,c
        ld      c,TEXT_ATTR
        jp      mp_cell
mp_ch_font:
        push    bc
        ld      l,a
        ld      h,0
        add     hl,hl
        add     hl,hl
        add     hl,hl                   ; ch * 8
        ld      de,FONT - 32 * 8
        add     hl,de
        ld      de,mp_g8t
        ld      bc,8
        call    VCOPY
        pop     bc
        ld      de,mp_g8t               ; de = its glyph
        ld      a,c
        ld      c,TEXT_ATTR
        jp      mp_cell

; void plat_puts(uint8_t col, uint8_t row, const char *s) __smallc
; Stops at the right edge.
        PUBLIC  _plat_puts
        PUBLIC  _plat_text_puts
_plat_text_puts:
_plat_puts:
        ld      hl,2
        add     hl,sp
        ld      e,(hl)
        inc     hl
        ld      d,(hl)
        inc     hl
        ld      c,(hl)
        inc     hl
        inc     hl
        ld      b,(hl)
mp_puts_next:
        ld      a,b
        cp      32
        ret     nc
        ld      a,(de)
        or      a
        ret     z
        inc     de
        push    de
        push    bc
        call    mp_char
        pop     bc
        pop     de
        inc     b
        jr      mp_puts_next

; void plat_init(void): the 6845, the interrupt, the doubling tables, the screen cleared
        PUBLIC  _plat_init
_plat_init:
        di
        xor     a
        out     ($80),a                 ; the control port: cassette off, the normal green plane shown (a ROM that ran before may have left bits that stop the video RAM being written)
        ld      a,NORMAL
        out     (PORT_BANK),a
        ld      a,(mp_up)
        or      a
        jr      nz,mp_up_done
        inc     a
        ld      (mp_up),a
        ld      a,$C3                   ; our frame interrupt (IM 1: the vector is in the user RAM)
        ld      ($0038),a
        ld      hl,mp_isr
        ld      ($0039),hl
        ld      hl,VCOPY                ; the RAM half of VCOPY: LD A,$0E; OUT ($82),A (read the video RAM, write the RAM), and a RET where the plane's half ends
        ld      (hl),$3E
        inc     hl
        ld      (hl),$0E
        inc     hl
        ld      (hl),$D3
        inc     hl
        ld      (hl),PORT_BANK
        ld      a,$C9
        ld      (VCOPY + 10),a
        ld      hl,mp_crtc
        ld      b,16
        xor     a
        ld      c,$87
mp_crtc_lp:
        out     ($86),a
        ld      e,(hl)
        out     (c),e
        inc     hl
        inc     a
        djnz    mp_crtc_lp
        ld      de,DBL                  ; the doubled nibbles: the high one of each byte, then the low one
        ld      b,0
mp_d1:  ld      a,b
        rrca
        rrca
        rrca
        rrca
        and     15
        call    mp_dn_get
        ld      (de),a
        inc     de
        inc     b
        jr      nz,mp_d1
mp_d2:  ld      a,b
        and     15
        call    mp_dn_get
        ld      (de),a
        inc     de
        inc     b
        jr      nz,mp_d2
mp_up_done:
        im      1
        ; fall into plat_clear

; void plat_clear(void): the three planes to 0 (in the drawing window), and nothing is remembered of the screen
        PUBLIC  _plat_clear
        PUBLIC  _plat_text_clear
_plat_text_clear:
_plat_clear:
        ld      (mp_spsave),sp          ; the drawing window has no stack, so SP can be the store pointer: a PUSH writes two bytes of a plane
        ld      de,0
        ld      bc,1536                 ; 48 KB in blocks of 32 bytes
        ld      a,DRAW
        out     (PORT_BANK),a
        ld      sp,$C000
mp_clr:
        REPT    16
        push    de
        ENDR
        dec     bc
        ld      a,b
        or      c
        jp      nz,mp_clr
        ld      a,NORMAL
        out     (PORT_BANK),a
        ld      sp,(mp_spsave)
        ld      hl,mp_cache             ; no cell shows what the cache says
        ld      de,mp_cache + 1
        ld      bc,32 * MAP_ROWS * 2 - 1
        ld      (hl),$FF
        ldir
        ld      hl,mp_shadow            ; and there is no text, drawn or not
        ld      de,mp_shadow + 1
        ld      bc,2 * SHADOW_SIZE - 1
        ld      (hl),0
        ldir
        xor     a
        ld      (mp_dirty),a
        ld      hl,mp_istate            ; no icon is on the screen
        ld      de,mp_istate + 1
        ld      bc,13
        ld      (hl),0
        ldir
        ret

; a = a nibble: a = it doubled across (mp_dn)
mp_dn_get:
        push    hl
        ld      l,a
        ld      h,0
        ld      a,mp_dn % 256
        add     a,l
        ld      l,a
        ld      a,mp_dn / 256
        adc     a,h
        ld      h,a
        ld      a,(hl)
        pop     hl
        ret

; The frame interrupt: a frame is counted, and interrupts stay off (the VSYNC is held for a few lines) until plat_idle waits for the next
mp_isr:
        push    af
        ld      a,(mp_vbl)
        inc     a
        ld      (mp_vbl),a
        pop     af
        ret

; uint8_t plat_key(void): the key pressed since the last call, or 0: a new key at once, a held one again after a delay and then at a rate.
; Letters are lower case (upper case with the shift key), the cursor keys 8 left, 9 right, 10 down, 11 up (28 to 31 with the shift key).
        PUBLIC  _plat_key
_plat_key:
        call    mp_flush                ; (a screen of text is drawn before it waits for a key)
        call    mp_scan                 ; a = the key (0 for none)
        or      a
        jr      z,mp_k_none
        ld      d,a
        ld      a,(mp_lastkey)
        cp      d
        jr      z,mp_k_held
        ld      a,d                     ; a new key
        ld      (mp_lastkey),a
        ld      a,(mp_vbl)
        ld      (mp_keyt),a
        ld      a,24                    ; (the first repeat comes 24 frames on)
        ld      (mp_keyd),a
        jr      mp_k_got
mp_k_held:
        ld      a,(mp_vbl)
        ld      hl,mp_keyt
        sub     (hl)
        ld      hl,mp_keyd
        cp      (hl)
        jr      c,mp_k_zero             ; not yet
        ld      a,(mp_vbl)
        ld      (mp_keyt),a
        ld      a,5                     ; (and then every 5)
        ld      (mp_keyd),a
mp_k_got:
        ld      a,(mp_lastkey)
        ld      l,a
        ld      h,0
        cp      8
        ret     c
        cp      12
        jr      nc,mp_k_chr
        ld      a,(mp_shift)            ; a cursor key (8 to 11) with the shift key: 28 to 31
        or      a
        ret     z
        ld      a,l
        add     a,20
        ld      l,a
        ret
mp_k_chr:
        ld      a,(mp_shift)            ; a letter with the shift key is upper case (Q A O P with shift: eight cells)
        or      a
        ret     z
        ld      a,l
        cp      'a'
        ret     c
        cp      'z' + 1
        ret     nc
        sub     32
        ld      l,a
        ret
mp_k_zero:
        ld      hl,0
        ret
mp_k_none:
        xor     a
        ld      (mp_lastkey),a
        ld      l,a
        ld      h,a
        ret

; a = the first key down (its code, 0 if there is none); mp_shift is 1 if the shift key is down.  Uses all but the alternate registers.
mp_scan:
        ld      bc,$0080                ; line 0: the shift key is bit 7
        in      a,(c)
        cpl
        rlca
        and     1
        ld      (mp_shift),a
        ld      d,0                     ; the line
mp_sc_line:
        ld      b,d
        ld      c,$80
        in      a,(c)
        cpl
        ld      e,a                     ; the keys of the line that are down, a bit each
        ld      a,d
        add     a,a
        add     a,a
        add     a,a
        ld      l,a
        ld      h,0
        ld      bc,mp_keys
        add     hl,bc                   ; the line's row of the table
        ld      b,8
mp_sc_bit:
        srl     e
        jr      nc,mp_sc_nb
        ld      a,(hl)
        or      a
        ret     nz                      ; a key (not the shift or control key, which have no code)
mp_sc_nb:
        inc     hl
        djnz    mp_sc_bit
        inc     d
        ld      a,d
        cp      10
        jr      nz,mp_sc_line
        xor     a
        ret

; uint16_t plat_clock(void), void plat_idle(void): a count of the frames the game has waited for, and a wait for the next one
        PUBLIC  _plat_clock
_plat_clock:
        ld      hl,(mp_clock)
        ret
        PUBLIC  _plat_idle
_plat_idle:
        call    mp_flush
        ld      hl,(mp_clock)
        inc     hl
        ld      (mp_clock),hl
        ei
        halt                            ; (the handler leaves interrupts off again)
        ret

        PUBLIC  _plat_flush
        PUBLIC  _plat_exit
_plat_flush:
        jp      mp_flush
_plat_exit:
        ret

; void plat_put_minirow(uint8_t ty, const uint8_t *colours, const uint8_t *base, uint8_t view) __smallc
; Draws tile row ty (0..95) of the mini map from its 96 colours (bit 0 blue, 1 red, 2 green), one a tile column.  A tile is 4 pixels wide and
; 2 lines high, so a row is 384 pixels (48 bytes a plane) by two lines, lines 2 ty and 2 ty + 1, from the left of the screen.  base and view
; are not used: a tile of the city shown dim where a view has none comes in the colours as colour bit 3 (ui/game.c, HAVE_MINIMAP_FLAT_BASE),
; drawn as a checker.
        PUBLIC  _plat_put_minirow
_plat_put_minirow:
        ld      hl,6
        add     hl,sp
        ld      e,(hl)
        inc     hl
        ld      d,(hl)                  ; de = the colours
        inc     hl
        ld      l,(hl)                  ; ty
        ld      (mm_src),de
        ld      h,0
        add     hl,hl
        add     hl,hl
        add     hl,hl
        add     hl,hl
        add     hl,hl
        add     hl,hl
        add     hl,hl                   ; ty * 128: its two lines
        ld      de,$0100
        add     hl,de
        ld      (mm_dst),hl
        ld      hl,mm_buf
        ld      (mm_out),hl
        ld      a,48
        ld      (mm_cnt),a
mm_k:
        ld      hl,(mm_src)             ; two tiles' colours
        ld      a,(hl)
        and     15
        ld      (mm_c0),a
        inc     hl
        ld      a,(hl)
        and     15
        ld      (mm_c1),a
        inc     hl
        ld      (mm_src),hl
        ld      hl,mm_nib
        ld      de,(mm_out)
        ld      b,6
mm_t:
        ld      a,(mm_c0)
        call    mm_lookup
        rlca
        rlca
        rlca
        rlca
        and     $F0
        ld      c,a
        ld      a,(mm_c1)
        call    mm_lookup
        or      c
        ld      (de),a
        ld      a,e                     ; the next buffer: 48 on
        add     a,48
        ld      e,a
        jr      nc,mm_t1
        inc     d
mm_t1:
        ld      a,l                     ; the next table: 16 on
        add     a,16
        ld      l,a
        jr      nc,mm_t2
        inc     h
mm_t2:
        djnz    mm_t
        ld      hl,(mm_out)
        inc     hl
        ld      (mm_out),hl
        ld      hl,mm_cnt
        dec     (hl)
        jr      nz,mm_k
        ld      hl,mm_buf               ; the drawing window: each plane's two lines
        ld      de,(mm_dst)
        ld      a,3
        ex      af,af'
        ld      a,DRAW
        out     (PORT_BANK),a
mm_pl:
        ld      bc,48
        ldir                            ; line 0
        ld      a,e
        add     a,16
        ld      e,a
        jp      nc,mm_p1
        inc     d
mm_p1:  ld      bc,48
        ldir                            ; line 1
        ld      a,d
        add     a,$40
        ld      d,a
        ld      a,e
        sub     112
        ld      e,a
        jp      nc,mm_p2
        dec     d
mm_p2:  ex      af,af'
        dec     a
        jp      z,mm_done
        ex      af,af'
        jp      mm_pl
mm_done:
        ld      a,NORMAL
        out     (PORT_BANK),a
        ret

; a = the colour (0-15): a = the nibble in the table hl; keeps hl
mm_lookup:
        push    hl
        add     a,l
        ld      l,a
        jr      nc,mm_l1
        inc     h
mm_l1:  ld      a,(hl)
        pop     hl
        ret

; The line pieces of the boxes' frames, pipes two pixels thick with rounded corners: 1 top left, 2 top right, 3 bottom left, 4 bottom
; right, 5 across, 6 down (codes the frames' strings in plat_config.h have, below the space: mp_char takes them for these)
mp_box:
        defb    $00,$00,$00,$0F,$1F,$18,$18,$18
        defb    $00,$00,$00,$F0,$F8,$18,$18,$18
        defb    $18,$18,$18,$1F,$0F,$00,$00,$00
        defb    $18,$18,$18,$F8,$F0,$00,$00,$00
        defb    $00,$00,$00,$FF,$FF,$00,$00,$00
        defb    $18,$18,$18,$18,$18,$18,$18,$18
mp_zero8:
        defb    0,0,0,0,0,0,0,0

; uint8_t plat_icon_same(uint8_t icon, uint8_t selected, uint8_t affordable) __smallc  (plat_icons.c, HAVE_ICON_CACHE)
; 1 if the icon was drawn like this and nothing has drawn over it since; else it is noted as drawn like this and the answer is 0.
        PUBLIC  _plat_icon_same
_plat_icon_same:
        ld      hl,2
        add     hl,sp
        ld      a,(hl)                  ; affordable
        add     a,a
        ld      c,a
        inc     hl
        inc     hl
        ld      a,(hl)                  ; selected
        or      c
        or      4                       ; (on the screen)
        ld      c,a
        inc     hl
        inc     hl
        ld      e,(hl)                  ; the icon
        ld      d,0
        ld      hl,mp_istate
        add     hl,de
        ld      a,(hl)
        cp      c
        ld      (hl),c
        ld      hl,0
        ret     nz
        inc     l
        ret

        SECTION bss_user
mp_cache: defs  32 * MAP_ROWS * 2       ; what each map cell shows (32 x 25 words)
mp_shadow: defs 2 * SHADOW_SIZE          ; the character in each cell of the first rows (0: none; bit 7: not drawn yet), then its attribute
mp_pix:  defs   48                      ; a cell as drawn: red, blue and green, 16 bytes each
mp_g16:  defs   16                      ; a glyph doubled across
mp_g8t:  defs   8                       ; a glyph fetched from the plane
mp_t24:  defs   24                      ; a picture fetched from the plane
mm_buf:  defs   288                     ; the mini map row: red, blue and green, two lines of 48 bytes each
mp_istate: defs 14                      ; how each icon was drawn: bit 0 selected, 1 affordable, 2 it is on the screen (0: not known)

        SECTION code_user
mp_up:   defb   0                       ; plat_init has run
mp_attr: defb   0                       ; the cell's attribute
mp_ch:   defb   0                       ; the character being drawn
mp_src:  defw   0                       ; the art being drawn
mp_scr:  defw   0                       ; the cell's offset in the red plane
mp_bs:   defw   0                       ; the picture being baked
mp_clock: defw  0
mp_dirty: defb  0                       ; there is text not drawn yet
mp_fp:   defw   0                       ; mp_flush: the cell it is at, and its row and column
mp_fr:   defb   0
mp_fc:   defb   0
mp_fa:   defb   0                       ; mp_flush: the attribute and the character of the cell
mp_fch:  defb   0
mp_spsave: defw 0                       ; the stack pointer, while plat_clear uses it to store
        PUBLIC  mp_vbl
mp_vbl:  defb   0                       ; the frames the interrupt has counted
mp_shift: defb  0                       ; the shift key is down
mp_lastkey: defb 0                      ; the key that was down at the last plat_key (0: none)
mp_keyt: defb   0                       ; the frame count when it went down or last repeated
mp_keyd: defb   0                       ; the frames until it repeats
mp_ta:   defs   4                       ; plat_text_attr: the count, the row, the column and the attribute
mp_ovp:  defw   0                       ; mp_chart_cell: the dots' art
mp_ov:   defs   3                       ; plat_put_overlay: the row, the column and the inverse flag
mm_dst:  defw   0                       ; the mini map row's first line in the red plane
mm_src:  defw   0                       ; the colours still to do
mm_out:  defw   0                       ; the byte of the first buffer being made
mm_cnt:  defb   0
mm_c0:   defb   0                       ; the colours of the two tiles of a byte
mm_c1:   defb   0
