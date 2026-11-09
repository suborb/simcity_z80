; Sony SMC-777 platform (z88dk +smc777: a boot disc, the program at $0100): the game draws pictures and text itself.
;
; The screen is the 320x200 graphics mode: a nibble a pixel (the left pixel in the high nibble), 160 bytes a pixel row, so a game cell is 8x8
; pixels, four bytes wide.  The 32 KB of graphics RAM is not in the Z80's memory but behind I/O ports: OUT (C),A with C = $80 | the address's
; high byte (bits 8-14) and B its low byte.  A pixel row y of the text row r is at (y mod 8) * $1000 + r * 160 + the byte in the row, so the
; cell at row r, column c has its first line at r * 160 + c * 4 and the next lines $1000 on.  A line's four bytes go out with OUTI, which
; decrements B before the access: a picture is kept as eight lines of four bytes in reverse order (byte 3 first), B = the line's address + 4.
; The colours are the machine's digital ones, a nibble of blue 1, green 2 and red 4 (the pictures' colour numbers have red 2, green 4:
; mp_cmap and tools/smc777_tiles.py turn them about).
;
; The keyboard is an 8041's: port $1B has the status (bit 0: a key went down or repeats, bit 6: shift), port $1A the ASCII code.  The 60 Hz
; interrupt (port $21 bit 0 enables it) counts frames for plat_idle.
;
; Arguments are the game's C calling convention (smallc).  A cell's attribute is the Spectrum's: ink in bits 0-2, paper in 3-5.

        SECTION code_user
        EXTERN  _view_tile_art          ; picture n is at 8 * n from it

        defc    TEXT_ATTR = 7           ; white on black
        defc    MAP_ROW = 6             ; the map's cell rows: the only ones with a cache entry
        defc    MAP_ROWS = 19

; The baked map pictures: 32 bytes each
        SECTION rodata_user
mp_tiles:
        BINARY  "build/smc777/tiles4.bin"

; The font (96 glyphs from the space) and the 14 tool icons of the Amstrad CPC game (four cells each, see tools/extract_cpc_icons.py): plat_init
; copies them to the character generator's RAM (PCG, from $108: the glyph of the space, $100, stays blank), where the text is drawn from and
; mp_icon_fetch reads the icons, and the room they were in is the cache of what each map cell shows (40 x 19 words), which takes the first 1520
; bytes of the 1664.
mp_cache:
mp_store:
        BINARY  "assets/font_8x8_bbc_system.bin"
        BINARY  "assets/cpc_icons.bin"
        defc    STORE_SIZE = 768 + 896
        defc    STORE_END = $0108 + STORE_SIZE

; the digital colour of a colour number (bit 0 blue, 1 red, 2 green)
mp_cmap:
        defb    0,1,4,5,2,3,6,7

; the mini map's two lines of a tile, from its colour (bit 3: dimmed to a checker)
mm_tab:
        defb    $00,$00, $11,$11, $44,$44, $55,$55, $22,$22, $33,$33, $66,$66, $77,$77
        defb    $00,$00, $10,$01, $40,$04, $50,$05, $20,$02, $30,$03, $60,$06, $70,$07

        SECTION code_user

; The cell's 32 bytes from de (eight lines of four bytes, the last first) to the screen cell mp_scr.  Uses all but IX.
mp_draw:
        ld      hl,(mp_scr)
        ex      de,hl                   ; hl = the picture, de = the cell's offset
        ld      a,e
        add     a,4
        ld      e,a                     ; e = the line's B
        ld      a,d
        or      $80
        ld      c,a
        ld      b,e
        REPT    8
        outi
        outi
        outi
        outi
        ld      b,e
        ld      a,c
        add     a,$10
        ld      c,a
        ENDR
        ret

; a = row, b = col: hl and mp_scr = the cell's offset, row * 160 + col * 4.  Uses a, hl.
mp_scraddr:
        push    de
        ld      l,a
        ld      h,0
        add     hl,hl
        add     hl,hl
        add     hl,hl
        add     hl,hl
        add     hl,hl                   ; row * 32
        ld      d,h
        ld      e,l
        add     hl,hl
        add     hl,hl                   ; row * 128
        add     hl,de                   ; row * 160
        ld      a,b
        add     a,a
        add     a,a                     ; col * 4 (under 160)
        ld      e,a
        ld      d,0
        add     hl,de
        ld      (mp_scr),hl
        pop     de
        ret

