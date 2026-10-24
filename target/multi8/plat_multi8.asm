; Mitsubishi Multi 8 platform (all-RAM mode, see -subtype=64k): the game draws pictures and text itself.
;
; The screen is three planes (blue, red, green: the bit order of a Spectrum attribute) of 80 bytes to a pixel row,
; 200 rows, 640 pixels across, and its pixels are twice as tall as they are wide.  The game's 8x8 cells are drawn
; with every pixel doubled across, so a cell is 16x8 hardware pixels, two bytes by eight rows, and the 40 columns
; fill the width.  A cell's first byte is
;     $8000 + row * 640 + col * 2          and the rest of its pixel rows are 80 bytes apart in each plane.
; The planes are paged in over $8000-$BFFF by port $2A (bits 0-3 are active low, one for each plane; bit 4 is set
; to see the planes and clear for the RAM underneath, where the uninitialised data lives), so nothing in
; $8000-$BFFF can be read or written while a plane is paged in: the routines' own variables are in the code section
; (at the end of this file), which is in the low RAM.  Interrupts are off (the startup code does that).
;
; Besides attribute cells it draws the map's pictures (plat_put_tile: baked in the machine's colours, no attributes), the
; sprites over them (plat_put_overlay) and the mini map's rows (plat_put_minirow: native pixels, written to the planes
; directly).  Each routine reads the keyboard when it is done (mp_keyscan).
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
        defc    MAP_ROW = 6             ; the map's cell rows: the only ones with a cache entry
        defc    MAP_ROWS = 19
        defc    TEXT_ATTR = 7           ; white on black

; The baked map pictures, in the image after the variables (so that those stay in the low RAM, which the code and the
; variables must while a plane is paged over $8000-$BFFF): the pictures are read only with the RAM under the planes paged in
        SECTION data_fcntl
mp_tiles:
        BINARY  "build/common/tiles_640x200_3bpp.bin"

