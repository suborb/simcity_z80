; Mitsubishi Multi 8 platform (all-RAM mode, see -subtype=64k): the game draws pictures and text itself.
;
; The screen is three planes (blue, red, green: the bit order of a Spectrum attribute) of 80 bytes to a pixel row,
; 200 rows, 640 pixels across, and its pixels are twice as tall as they are wide.  The game's 8x8 cells are drawn
; with every pixel doubled across, so a cell is 16x8 hardware pixels, two bytes by eight rows, and the 40 columns
; fill the width.  A cell's first byte is
;     $8000 + row * 640 + col * 2          and the rest of its pixel rows are 80 bytes apart in each plane.
; The planes are paged in over $8000-$BFFF by port $2A (bits 0-3 are active low, one for each plane; bit 4 is set
; to see the planes and clear for the RAM underneath, where the uninitialised data lives), so nothing in
; $8000-$BFFF can be read or written while a plane is paged in: the routines' own variables are in the data
; section, which is in the low RAM with the code.  Interrupts are off (the startup code does that).
;
; The routines take their arguments the way the game's C code passes them (smallc: first argument pushed first,
; the caller cleans up).  A cell is the Spectrum's: ink in attribute bits 0-2 and paper in 3-5.  A plane's byte
; for a pixel is its ink or paper state:
;     ink  paper     byte
;      1     0       the picture
;      0     1       its inverse
;      1     1       $FF
;      0     0       0
; (an inverted picture is the same with ink and paper swapped), so each of the three planes is drawn one of four
; ways, and planes drawn the same way are stored together: a store with several planes paged in goes to each.
; The picture is first doubled across into mp_pix with a table of the doubled halves of a byte (mp_dbl_init).

        SECTION code_user
        EXTERN  _font_8x8_bbc_system
        EXTERN  __port29_copy
        EXTERN  _view_tile_art          ; the engine's art table: picture n is at 8 * n from it

        defc    PORT_MEM = $2A
        defc    MEM_IDLE = $2F          ; the RAM under the screen (what z88dk's console calls vram_out)
        defc    MEM_ALL = $38           ; all three planes together (a store goes to each)
        defc    MEM_TEXT = $37          ; the text page
        defc    SCREEN = $8000
        defc    DBL = $F800             ; 512 bytes above the data: the doubled high nibble of a byte, then the low
        defc    DBL_HI = DBL / 256
        defc    TEXT_ATTR = 7           ; white on black

; The baked map pictures, in the image after the variables (so that those stay in the low RAM, which the code and the
; variables must while a plane is paged over $8000-$BFFF): the pictures are read only with the RAM under the planes paged in
        SECTION data_fcntl
mp_tiles:
        BINARY  "build/multi8/mp_tiles.bin"

; The 14 tool icons: four 8x8 cells each, then their attribute bytes (tools/make_multi8_assets.py)
        SECTION rodata_user
        PUBLIC  _mp_icons
_mp_icons:
        BINARY  "assets/icons_spec.bin"

        SECTION code_user

; void plat_put_tile(uint8_t col, uint8_t row, const uint8_t *art, uint8_t attr, uint8_t inverse) __smallc
; One of the map's pictures: art points into the engine's art table, which says which (picture n is at
; _view_tile_art + 8 * n), and the picture is drawn from mp_tiles, where it is baked in the Multi 8's colours: 24 bytes,
; a plane (blue, red, green) of eight pixel rows after another (tools/extract_cpc_tiles.py).  The attribute is not
; used.  `inverse` draws the complement, which is the cursor.
        PUBLIC  _plat_put_tile
_plat_put_tile:
        ld      hl,2
        add     hl,sp
        ld      a,(hl)                  ; inverse
        ld      c,$80                   ; the cache's key for this: $80, or $81 inverted (the other path's are below $40)
        or      a
        jr      z,mp_t_plain
        inc     c