; void plat_put_tile(uint8_t col, uint8_t row, const uint8_t *art, uint8_t attr, uint8_t inverse) __smallc
; A map picture: art is _view_tile_art + 8 * n, drawn from mp_tiles (32 bytes a picture).  The attribute is not used; `inverse` draws the
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
        add     hl,hl
        add     hl,hl                   ; 32 * n
        ld      de,mp_tiles
        add     hl,de
        ex      de,hl                   ; de = its pixels
        pop     bc
        pop     af
mp_pl_go:
        bit     0,c
        jr      z,mp_pl_draw
        push    af                      ; the complement into mp_pix
        push    bc
        ld      hl,mp_pix
        ld      b,32
mp_cpl:
        ld      a,(de)
        xor     $77
        ld      (hl),a
        inc     de
        inc     hl
        djnz    mp_cpl
        pop     bc
        pop     af
        ld      de,mp_pix
mp_pl_draw:
        call    mp_scraddr
        jp      mp_draw

; void mp_planar(uint8_t col, uint8_t row, const uint8_t *planes, uint8_t inverse) __smallc
; A cell from 24 bytes: a plane (blue, red, green) of eight lines after another (the complement if `inverse`).  Not cached: the icons are
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
        call    mp_expand
        pop     bc
        pop     af
        ld      de,mp_pix2
        jr      mp_pl_go

; de = 24 bytes, a plane (blue, red, green) of eight lines after another: mp_pix2 = the cell as drawn.  Uses all but IX.
mp_expand:
        push    ix
        push    de
        pop     ix
        ld      hl,mp_pix2
        ld      a,8
        ex      af,af'
mp_x_ln:
        ld      b,(ix+0)                ; blue,
        ld      d,(ix+8)                ; red
        ld      e,(ix+16)               ; and green of the line
        inc     ix
        call    mp_x_byte
        call    mp_x_byte
        call    mp_x_byte
        call    mp_x_byte
        ex      af,af'
        dec     a
        jr      z,mp_x_done
        ex      af,af'
        jp      mp_x_ln
mp_x_done:
        pop     ix
        ret

; a byte of the line (two pixels, the right one first: the bytes are kept last first) from the planes in b, d and e
mp_x_byte:
        xor     a
        srl     d
        rla
        srl     e
        rla
        srl     b
        rla                             ; red 4, green 2, blue 1
        ld      c,a
        xor     a
        srl     d
        rla
        srl     e
        rla
        srl     b
        rla
        add     a,a
        add     a,a
        add     a,a
        add     a,a
        or      c
        ld      (hl),a
        inc     hl
        ret

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
        push    af
        dec     a
        cp      2
        jr      nc,mp_fg_no             ; rows 1 and 2, columns 0 to 27: the tool icons, which are no longer as they were drawn
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
        ld      de,mp_pix
        jp      mp_draw

; The art at mp_src in the colours of mp_attr, as the cell mp_pix.
mp_build:
        push    ix
        ld      a,(mp_attr)
        and     7
        call    mp_nib
        ld      c,a                     ; the ink
        ld      a,(mp_attr)
        rrca
        rrca
        rrca
        and     7
        call    mp_nib
        ld      b,a                     ; the paper
        ld      a,c
        add     a,a
        add     a,a
        add     a,a
        add     a,a
        or      c
        ld      d,a                     ; the ink in both nibbles
        ld      a,b
        add     a,a
        add     a,a
        add     a,a
        add     a,a
        or      b
        ld      b,a                     ; the paper in both
        xor     d
        ld      d,a                     ; where they differ: a pixel's byte is b xor (d and its mask)
        ld      ix,(mp_src)
        ld      hl,mp_pix
        ld      a,8
        ex      af,af'
mp_bl_ln:
        ld      c,(ix+0)
        inc     ix
        call    mp_bl_byte
        call    mp_bl_byte
        call    mp_bl_byte
        call    mp_bl_byte
        ex      af,af'
        dec     a
        jr      z,mp_bl_done
        ex      af,af'
        jp      mp_bl_ln
mp_bl_done:
        pop     ix
        ret

; a byte of the glyph line in c (two pixels, the right one first), the ink and paper in d and b
mp_bl_byte:
        rrc     c
        sbc     a,a
        and     $0F
        ld      e,a
        rrc     c
        sbc     a,a
        and     $F0
        or      e
        and     d
        xor     b
        ld      (hl),a
        inc     hl
        ret

; a = the colour number (0-7): a = its digital colour.  Uses hl, de.
mp_nib:
        ld      e,a
        ld      d,0
        ld      hl,mp_cmap
        add     hl,de
        ld      a,(hl)
        ret