; The 14 tool icons of the Amstrad CPC game: four cells each, a cell 8 rows of two bytes (the pens' low and high bits), see
; tools/extract_cpc_icons.py
        SECTION rodata_user
        PUBLIC  _mp_icons
_mp_icons:
        BINARY  "assets/cpc_icons.bin"

        SECTION code_user

; void plat_put_tile(uint8_t col, uint8_t row, const uint8_t *art, uint8_t attr, uint8_t inverse) __smallc
; One of the map's pictures: art points into the engine's art table, which says which (picture n is at
; _view_tile_art + 8 * n), and the picture is drawn from mp_tiles, where it is baked in the Multi 8's colours: 24 bytes,
; a plane (blue, red, green) of eight pixel rows after another (tools/extract_cpc_tiles.py).  The attribute is not
; used.  `inverse` draws the complement, which is the cursor.
        IFDEF   HAVE_SOUND
        EXTERN  snd_init, ay_poll
        ENDIF
        PUBLIC  _plat_put_tile
_plat_put_tile:
        ld      hl,2
        add     hl,sp
        ld      a,(hl)                  ; inverse
        ld      c,0                     ; the cache's key for this: the inverse flag
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
mp_pl_go:
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
        IFDEF   HAVE_SOUND
        call    ay_poll                 ; (the sound's ticks go on while the screen is drawn)
        ENDIF
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

; void mp_planar(uint8_t col, uint8_t row, const uint8_t *planes, uint8_t inverse) __smallc
; A cell from 24 bytes: a plane (blue, red, green) of eight rows after another, as plat_put_tile draws the map's pictures
; (the complement if `inverse`).  Not cached: the icons are not in the map.
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
        jp      mp_pl_go

; void mp_tile1(uint8_t col, uint8_t row, const uint8_t *art, uint8_t attr, uint8_t inverse) __smallc
; The 8 bytes of art, in the colours of attr (ink and paper swapped if `inverse`): the icons.
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
        call    mp_forget
        jr      mp_cell_nc

; A map cell that already shows this picture is left alone: mp_cache has a word for each cell of the map, its art address
; xor the inverse flag (art addresses differ by 8 or more), or $FFFF if it shows something else.  a = row, b = col, c = inverse, de = art.  Carry if it
; is as wanted; else the entry is updated.  Keeps a, b, c, de.
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
        add     hl,hl                   ; row * 8
        ld      d,h
        ld      e,l
        add     hl,hl
        add     hl,hl                   ; row * 32
        add     hl,de                   ; row * 40
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

; The cell shows something the cache does not know: forget it.  Keeps a, b, c, de.
mp_forget:
        call    mp_entry
        ret     c
        ld      (hl),$FF
        inc     hl
        ld      (hl),$FF
        ret

; Other drawing in a cell: the cache no longer applies
mp_cell:
        call    mp_forget
mp_cell_nc:
        call    mp_scraddr
        ld      a,c                     ; ink == paper: a plain fill, with no picture to draw
        rrca
        rrca
        rrca
        xor     c
        and     7
        jp      z,mp_solid
        push    de                      ; the art, for after the planes are worked out
        call    mp_mk_m
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

; Which planes are drawn which way for the attribute in c: mp_m[k] gets the bit of each plane whose ink bit is k & 1, paper bit k >> 1.
mp_mk_m:
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
        ret

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
        jp      mp_draw

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

; void plat_text_attr(uint8_t col, uint8_t row, uint8_t n, uint8_t attr) __smallc
; Recolours n cells of text already drawn (white on black): the cell's blue plane has the glyph (all three have), so it is read back
; and drawn again in the attribute's ink and paper.
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
        ld      a,(mp_ta + 2)
        ld      b,a
        ld      a,(mp_ta + 1)
        ld      hl,mp_ta + 3
        ld      c,(hl)
        call    mp_scraddr              ; (a = row, b = col)
        ld      a,$3E
        out     (PORT_MEM),a            ; the blue plane
        ld      hl,(mp_scr)
        ld      de,mp_pix
        ld      b,8
ta_rd:
        ld      a,(hl)
        ld      (de),a
        inc     hl
        inc     de
        ld      a,(hl)
        ld      (de),a
        inc     de
        ld      a,79
        add     a,l
        ld      l,a
        jr      nc,ta_nc
        inc     h
ta_nc:
        djnz    ta_rd
        ld      a,MEM_IDLE
        out     (PORT_MEM),a
        ld      a,(mp_ta + 3)
        ld      c,a
        call    mp_mk_m
        call    mp_draw                 ; (it ends in mp_keyscan, which returns)
        ld      hl,mp_ta + 2
        inc     (hl)
        ld      hl,mp_ta
        dec     (hl)
        jr      nz,ta_cell
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
        call    mp_forget               ; the cell no longer shows what the cache says
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
        IFDEF   HAVE_SOUND
        call    snd_init                ; (the sound's frame clock)
        ENDIF
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
        ld      bc,40 * MAP_ROWS * 2 - 1
        ld      (hl),$FF
        ldir
        ret

        IFDEF   HAVE_MINIMAP_ART
; void plat_put_minirow(uint8_t sy) __smallc
; Draws row sy (0..47) of the mini map from mm_row, which target/common/minimap_640x200_3bpp.asm has filled in: for each plane, its three
; lines of 48 bytes go to lines MM_LINE0 + 3 sy to + 2 of that plane, MM_BYTE bytes in from the left.  A tile is 4 pixels by
; 3 lines.
        EXTERN  _mm_row
        defc    MM_LINE0 = 52           ; the map is 144 lines, centred in the 152 below the status panel
        defc    MM_BYTE = 16            ; (80 - 48) / 2: centred
        PUBLIC  _plat_put_minirow
_plat_put_minirow:
        ld      hl,2
        add     hl,sp
        ld      l,(hl)                  ; sy
        ld      h,0
        ld      d,h
        ld      e,l
        add     hl,hl
        add     hl,hl
        add     hl,hl
        add     hl,hl                   ; 16 sy
        or      a
        sbc     hl,de                   ; 15 sy
        add     hl,hl
        add     hl,hl
        add     hl,hl
        add     hl,hl                   ; 240 sy: three lines of 80 bytes
        ld      de,SCREEN + MM_LINE0 * 80 + MM_BYTE
        add     hl,de
        ld      (mm_dst),hl
        ld      hl,_mm_row
        ld      (mm_src),hl
        xor     a
mm_art_pl:
        ld      (mm_msk),a              ; the plane: 0 blue, 1 red, 2 green
        ld      e,a
        ld      d,0
        ld      hl,mm_sel
        add     hl,de
        ld      a,(hl)
        out     (PORT_MEM),a            ; only this plane paged in
        ld      hl,(mm_src)
        ld      de,(mm_dst)
        ld      bc,48
        ldir
        ld      hl,(mm_dst)
        ld      de,80
        add     hl,de
        ex      de,hl
        ld      hl,(mm_src)
        ld      bc,48
        add     hl,bc
        ld      bc,48
        ldir
        ld      hl,(mm_dst)
        ld      de,160
        add     hl,de
        ex      de,hl
        ld      hl,(mm_src)
        ld      bc,96
        add     hl,bc
        ld      bc,48
        ldir
        ld      a,MEM_IDLE
        out     (PORT_MEM),a
        ld      hl,(mm_src)
        ld      de,144
        add     hl,de
        ld      (mm_src),hl
        ld      a,(mm_msk)
        inc     a
        cp      3
        jr      nz,mm_art_pl
        jp      mp_keyscan
mm_sel: defb    $3E, $3D, $3B           ; only the blue, red or green plane (see mp_one)

        ELSE
; void plat_put_minirow(uint8_t sy, const uint8_t *colours) __smallc
; Flat colour mode.  Draws row sy (0..47) of the mini map from 96 colours (bit 0 blue, 1 red, 2 green), one a tile column.  A
; tile is a block 4 pixels wide and 3 lines high, so a row is 384 pixels (48 bytes a plane) by 3 lines.  Each plane's 48
; bytes are made from the colours (two tiles to a byte), then written to the row's three lines.
        defc    MM_LINE0 = 52           ; the map is 144 lines, centred in the 152 below the status panel
        defc    MM_BYTE = 16            ; (80 - 48) / 2: centred
        PUBLIC  _plat_put_minirow
_plat_put_minirow:
        ld      hl,2
        add     hl,sp
        ld      e,(hl)
        inc     hl
        ld      d,(hl)                  ; de = the colours
        inc     hl
        ld      l,(hl)                  ; sy
        ld      h,0
        push    de
        ld      d,h
        ld      e,l
        add     hl,hl
        add     hl,hl
        add     hl,hl
        add     hl,hl                   ; 16 sy
        or      a
        sbc     hl,de                   ; 15 sy
        add     hl,hl
        add     hl,hl
        add     hl,hl
        add     hl,hl                   ; 240 sy: three lines of 80 bytes
        ld      de,SCREEN + MM_LINE0 * 80 + MM_BYTE
        add     hl,de
        ld      (mm_dst),hl
        ld      a,$AA                   ; the checker a tile of the base map (colour bit 3) is drawn in
        ld      (mm_pat),a
        pop     de
        ld      hl,mm_buf
        call    mm_pack3
        ld      a,$55                   ; the middle line has the other half of it
        ld      (mm_pat),a
        call    mm_pack3
        ld      hl,mm_buf
        ld      (mm_src),hl
        ld      a,1
mm_plane:
        ld      (mm_msk),a
        cpl
        and     7
        or      $38
        out     (PORT_MEM),a            ; only this plane paged in
        ld      de,(mm_dst)             ; the plane's 48 bytes to each of the three lines (nothing is read back from the plane)
        ld      hl,(mm_src)
        ld      bc,48
        ldir
        ld      hl,80
        ld      de,(mm_dst)
        add     hl,de
        ex      de,hl
        ld      hl,(mm_src)
        ld      bc,144
        add     hl,bc
        ld      bc,48
        ldir
        ld      hl,160
        ld      de,(mm_dst)
        add     hl,de
        ex      de,hl
        ld      hl,(mm_src)
        ld      bc,48
        ldir
        ld      hl,(mm_src)
        ld      de,48
        add     hl,de
        ld      (mm_src),hl
        ld      a,(mm_msk)
        add     a,a
        cp      8
        jr      nz,mm_plane
        ld      a,MEM_IDLE
        out     (PORT_MEM),a
        jp      mp_keyscan

; The three planes' 48 bytes each, from hl on, from the colours at de (kept)
mm_pack3:
        ld      c,1
mm_p3:
        push    de
        call    mm_pack
        pop     de
        sla     c
        ld      a,c
        cp      8
        jr      nz,mm_p3
        ret

; 48 bytes at hl from the 96 colours at de: for the plane of mask c, a byte is a nibble of ones for a tile that has
; the plane in its colour, then one for the next tile.  de goes on 96.
mm_pack:
        ld      b,48
mm_pk:
        ld      a,(de)
        inc     de
        call    mm_nib
        and     $F0
        ld      (hl),a
        ld      a,(de)
        inc     de
        call    mm_nib
        and     $0F
        or      (hl)
        ld      (hl),a
        inc     hl
        djnz    mm_pk
        ret

; a = $FF if the colour in a has the plane of mask c, else 0; a tile of the base map (bit 3 of the colour) gets the checker mm_pat of it
mm_nib:
        bit     3,a
        jr      nz,mm_dim
        and     c
        add     a,$FF
        sbc     a,a
        ret
mm_dim:
        and     c
        add     a,$FF
        sbc     a,a
        push    hl
        ld      hl,mm_pat
        and     (hl)
        pop     hl
        ret

        ENDIF

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
mp_cache: defs  40 * MAP_ROWS * 2

; The cell in hand, in the low RAM (see the top).  These are in the code section, not data_user: the program's initialised
; data is placed after the code and the strings, and grows over $8000 as the program does; the planes page over that.
        SECTION code_user
mp_m:    defs   4                       ; the planes drawn each way
; The line pieces of the boxes' frames, pipes two pixels thick with rounded corners: 1 top left, 2 top right, 3 bottom left, 4 bottom
; right, 5 across, 6 down (codes the frames' strings in plat_config.h have, below the space: mp_char takes them for these)
mp_box:
        defb    $00,$00,$00,$0F,$1F,$18,$18,$18
        defb    $00,$00,$00,$F0,$F8,$18,$18,$18
        defb    $18,$18,$18,$1F,$0F,$00,$00,$00
        defb    $18,$18,$18,$F8,$F0,$00,$00,$00
        defb    $00,$00,$00,$FF,$FF,$00,$00,$00
        defb    $18,$18,$18,$18,$18,$18,$18,$18
mp_ta:   defs   4                       ; plat_text_attr: the count, the row, the column and the attribute
mp_pix:  defs   16                      ; the picture doubled across: two bytes a row
mp_pix3: defs   48                      ; a baked picture doubled across: the three planes, sixteen bytes each
mp_scr:  defw   0
mp_held: defb   0                       ; the code of the key that is down, or 0
mp_event: defb  0                       ; the key pressed since plat_key last looked, or 0 ...
mp_flags: defb  0                       ; ... and the flags (bit 7: shift) when it was
mm_buf:  defs   288                     ; the flat-colour mini map row's three planes, 48 bytes each (the art mode has mm_row)
mm_pat:  defb   0                       ; the checker a tile of the base map is drawn in on this line: $AA, or $55 on the middle one
mm_dst:  defw   0                       ; where the row's first line starts in a plane
mm_msk:  defb   0                       ; the plane being written: 1, 2 or 4
mm_src:  defw   0                       ; its 48 bytes