mp_t_plain:
        inc     hl
        inc     hl
        inc     hl
        inc     hl                      ; (past the attribute)
        ld      e,(hl)
        inc     hl
        ld      d,(hl)                  ; de = art
        inc     hl
        ld      a,(hl)                  ; row
        inc     hl
        inc     hl
        ld      b,(hl)                  ; col
        call    mp_cached
        ret     c
        ; a = row, b = col, c = key, de = art: the picture to a doubled copy of its three planes
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
        ld      de,mp_tiles
        add     hl,de
        ex      de,hl                   ; de = its planes
        push    ix                      ; (the C code's frame pointer: kept)
        ld      ix,mp_pix3
        ld      b,24
mp_bake_lp:
        ld      a,(de)
        inc     de
        ld      l,a
        ld      h,DBL_HI
        ld      a,(hl)                  ; the high nibble doubled: the left byte
        ld      (ix+0),a
        inc     ix
        inc     h
        ld      a,(hl)                  ; the low nibble: the right byte
        ld      (ix+0),a
        inc     ix
        djnz    mp_bake_lp
        pop     ix
        pop     bc
        bit     0,c
        jr      z,mp_bake_draw
        ld      hl,mp_pix3              ; inverted: the complement (the row, which a is for, is still on the stack)
        ld      d,48
mp_bake_cpl:
        ld      a,(hl)
        cpl
        ld      (hl),a
        inc     hl
        dec     d
        jr      nz,mp_bake_cpl
mp_bake_draw:
        pop     af
        call    mp_scraddr
        ld      de,mp_pix3
        ld      a,1                     ; blue, red, green: each in turn, from the next 16 bytes
        call    mp_one
        ld      a,2
        call    mp_one
        ld      a,4
        call    mp_one
        ld      a,MEM_IDLE
        out     (PORT_MEM),a
        jp      mp_keyscan

; The cell's 16 bytes from de into the plane a (bit 0 blue, 1 red, 2 green); de goes on
mp_one:
        cpl
        and     7
        or      $38
        out     (PORT_MEM),a
        ld      hl,(mp_scr)
        ld      bc,79
        jp      mp_copy

; void mp_tile1(uint8_t col, uint8_t row, const uint8_t *art, uint8_t attr, uint8_t inverse) __smallc
; The 8 bytes of art, in the colours of attr (ink and paper swapped if `inverse`): the mini maps and the icons.
        PUBLIC  _mp_tile1
_mp_tile1:
        ld      hl,2
        add     hl,sp
        ld      a,(hl)                  ; inverse
        inc     hl
        inc     hl
        ld      c,(hl)                  ; attr
        or      a
        call    nz,mp_swap
        ld      a,c
        and     $3F                     ; the colours: the cache's key
        ld      c,a
        inc     hl
        inc     hl
        ld      e,(hl)
        inc     hl
        ld      d,(hl)                  ; de = art
        inc     hl
        ld      a,(hl)                  ; row
        inc     hl
        inc     hl
        ld      b,(hl)                  ; col
        call    mp_cached
        ret     c
        jr      mp_cell_nc

; A cell that already shows this picture in these colours is left alone (the game redraws far more than changes):
; mp_cache holds each cell's art address and key (the colours, bits 0-5, swapped if inverse, or $80 and up for the map's
; own pictures), or $40 for a cell that has been drawn some other way.  a = row, b = col, c = key, de = art.
; Carry if the cell is as wanted; otherwise the entry is updated and it is clear.  Keeps a, b, c and de.
mp_cached:
        push    af
        push    de
        call    mp_entry
        pop     de
        ld      a,(hl)
        cp      e
        jr      nz,mp_miss
        inc     hl
        ld      a,(hl)
        cp      d
        jr      nz,mp_miss1
        inc     hl
        ld      a,(hl)
        cp      c
        jr      nz,mp_miss2
        pop     af
        scf
        ret
mp_miss:
        ld      (hl),e
        inc     hl
mp_miss1:
        ld      (hl),d
        inc     hl
mp_miss2:
        ld      (hl),c
        pop     af
        or      a
        ret

; The cache entry of the cell a = row, b = column -> hl (row * 40 + col, times 3).  Keeps a, b and c.
mp_entry:
        push    af
        push    de
        ld      l,a
        ld      h,0
        add     hl,hl
        add     hl,hl
        add     hl,hl                   ; row * 8
        ld      d,h
        ld      e,l
        add     hl,hl
        add     hl,hl                   ; row * 32
        add     hl,de                   ; row * 40
        ld      e,b
        ld      d,0
        add     hl,de
        ld      d,h
        ld      e,l
        add     hl,hl
        add     hl,de                   ; * 3
        ld      de,mp_cache
        add     hl,de
        pop     de
        pop     af
        ret

; Any other drawing (text, a bitmap) in a cell: it no longer shows what the cache says
mp_cell:
        push    de
        call    mp_entry
        inc     hl
        inc     hl
        ld      (hl),$40
        pop     de