; void plat_text_attr(uint8_t col, uint8_t row, uint8_t n, uint8_t attr) __smallc
; Recolours n cells of text already drawn: the glyph is read back from the screen (where it was drawn white on black: a pixel is set if its
; nibble is) and drawn again in the attribute's ink and paper.
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
        ld      e,l                     ; the first line's B
        ld      a,h
        or      $80
        ld      c,a
        ld      hl,mp_g8
        ld      a,8
        ex      af,af'
ta_ln:
        ld      b,e
        ld      d,0
        call    ta_byte
        call    ta_byte
        call    ta_byte
        call    ta_byte
        ld      (hl),d
        inc     hl
        ld      a,c
        add     a,$10
        ld      c,a
        ex      af,af'
        dec     a
        jr      z,ta_read
        ex      af,af'
        jp      ta_ln
ta_read:
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

; a byte of the screen line read back: two pixels of the glyph into d (the left byte first)
ta_byte:
        in      a,(c)
        cp      $10
        ccf
        rl      d                       ; the left pixel
        and     $0F
        cp      1
        ccf
        rl      d
        inc     b
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
        push    ix
        ld      ix,(mp_src)
        ld      a,l
        add     a,3
        ld      e,a                     ; the line's B: its last byte (IN and OUT use B as it is)
        ld      a,h
        or      $80
        ld      c,a
        ld      b,e
        ld      a,8
        ex      af,af'
mp_ov_ln:
        ld      d,(ix+0)
        inc     ix
        call    mp_ov_byte
        call    mp_ov_byte
        call    mp_ov_byte
        call    mp_ov_byte
        ld      b,e
        ld      a,c
        add     a,$10
        ld      c,a
        ex      af,af'
        dec     a
        jr      z,mp_ov_done
        ex      af,af'
        jp      mp_ov_ln
mp_ov_done:
        pop     ix
        ret

; a byte of the art line in d (two pixels, the right one first) ORed white into the screen byte at b
mp_ov_byte:
        rrc     d
        sbc     a,a
        and     $07
        ld      l,a
        rrc     d
        sbc     a,a
        and     $70
        or      l
        ld      l,a
        in      a,(c)
        or      l
        out     (c),a
        dec     b
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
        cp      ' '
        jp      z,mp_space
        push    bc                      ; the column and row
        ld      l,a
        ld      h,0
        add     hl,hl
        add     hl,hl
        add     hl,hl                   ; ch * 8
        ld      de,8                    ; the glyph is at $108 + (ch - 32) * 8
        add     hl,de
        ld      a,h
        or      $10
        ld      c,a
        ld      b,l
        ld      hl,mp_g8
        REPT    8
        in      a,(c)
        ld      (hl),a
        inc     hl
        inc     b
        ENDR
        pop     bc
        ld      de,mp_g8
        ld      a,c
        ld      c,TEXT_ATTR
        jp      mp_cell

; A space: b = col, c = row, a black cell (nothing to work out)
mp_space:
        ld      a,c
        call    mp_forget
        call    mp_scraddr
        ld      e,l                     ; the first line's B
        ld      a,h
        or      $80
        ld      c,a
        ld      a,8
        ex      af,af'
mp_bk_ln:
        ld      b,e
        xor     a
        out     (c),a
        inc     b
        out     (c),a
        inc     b
        out     (c),a
        inc     b
        out     (c),a
        ld      a,c
        add     a,$10
        ld      c,a
        ex      af,af'
        dec     a
        ret     z
        ex      af,af'
        jr      mp_bk_ln

; void mp_icon_fetch(uint8_t *dest, uint8_t n) __smallc
; The 16 bytes of the icon cell n (0 to 55) from the PCG RAM.
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
        ld      bc,$0108 + 96 * 8       ; the icons follow the font
        add     hl,bc
        ld      a,h
        or      $10
        ld      c,a
        ld      b,l
        ex      de,hl
        ld      d,16
mp_if:
        in      a,(c)
        ld      (hl),a
        inc     hl
        inc     b
        jr      nz,mp_if_nc
        inc     c
mp_if_nc:
        dec     d
        jr      nz,mp_if
        ret

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

; void plat_init(void): the mode, the text layer blank, the frame interrupt
        PUBLIC  _plat_init
