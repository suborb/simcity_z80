; Samsung SPC-1500 platform (z88dk +spc1500, all RAM: the program is at $0000): the game draws pictures and text itself.  Derived from the Sharp X1's (target/x1/plat_x1.asm):
; the SPC-1500's video is the X1's.
;
; The screen is the 40 column mode's graphics: three planes (blue, red, green: a Spectrum attribute's bit order) of 40 bytes a pixel row,
; 200 rows, 8 pixels a byte, so a game cell is 8x8 pixels, a byte wide.  The planes are not in the Z80's memory but behind I/O ports: OUT (C),A
; and IN A,(C) with B the high byte of the address.  Blue is at $4000, red at $8000 and green at $C000 (a plane is 16 KB); a pixel row y of
; the text row r is at (y mod 8) * $800 + r * 40 + column.  So the cell at offset o = row * 40 + col has its first line at $4000 + o and the
; next lines 8 on in the high byte; eight lines on is the next plane's first line, which lets 24 bytes (a baked picture: blue, red,
; green, eight lines each) go out in a row with B only ever incremented by 8.
;
; The keyboard is a matrix read at I/O port $1900 + row (rows 0 to 9, a bit set for a key down: keytab.inc, made by tools/spc1500_keys.py from MAME's table), polled by
; plat_key, which makes the keys repeat itself.  There is no interrupt: the frames are the vertical blank bit (port $1A01 bit 7).
;
; Arguments are the game's C calling convention (smallc).  A cell's attribute is the Spectrum's: ink in bits 0-2, paper in 3-5.  A plane's
; byte for a line, from the picture g, is (g AND (ink XOR paper)) XOR paper, each of those a bit of the attribute made into a mask.

        SECTION code_user
        EXTERN  _font_8x8_bbc_system
        EXTERN  _view_tile_art          ; picture n is at 8 * n from it
        IFDEF   HAVE_SOUND
        EXTERN  ay_poll, ay_sync, ay_tick, snd_init
        ENDIF

        defc    TEXT_ATTR = 7           ; white on black
        defc    MAP_ROW = 6             ; the map's cell rows: the only ones with a cache entry
        defc    MAP_ROWS = 19

; The baked map pictures
        SECTION data_fcntl
mp_tiles:
        BINARY  "build/common/tiles_640x200_3bpp.bin"

; The 14 tool icons of the Amstrad CPC game: four cells each, see tools/extract_cpc_icons.py
        SECTION rodata_user
        PUBLIC  _mp_icons
_mp_icons:
        BINARY  "assets/cpc_icons.bin"

        SECTION code_user

; The cell's 24 bytes from de (blue, red, green: eight lines each) to the screen cell mp_scr.  Uses all but IX.
mp_draw:
        ld      hl,(mp_scr)
        ld      a,h
        or      $40
        ld      b,a
        ld      c,l
        call    mp_plane8
        call    mp_plane8
        call    mp_plane8
        IFDEF   HAVE_SOUND
        jp      ay_poll                 ; (the sound's ticks go on while the screen is drawn)
        ELSE
        ret
        ENDIF
mp_plane8:
        REPT    8
        ld      a,(de)
        inc     de
        out     (c),a
        ld      a,b
        add     a,8
        ld      b,a
        ENDR
        ret

; a = row, b = col: hl and mp_scr = the cell's offset, row * 40 + col.  Uses a, hl.
mp_scraddr:
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
        ld      e,b
        ld      d,0
        add     hl,de
        ld      (mp_scr),hl
        pop     de
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
        ld      de,mp_tiles
        add     hl,de
        ex      de,hl                   ; de = its planes
        pop     bc
        pop     af
mp_pl_go:
        bit     0,c
        jr      z,mp_pl_draw
        push    af                      ; the complement into mp_pix3
        push    bc
        ld      hl,mp_pix3
        ld      b,24
mp_cpl:
        ld      a,(de)
        cpl
        ld      (hl),a
        inc     de
        inc     hl
        djnz    mp_cpl
        pop     bc
        pop     af
        ld      de,mp_pix3
mp_pl_draw:
        call    mp_scraddr
        jp      mp_draw

; void mp_planar(uint8_t col, uint8_t row, const uint8_t *planes, uint8_t inverse) __smallc
; A cell from 24 bytes: a plane (blue, red, green) of eight lines after another, as plat_put_tile draws the map's pictures (the complement if
; `inverse`).  Not cached: the icons are not in the map.
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
        jr      mp_cell_nc

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
        ld      de,mp_pix3
        jp      mp_draw

; The art at mp_src in the colours of mp_attr, as three planes of eight lines in mp_pix3.
mp_build:
        ld      de,mp_pix3
        ld      a,3
mp_bd_pl:
        ld      (mp_pn),a
        ld      a,(mp_attr)
        ld      b,a
        and     1
        ld      c,a                     ; the ink bit
        ld      a,b
        rrca
        rrca
        rrca
        and     1
        ld      b,a                     ; the paper bit
        xor     c
        neg
        ld      c,a                     ; ink xor paper, a mask
        ld      a,b
        neg
        ld      b,a                     ; paper, a mask
        ld      hl,(mp_src)
        REPT    8
        ld      a,(hl)
        inc     hl
        and     c
        xor     b
        ld      (de),a
        inc     de
        ENDR
        ld      hl,mp_attr
        srl     (hl)                    ; the next plane's bits
        ld      a,(mp_pn)
        dec     a
        jr      nz,mp_bd_pl
        ret

; void plat_text_attr(uint8_t col, uint8_t row, uint8_t n, uint8_t attr) __smallc
; Recolours n cells of text already drawn: the glyph is read back from the blue plane (where it was drawn white) and drawn again in the
; attribute's ink and paper.
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
        call    mp_forget
        call    mp_scraddr
        ld      a,h
        or      $40
        ld      b,a
        ld      c,l
        ld      de,mp_g8
        REPT    8
        in      a,(c)
        ld      (de),a
        inc     de
        ld      a,b
        add     a,8
        ld      b,a
        ENDR
        ld      a,(mp_ta + 2)
        ld      b,a
        ld      a,(mp_ta + 1)
        ld      de,mp_g8
        ld      hl,mp_ta + 3
        ld      c,(hl)
        call    mp_cell_nc
        ld      hl,mp_ta + 2
        inc     (hl)
        ld      hl,mp_ta
        dec     (hl)
        jr      nz,ta_cell
        ret

; void plat_put_overlay(uint8_t col, uint8_t row, const uint8_t *art) __smallc
; The pixels set in 8 bytes of art, white, over the cell: a sprite.
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
        call    mp_forget
        call    mp_scraddr
        ld      a,h
        or      $40
        ld      b,a
        ld      c,l
        call    mp_or8
        call    mp_or8
mp_or8:
        ld      de,(mp_src)
        REPT    8
        ld      a,(de)
        inc     de
        ld      l,a
        in      a,(c)
        or      l
        out     (c),a
        ld      a,b
        add     a,8
        ld      b,a
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
        ld      d,(hl)
        inc     hl
        ld      a,(hl)
        inc     hl
        inc     hl
        ld      b,(hl)
        ld      c,TEXT_ATTR
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

; The CRTC, the 8255's port C, the palette and priority, and the text layer cleared: plat_init, and again after the IPL ROM's own routines (the tape's, plat_files.asm) have been
; at the screen with the ROM's console
mp_hw_reset:
        ld      hl,mp_crtc              ; CRTC registers 0 to 13
        ld      bc,$1800
        ld      d,0
        ld      e,14
mp_crtc_lp:
        out     (c),d
        inc     c
        ld      a,(hl)
        out     (c),a
        dec     c
        inc     hl
        inc     d
        dec     e
        jr      nz,mp_crtc_lp
        ld      bc,$1A02                ; 8255 port C as the IPL leaves it for 40 columns
        ld      a,$F2
        out     (c),a
        ld      bc,$1000                ; the palette: colour n is the planes' bits n (blue $AA, red $CC, green $F0)
        ld      a,$AA
        out     (c),a
        ld      b,$11
        ld      a,$CC
        out     (c),a
        ld      b,$12
        ld      a,$F0
        out     (c),a
        ld      bc,$1300                ; the graphics over the text everywhere
        ld      a,$FF
        out     (c),a
        ld      bc,$2000                ; the text layer: attributes and codes 0 (nothing over the graphics),
        xor     a
        call    mp_fill_text
        ld      bc,$3000
        xor     a
        call    mp_fill_text
        ret

; void plat_init(void): the 40 column mode, the palette, the text layer blank
        PUBLIC  _plat_init
        PUBLIC  mp_hw_reset
_plat_init:
        di                              ; (nothing here uses the interrupt)
        call    mp_hw_reset
        ld      a,(mp_up)
        or      a
        jr      nz,_plat_clear
        inc     a
        ld      (mp_up),a
        IFDEF   HAVE_SOUND
        call    snd_init
        ENDIF
        ; fall into plat_clear

; void plat_clear(void): the three planes to 0 (the whole of each 16 KB, whether or not the screen shows it)
        PUBLIC  _plat_clear
        PUBLIC  _plat_text_clear
_plat_text_clear:
_plat_clear:
        ld      bc,$4000
        xor     a
mp_clear_lp:
        REPT    16
        out     (c),a
        inc     c
        ENDR
        jr      nz,mp_clear_lp
        inc     b
        jr      nz,mp_clear_lp
        ld      hl,mp_cache             ; and no cell shows what the cache says
        ld      de,mp_cache + 1
        ld      bc,40 * MAP_ROWS * 2 - 1
        ld      (hl),$FF
        ldir
        ret

; 2048 bytes of a to the I/O addresses from bc on
mp_fill_text:
        ld      l,a
        ld      de,2048
mp_ft:
        ld      a,l
        out     (c),a
        inc     bc
        dec     de
        ld      a,d
        or      e
        jr      nz,mp_ft
        ret

; uint8_t plat_key(void): the key pressed since the last call, or 0.  The matrix is scanned for the first key down that has a code (keytab.inc); a key just
; pressed is returned at once and, if it stays down, again after 20 frames and every 3 on (frames counted by plat_idle).  Shift and a cursor key are the far cursor codes.
        PUBLIC  _plat_key
_plat_key:
        ld      bc,$1900                ; shift
        in      a,(c)
        and     $02
        ld      (mp_shift),a
        ld      hl,mp_keytab
        ld      d,0
mp_kr:
        ld      b,$19
        ld      c,d
        in      a,(c)
        ld      e,a                     ; the row's bits
        ld      b,8
mp_kb:
        srl     e
        jr      nc,mp_kn
        ld      a,(hl)
        or      a
        jr      nz,mp_kfound
mp_kn:
        inc     hl
        djnz    mp_kb
        inc     d
        ld      a,d
        cp      10
        jr      nz,mp_kr
        xor     a                       ; no key down
        ld      (mp_last),a
        ld      l,a
        ld      h,a
        ret
mp_kfound:
        ld      c,a
        ld      a,(mp_shift)
        or      a
        ld      a,c
        jr      z,mp_k_ns
        cp      8
        jr      c,mp_k_ns
        cp      12
        jr      nc,mp_k_ns
        add     a,20                    ; 8 -> 28 left, 9 -> 29 right, 10 -> 30 down, 11 -> 31 up
mp_k_ns:
        ld      hl,mp_last
        cp      (hl)
        jr      z,mp_krep
        ld      (hl),a                  ; a new key: reported now
        push    af
        ld      hl,(mp_clock)
        ld      de,20
        add     hl,de
        ld      (mp_rep),hl
        pop     af
        ld      l,a
        ld      h,0
        ret
mp_krep:                                ; still down: again when the deadline has passed
        ld      hl,(mp_clock)
        ld      de,(mp_rep)
        or      a
        sbc     hl,de
        jr      c,mp_kzero
        ld      hl,(mp_clock)
        ld      de,3
        add     hl,de
        ld      (mp_rep),hl
        ld      a,(mp_last)
        ld      l,a
        ld      h,0
        ret
mp_kzero:
        ld      hl,0
        ret

; uint16_t plat_clock(void), void plat_idle(void): a count of the frames the game has waited for, and a wait for the next one (the
; display's vertical blank bit, port $1A01 bit 7, each half bounded in case it is not what it seems)
        PUBLIC  _plat_clock
_plat_clock:
        ld      hl,(mp_clock)
        ret
        PUBLIC  _plat_idle
_plat_idle:
        ld      hl,(mp_clock)
        inc     hl
        ld      (mp_clock),hl
        IFDEF   HAVE_SOUND
        ld      de,3000                 ; the next frame: the sound's tick (bounded)
mp_vs0:
        push    de
        call    ay_sync
        pop     de
        jr      z,mp_vs_tick
        dec     de
        ld      a,d
        or      e
        jr      nz,mp_vs0
        ret
mp_vs_tick:
        jp      ay_tick
        ELSE
        ld      bc,$1A01
        ld      de,3000
mp_vs0:
        in      a,(c)
        rla
        jr      nc,mp_vs1
        dec     de
        ld      a,d
        or      e
        jr      nz,mp_vs0
mp_vs1:
        ld      de,3000
mp_vs2:
        in      a,(c)
        rla
        ret     c
        dec     de
        ld      a,d
        or      e
        jr      nz,mp_vs2
        ret
        ENDIF

        PUBLIC  _plat_flush
        PUBLIC  _plat_exit
_plat_flush:
_plat_exit:
        ret

; void plat_put_minirow(uint8_t ty, const uint8_t *colours, const uint8_t *base, uint8_t view) __smallc
; Draws tile row ty (0..95) of the mini map from its 96 colours (bit 0 blue, 1 red, 2 green), one a tile column.  A tile is 2 pixels wide and
; 2 lines high, so a row is 192 pixels (24 bytes a plane) by two lines, lines 2 ty and 2 ty + 1, from the left of the screen.  base and view
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
        ld      a,l
        and     3
        add     a,a
        add     a,a
        add     a,a
        add     a,a                     ; (ty mod 4) * 16: its two lines are 2 * (ty mod 4) lines down the text row, $800 each
        ld      h,a
        ld      a,l
        srl     a
        srl     a                       ; the text row
        ld      l,a
        ld      a,h
        ld      h,0
        add     hl,hl
        add     hl,hl
        add     hl,hl                   ; row * 8
        ld      b,h
        ld      c,l
        add     hl,hl
        add     hl,hl                   ; row * 32
        add     hl,bc                   ; row * 40
        ld      b,a
        ld      c,0
        add     hl,bc                   ; + the line's $800s
        ld      (mm_dst),hl
        push    de
        ld      a,$AA                   ; the checker a tile of the base map (colour bit 3) is drawn in
        ld      (mm_pat),a
        ld      hl,mm_buf
        call    mm_pack3
        pop     de
        ld      a,$55                   ; the second line has the other half of it
        ld      (mm_pat),a
        call    mm_pack3
        ld      hl,mm_buf
        ld      (mm_src),hl
        ld      hl,(mm_dst)
        ld      a,h
        or      $40                     ; blue
        ld      h,a
        ld      (mm_dst),hl
        ld      a,3
mm_plane:
        ld      (mm_pn),a
        ld      bc,(mm_dst)
        ld      hl,(mm_src)
        call    mm_wr24                 ; the plane's first line,
        ld      hl,(mm_dst)
        ld      bc,$800
        add     hl,bc
        ld      b,h
        ld      c,l
        ld      hl,(mm_src)
        ld      de,72
        add     hl,de
        call    mm_wr24                 ; and the second, the other half of the checker
        ld      hl,(mm_src)
        ld      de,24
        add     hl,de
        ld      (mm_src),hl
        ld      hl,(mm_dst)
        ld      de,$4000
        add     hl,de
        ld      (mm_dst),hl
        ld      a,(mm_pn)
        dec     a
        jr      nz,mm_plane
        ret

; 24 bytes from hl to the I/O addresses from bc on
mm_wr24:
        ld      e,24
mm_w:
        ld      a,(hl)
        inc     hl
        out     (c),a
        inc     bc
        dec     e
        jr      nz,mm_w
        ret

; The three planes' 24 bytes each, from hl on, from the colours at de (kept: it is re-read for each plane, and de goes back)
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

; 24 bytes at hl from the 96 colours at de, for the plane of mask c: four tiles a byte, two bits each, the first in the high bits
mm_pack:
        ld      b,24
mm_pk:
        push    bc
        ld      b,0
        REPT    4
        ld      a,(de)
        inc     de
        call    mm_nib
        and     3
        sla     b
        sla     b
        or      b
        ld      b,a
        ENDR
        ld      (hl),b
        inc     hl
        pop     bc
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

        SECTION rodata_user
mp_crtc:                                ; the 40 column mode of the IPL (R0 to R3) with 8 line characters and 25 rows: R4 31 and R5 6 (262 lines), R6 25, R7 28, R9 7, the cursor off
        defb    $38,$28,$30,$44,$1F,$06,$19,$1C,$00,$07,$20,$07,$00,$00
mp_keytab:
        INCLUDE "target/spc1500/keytab.inc"

; What each map cell shows (40 x 19 words)
        SECTION bss_user
mp_cache: defs  40 * MAP_ROWS * 2

        SECTION code_user
mp_up:   defb   0                       ; plat_init has run
mp_attr: defb   0                       ; the cell's attribute (shifted a plane at a time by mp_build)
mp_src:  defw   0                       ; the art being drawn
mp_scr:  defw   0                       ; the cell's offset
mp_clock: defw  0
mp_shift: defb  0                       ; plat_key: shift is down
mp_last: defb   0                       ; the key plat_key last returned and that is still down
mp_rep:  defw   0                       ; the frame it repeats at
mp_ta:   defs   4                       ; plat_text_attr: the count, the row, the column and the attribute
mp_pn:   defb   0                       ; the plane being built
mp_g8:   defs   8                       ; plat_text_attr: the glyph read back
mp_pix3: defs   24                      ; a cell's three planes as drawn
; The line pieces of the boxes' frames, pipes two pixels thick with rounded corners: 1 top left, 2 top right, 3 bottom left, 4 bottom
; right, 5 across, 6 down (codes the frames' strings in plat_config.h have, below the space: mp_char takes them for these)
mp_box:
        defb    $00,$00,$00,$0F,$1F,$18,$18,$18
        defb    $00,$00,$00,$F0,$F8,$18,$18,$18
        defb    $18,$18,$18,$1F,$0F,$00,$00,$00
        defb    $18,$18,$18,$F8,$F0,$00,$00,$00
        defb    $00,$00,$00,$FF,$FF,$00,$00,$00
        defb    $18,$18,$18,$18,$18,$18,$18,$18
mm_buf:  defs   144                     ; the mini map row: two lines of three planes, 24 bytes each
mm_pat:  defb   0                       ; the checker a tile of the base map is drawn in on this line
mm_dst:  defw   0                       ; the row's first line in the blue plane, as an I/O address
mm_src:  defw   0
mm_pn:   defb   0