mp_cell_nc:
        call    mp_scraddr
        ld      a,c                     ; ink == paper (the density minimaps): a plain fill, with no picture to draw
        rrca
        rrca
        rrca
        xor     c
        and     7
        jp      z,mp_solid
        push    de                      ; the art, for after the planes are worked out
        ; which planes are drawn which way: mp_m[k] gets the bit of each plane whose ink bit is k & 1, paper bit k >> 1
        xor     a
        ld      hl,mp_m
        ld      (hl),a
        inc     hl
        ld      (hl),a
        inc     hl
        ld      (hl),a
        inc     hl
        ld      (hl),a
        ld      b,1                     ; the plane's bit
mp_cls:
        ld      a,c
        and     1
        ld      d,a
        ld      a,c
        rrca
        rrca
        and     2                       ; the paper bit (3 for this plane)
        or      d
        ld      e,a
        ld      d,0
        ld      hl,mp_m
        add     hl,de
        ld      a,(hl)
        or      b
        ld      (hl),a
        srl     c                       ; the next plane's bits
        sla     b
        ld      a,b
        cp      8
        jr      nz,mp_cls
        pop     de
        call    mp_double               ; the picture doubled across, into mp_pix
mp_draw:
        ; and each way of drawing, for the planes that use it
        ld      hl,mp_zero
        ld      a,(mp_m)
        call    mp_pass
        ld      hl,mp_copy
        ld      a,(mp_m + 1)
        call    mp_pass
        ld      hl,mp_cpl
        ld      a,(mp_m + 2)
        call    mp_pass
        ld      hl,mp_ones
        ld      a,(mp_m + 3)
        call    mp_pass
        ld      a,MEM_IDLE
        out     (PORT_MEM),a
        ; and a look at the keyboard (a redraw takes long enough for a short press to come and go between the game's own
        ; polls): fall into mp_keyscan

; Sample the keyboard: port 1 has bit 3 clear while a key is down and bit 7 set for shift, port 0 is the key's code.
; A key going down (or another coming down) is kept as the event for plat_key; nothing else is kept.  Uses a, c, hl.
mp_keyscan:
        in      a,(1)
        ld      c,a
        and     8
        jr      nz,mp_keyup
        in      a,(0)
        ld      hl,mp_held
        cp      (hl)
        ret     z                       ; the same key, still down
        ld      (hl),a
        ld      (mp_event),a
        ld      a,c
        ld      (mp_flags),a
        ret
mp_keyup:
        xor     a
        ld      (mp_held),a             ; no key is down: the next press is a new one
        ret

; A cell of one colour: the planes of the ink are ones, the others zeros.  (c = the attribute.)
mp_solid:
        ld      a,c
        and     7
        ld      c,a
        xor     a
        ld      (mp_m + 1),a
        ld      (mp_m + 2),a
        ld      a,c
        ld      (mp_m + 3),a
        cpl
        and     7
        ld      (mp_m),a
        jr      mp_draw

; uint16_t mp_key(void): the key pressed since the last call (its code in l, the flags in h), or 0 in l
        PUBLIC  _mp_key
_mp_key:
        call    mp_keyscan
        ld      hl,(mp_event)
        xor     a
        ld      (mp_event),a
        ret