_plat_init:
        di
        xor     a
        out     ($20),a                 ; 80 column text over the 320x200 graphics
        out     ($23),a                 ; the border black
        ld      c,$08                   ; the text layer: attributes (no ink, a transparent paper),
        call    mp_fill_text
        ld      c,$00
        ld      a,' '                   ; and spaces
        call    mp_fill_text
        ld      a,(mp_up)
        or      a
        jr      nz,mp_up_done
        inc     a
        ld      (mp_up),a
        xor     a                       ; the blank glyph of the space
        ld      c,$11
        ld      b,8
mp_blank:
        dec     b
        out     (c),a
        jr      nz,mp_blank
        ld      hl,mp_store             ; the font and the icons to the PCG RAM
        ld      de,$0108
mp_pcg:
        ld      a,d
        or      $10
        ld      c,a
        ld      b,e
        ld      a,(hl)
        out     (c),a
        inc     hl
        inc     de
        ld      a,d
        cp      STORE_END / 256
        jr      nz,mp_pcg
        ld      a,e
        cp      STORE_END % 256
        jr      nz,mp_pcg
        ld      a,195                   ; our frame interrupt (IM 1: the crt's jump to its own handler is replaced)
        ld      ($0038),a
        ld      hl,mp_isr
        ld      ($0039),hl
        ld      a,1
        out     ($21),a                 ; the frame interrupt on
mp_up_done:
        im      1
        ei
        ; fall into plat_clear

; void plat_clear(void): the 32 KB of graphics RAM to 0
        PUBLIC  _plat_clear
        PUBLIC  _plat_text_clear
_plat_text_clear:
_plat_clear:
        ld      c,$80
        xor     a
mp_clear_lp:
        ld      b,0
mp_cl:
        out     (c),a
        djnz    mp_cl
        inc     c
        jr      nz,mp_clear_lp
        ld      hl,mp_istate            ; no icon is on the screen,
        ld      de,mp_istate + 1
        ld      bc,13
        ld      (hl),0
        ldir
        ld      hl,mp_cache             ; and no cell shows what the cache says
        ld      de,mp_cache + 1
        ld      bc,40 * MAP_ROWS * 2 - 1
        ld      (hl),$FF
        ldir
        ret

; 2048 bytes of a to the text RAM: c = $00 for the characters, $08 for the attributes
mp_fill_text:
        ld      l,a
        ld      d,8
mp_ft_pg:
        ld      b,0
        ld      a,l
mp_ft:
        out     (c),a
        djnz    mp_ft
        inc     c
        dec     d
        jr      nz,mp_ft_pg
        ret

; The frame interrupt (the read of port $21 clears it)
mp_isr:
        push    af
        in      a,($21)
        push    hl
        ld      hl,(mp_vbl)
        inc     hl
        ld      (mp_vbl),hl
        pop     hl
        pop     af
        ei
        reti

; uint8_t plat_key(void): the key pressed since the last call, or 0.  The cursor keys are 8 left, 9 right, 10 down, 11 up (28 to 31 with
; shift: eight cells); letters are lower case.
        PUBLIC  _plat_key
_plat_key:
        in      a,($1B)
        ld      d,a                     ; the status
        ld      hl,0
        and     1
        ret     z
        in      a,($1A)
        cp      $80
        ret     nc                      ; (kana)
        ld      l,8
        cp      $16                     ; the cursor keys: $16 left, $19 right, $1C down, $17 up
        jr      z,mp_kc
        ld      l,9
        cp      $19
        jr      z,mp_kc
        ld      l,10
        cp      $1C
        jr      z,mp_kc
        ld      l,11
        cp      $17
        jr      z,mp_kc
        ld      l,a
        cp      'A'
        ret     c
        cp      'Z' + 1
        ret     nc
        or      $20                     ; letters in lower case
        ld      l,a
        ret
mp_kc:
        bit     6,d
        ret     z
        ld      a,l
        add     a,20                    ; 8 -> 28 left, 9 -> 29 right, 10 -> 30 down, 11 -> 31 up
        ld      l,a
        ret

; uint16_t plat_clock(void), void plat_idle(void): a count of the frames the game has waited for, and a wait for the next one (the frame
; interrupt's count changing, bounded in case it never comes)
        PUBLIC  _plat_clock
_plat_clock:
        ld      hl,(mp_clock)
        ret
        PUBLIC  _plat_idle
_plat_idle:
        ld      hl,(mp_clock)
        inc     hl
        ld      (mp_clock),hl
        ld      de,(mp_vbl)
        ld      bc,12000
mp_id:
        ld      hl,(mp_vbl)
        or      a
        sbc     hl,de
        ret     nz
        dec     bc
        ld      a,b
        or      c
        jr      nz,mp_id
        ret

        PUBLIC  _plat_flush
        PUBLIC  _plat_exit
_plat_flush:
_plat_exit:
        ret

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

; void plat_put_minirow(uint8_t ty, const uint8_t *colours, const uint8_t *base, uint8_t view) __smallc
; Draws tile row ty (0..95) of the mini map from its 96 colours (bit 0 blue, 1 red, 2 green), one a tile column.  A tile is 2 pixels wide and
; 2 lines high, so a row is 192 pixels (96 bytes) by two lines, lines 2 ty and 2 ty + 1, from the left of the screen.  base and view are not
; used: a tile of the city shown dim where a view has none comes in the colours as colour bit 3 (ui/game.c, HAVE_MINIMAP_FLAT_BASE), drawn
; as a checker.
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
        rrca
        rrca
        rrca                            ; (ty mod 4) * 32: its two lines are 2 * (ty mod 4) pixel rows down the text row, $1000 each
        ld      b,a
        ld      a,l
        srl     a
        srl     a                       ; the text row
        ld      l,a
        ld      h,0
        add     hl,hl
        add     hl,hl
        add     hl,hl
        add     hl,hl
        add     hl,hl                   ; row * 32
        push    de
        ld      d,h
        ld      e,l
        add     hl,hl
        add     hl,hl
        add     hl,de                   ; row * 160
        pop     de
        ld      a,h
        or      $80
        add     a,b
        ld      c,a
        ld      b,l
        ld      (mm_dst),bc
        push    ix
        ld      ix,mm_buf
        ld      a,96
        ld      (mm_cnt),a
mm_t:
        ld      a,(de)
        inc     de
        and     15
        add     a,a
        ld      c,a
        ld      b,0
        ld      hl,mm_tab
        add     hl,bc
        ld      a,(hl)
        ld      (ix+0),a                ; the first line's byte,
        inc     hl
        ld      a,(hl)
        ld      (ix+96),a               ; and the second's
        inc     ix
        ld      hl,mm_cnt
        dec     (hl)
        jr      nz,mm_t
        pop     ix
        ld      bc,(mm_dst)
        ld      hl,mm_buf
        call    mm_wr96
        ld      bc,(mm_dst)
        ld      a,c
        add     a,$10
        ld      c,a
        ld      hl,mm_buf + 96
mm_wr96:
        ld      e,96
mm_w:
        ld      a,(hl)
        inc     hl
        out     (c),a
        inc     b
        jr      nz,mm_nc
        inc     c
mm_nc:
        dec     e
        jr      nz,mm_w
        ret

        SECTION bss_user
mm_buf:  defs   192                     ; the mini map row: two lines of 96 bytes, and (the two are never wanted at once) the cells being drawn:
        defc    mp_pix = mm_buf         ; a cell as drawn
        defc    mp_pix2 = mm_buf + 32   ; a cell expanded from its planes
mp_istate: defs 14                      ; how each icon was drawn: bit 0 selected, 1 affordable, 2 it is on the screen (0: not known)

        SECTION code_user
mp_up:   defb   0                       ; plat_init has run: our interrupt is in
mp_attr: defb   0                       ; the cell's attribute
mp_src:  defw   0                       ; the art being drawn
mp_scr:  defw   0                       ; the cell's offset
mp_clock: defw  0
mp_vbl:  defw   0                       ; the frames the interrupt has counted
mp_ta:   defs   4                       ; plat_text_attr: the count, the row, the column and the attribute
mp_g8:   defs   8                       ; plat_text_attr: the glyph read back
mm_dst:  defw   0                       ; the row's first line, as the port address
mm_cnt:  defb   0
; The line pieces of the boxes' frames, pipes two pixels thick with rounded corners: 1 top left, 2 top right, 3 bottom left, 4 bottom
; right, 5 across, 6 down (codes the frames' strings in plat_config.h have, below the space: mp_char takes them for these)
mp_box:
        defb    $00,$00,$00,$0F,$1F,$18,$18,$18
        defb    $00,$00,$00,$F0,$F8,$18,$18,$18
        defb    $18,$18,$18,$1F,$0F,$00,$00,$00
        defb    $18,$18,$18,$F8,$F0,$00,$00,$00
        defb    $00,$00,$00,$FF,$FF,$00,$00,$00
        defb    $18,$18,$18,$18,$18,$18,$18,$18