; Draw the cell one way into the planes in a (a bit each: 1 blue, 2 red, 4 green; none: nothing): hl = the routine
; (it returns to mp_pass's caller).  The routines have hl = the cell, de = mp_pix, bc = 79 (80 less the byte stepped over).
mp_pass:
        or      a
        ret     z
        cpl
        and     7
        or      $38                     ; the planes, active low
        out     (PORT_MEM),a
        push    hl
        ld      hl,(mp_scr)
        ld      de,mp_pix
        ld      bc,79
        ret

mp_zero:
        REPT    8
        ld      (hl),0
        inc     hl
        ld      (hl),0
        add     hl,bc
        ENDR
        ret
mp_ones:
        REPT    8
        ld      (hl),$FF
        inc     hl
        ld      (hl),$FF
        add     hl,bc
        ENDR
        ret
mp_copy:
        REPT    8
        ld      a,(de)
        ld      (hl),a
        inc     de
        inc     hl
        ld      a,(de)
        ld      (hl),a
        inc     de
        add     hl,bc
        ENDR
        ret
mp_cpl:
        REPT    8
        ld      a,(de)
        cpl
        ld      (hl),a
        inc     de
        inc     hl
        ld      a,(de)
        cpl
        ld      (hl),a
        inc     de
        add     hl,bc
        ENDR
        ret

; The address of the cell a = row, b = column in the planes, into mp_scr: row * 640 is (row * 5) << 7.  Uses a and hl.
mp_scraddr:
        ld      h,a
        add     a,a
        add     a,a
        add     a,h                     ; row * 5, which fits a byte, and row * 640 is that << 7
        rrca                            ; bit 7 = its low bit; bits 0-6 = the rest
        ld      l,a
        and     $7F
        or      $80                     ; SCREEN is $8000
        ld      h,a
        ld      a,l
        and     $80
        ld      l,a
        ld      a,b
        add     a,a                     ; col * 2, below $80
        or      l
        ld      l,a
        ld      (mp_scr),hl
        ret

; The 8 bytes at de, every pixel doubled across, into mp_pix (two bytes a row).  Uses a, bc, de and hl.
mp_double:
        ld      hl,mp_pix
        REPT    8
        ld      a,(de)
        inc     de
        ld      c,a
        ld      b,DBL_HI
        ld      a,(bc)                  ; the high nibble, doubled: the left byte
        ld      (hl),a
        inc     hl
        inc     b
        ld      a,(bc)                  ; the low nibble: the right byte
        ld      (hl),a
        inc     hl
        ENDR
        ret

; void plat_put_overlay(uint8_t col, uint8_t row, const uint8_t *art) __smallc
; The pixels set in the 8 bytes of art, white, over what the cell shows: a sprite over its tile.  (The cell then shows
; something the cache does not know.)
        PUBLIC  _plat_put_overlay
_plat_put_overlay:
        ld      hl,2
        add     hl,sp
        ld      e,(hl)
        inc     hl
        ld      d,(hl)                  ; de = art
        inc     hl
        ld      a,(hl)                  ; row
        inc     hl
        inc     hl
        ld      b,(hl)                  ; col
        push    af
        push    bc
        call    mp_double
        pop     bc
        pop     af
        push    af
        push    bc
        call    mp_entry                ; the cell no longer shows what the cache says
        inc     hl
        inc     hl
        ld      (hl),$40
        pop     bc
        pop     af
        call    mp_scraddr
        ld      a,1                     ; the pixels into each plane in turn (white is all three): or them in
        call    mp_or
        ld      a,2
        call    mp_or
        ld      a,4
        call    mp_or
        ld      a,MEM_IDLE
        out     (PORT_MEM),a
        jp      mp_keyscan

; The doubled cell in mp_pix ORed into the plane a (bit 0 blue, 1 red, 2 green)
mp_or:
        cpl
        and     7
        or      $38
        out     (PORT_MEM),a
        ld      hl,(mp_scr)
        ld      de,mp_pix
        ld      bc,79
        REPT    8
        ld      a,(de)
        or      (hl)
        ld      (hl),a
        inc     hl
        inc     de
        ld      a,(de)
        or      (hl)
        ld      (hl),a
        inc     de
        add     hl,bc
        ENDR
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

; void plat_put_bitmap(uint8_t col, uint8_t row, const uint8_t *art) __smallc
; The 8 bytes of art, white on black.
        PUBLIC  _plat_put_bitmap
_plat_put_bitmap:
        ld      hl,2
        add     hl,sp
        ld      e,(hl)
        inc     hl
        ld      d,(hl)                  ; de = art
        inc     hl
        ld      a,(hl)                  ; row
        inc     hl
        inc     hl
        ld      b,(hl)                  ; col
        ld      c,TEXT_ATTR
        jp      mp_cell

; void plat_put(uint8_t col, uint8_t row, uint8_t ch) __smallc
; The character's 8x8 glyph from the console's font, white on black.
        PUBLIC  _plat_put
_plat_put:
        ld      hl,2
        add     hl,sp
        ld      a,(hl)                  ; ch
        inc     hl
        inc     hl
        ld      c,(hl)                  ; row
        inc     hl
        inc     hl
        ld      b,(hl)                  ; col
        ; a = ch, b = col, c = row
mp_char:
        ld      l,a
        ld      h,0
        add     hl,hl
        add     hl,hl
        add     hl,hl                   ; ch * 8
        ld      de,_font_8x8_bbc_system - 32 * 8
        add     hl,de
        ex      de,hl                   ; de = its glyph
        ld      a,c                     ; row
        ld      c,TEXT_ATTR
        jp      mp_cell

; void plat_puts(uint8_t col, uint8_t row, const char *s) __smallc
; Not past the right edge (column 39): it would wrap.
        PUBLIC  _plat_puts
        PUBLIC  _plat_text_puts
_plat_text_puts:
_plat_puts:
        ld      hl,2
        add     hl,sp
        ld      e,(hl)
        inc     hl
        ld      d,(hl)                  ; de = s
        inc     hl
        ld      c,(hl)                  ; row
        inc     hl
        inc     hl
        ld      b,(hl)                  ; col
mp_puts_next:
        ld      a,b
        cp      40
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

; The table that doubles a byte's pixels across: DBL[x] is the high nibble of x with every bit doubled (the left
; byte of the doubled pixels), DBL[256 + x] the low nibble (the right byte)
mp_dbl_init:
        ld      hl,DBL
        ld      de,mp_nibbles
        ld      b,16
mp_dbl_hi:
        ld      a,(de)
        inc     de
        ld      c,16
mp_dbl_fill:
        ld      (hl),a
        inc     hl
        dec     c
        jr      nz,mp_dbl_fill
        djnz    mp_dbl_hi
        ld      de,DBL + 256
        ld      b,16
mp_dbl_lo:
        push    bc
        ld      hl,mp_nibbles
        ld      bc,16
        ldir
        pop     bc
        djnz    mp_dbl_lo
        ret

; void plat_init(void): the doubling table, the colour screen at 80 columns, the text page blank, then the pixels cleared
        PUBLIC  _plat_init
_plat_init:
        di
        call    mp_dbl_init
        ld      a,(__port29_copy)
        and     $3F                     ; bit 7 clear: colour; bit 6 set: 80 columns
        or      $40
        ld      (__port29_copy),a
        out     ($29),a
        ld      a,6                     ; the CRT controller: 25 rows of 8 scan lines
        out     ($1C),a
        ld      a,25
        out     ($1D),a
        ld      a,9
        out     ($1C),a
        ld      a,7
        out     ($1D),a
        ld      a,MEM_TEXT
        out     (PORT_MEM),a
        ld      hl,SCREEN
        ld      de,SCREEN + 1
        ld      bc,80 * 25 - 1
        ld      (hl),32                 ; spaces, so no text shows over the pixels
        ldir
        ld      hl,SCREEN + $800
        ld      de,SCREEN + $801
        ld      bc,80 * 25 - 1
        ld      (hl),7
        ldir
        ; and clear the pixels

; void plat_clear(void): the three planes to 0 (a store with all three paged in goes to each)
        PUBLIC  _plat_clear
        PUBLIC  _plat_text_clear
_plat_text_clear:
_plat_clear:
        ld      a,MEM_ALL
        out     (PORT_MEM),a
        ld      hl,SCREEN
        ld      de,SCREEN + 1
        ld      bc,80 * 200 - 1
        ld      (hl),0
        ldir
        ld      a,MEM_IDLE
        out     (PORT_MEM),a
        ld      hl,mp_cache             ; and no cell shows what the cache says
        ld      de,mp_cache + 1
        ld      bc,40 * 25 * 3 - 1
        ld      (hl),$40
        ldir
        ret

; void plat_exit(void)
        PUBLIC  _plat_exit
_plat_exit:
        ret

; The doubled four pixels of each nibble
        SECTION rodata_user
mp_nibbles:
        defb    $00,$03,$0C,$0F,$30,$33,$3C,$3F,$C0,$C3,$CC,$CF,$F0,$F3,$FC,$FF

; What each cell shows (40 x 25 of three bytes), in the RAM under the screen: only looked at with that RAM paged in
        SECTION bss_user
mp_cache: defs  40 * 25 * 3

; The cell in hand, in the low RAM (see the top)
        SECTION data_user
mp_m:    defs   4                       ; the planes drawn each way
mp_pix:  defs   16                      ; the picture doubled across: two bytes a row
mp_pix3: defs   48                      ; a baked picture doubled across: the three planes, sixteen bytes each
mp_scr:  defw   0
mp_held: defb   0                       ; the code of the key that is down, or 0
mp_event: defb  0                       ; the key pressed since plat_key last looked, or 0 ...
mp_flags: defb  0                       ; ... and the flags (bit 7: shift) when it was
