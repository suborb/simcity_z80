; Samsung SPC-1000 platform (z88dk +spc1000 -subtype=allram): the game draws pictures and text itself.
;
; The screen is the MC6847's 256x192 mode (RG6), one bit a pixel: a line is 32 bytes and a game cell is a byte wide and eight lines tall.  The video
; RAM is not in the Z80's memory but behind I/O ports (OUT (C),A with BC the address, 0 to $17FF), and the mode is port $2000.  Cell (col, row) line
; k is at row * 256 + k * 32 + col, so a cell's address is a high byte (the row) and a low byte that never carries from line to line.
;
; The keyboard is ten rows read with IN from $8000 + row; the table z88dk's in_Inkey uses gives each key's code (cursors 8 to 11, Enter 13, Esc 27,
; letters in lower case).  Arguments are the game's C calling convention (smallc).
;
; The pictures are the engine's own 1 bit art (the Spectrum's, with no colour): plat_put_tile draws the 8 bytes it is given.

        SECTION code_user
        EXTERN  _font_8x8_bbc_system
        EXTERN  in_keytranstbl, in_GetKey, _in_KeyDebounce, _in_KeyStartRepeat, _in_KeyRepeatPeriod
        IFDEF   HAVE_SOUND
        EXTERN  snd_init, _plat_frames
        ENDIF

        IFDEF   VRAM_FLAT                       ; (the host test, test/spc1000/flat.py: the video RAM is memory at VRAM_FLAT, and the keys are a script)
        defc    VRAM_BASE_HI = VRAM_FLAT / 256
        ENDIF
        defc    VRAM_MODE = $2000
        defc    MODE_RG6_WHITE = $8E            ; graphics (bit 3), GM1 and GM0 (bits 2-1: 256x192, one bit a pixel), colour set 1 (bit 7: white on black)
        defc    NUM_ICONS = 14
        defc    MAP_ROW = 6                     ; the map's cell rows (6 to 23): the only ones with a cache entry
        defc    MAP_ROWS = 18

; The tool icons: the Spectrum's, four 8x8 pictures each (top left, top right, bottom left, bottom right: the first 448 bytes of assets/udgs.bin)
        SECTION rodata_user
mp_icons:
        BINARY  "build/spc1000/icons.bin"

        SECTION code_user

; bc = a cell's first line (its row in b, its column in c), de = 8 bytes, h = what to xor them with.  Writes the eight lines.  Uses a, bc, de.
mp_cell8:
        ld      a,b
        cp      24
        IFDEF   VRAM_FLAT
        jr      c,mp_c8_ok
        ld      (mp_bad),a              ; (the host test: the row that was asked for)
        ret
mp_c8_ok:
        ELSE
        ret     nc
        ENDIF
        ;                               (below the screen: the video RAM ends at row 24, and the next addresses are other ports)
        IFDEF   VRAM_FLAT
        ld      a,b
        add     a,VRAM_BASE_HI
        ld      b,a
        ENDIF
        REPT    8
        ld      a,(de)
        xor     h
        IFDEF   VRAM_FLAT
        ld      (bc),a
        ELSE
        out     (c),a
        ENDIF
        inc     de
        ld      a,c
        add     a,32
        ld      c,a
        ENDR
        ret

; void plat_put_tile(uint8_t col, uint8_t row, const uint8_t *art, uint8_t attr, uint8_t inverse) __smallc
; A map picture: the 8 bytes of art, complemented (dark on light), or as they are if `inverse` (the cursor).  The attribute is not used.
        PUBLIC  _plat_put_tile
_plat_put_tile:
        ld      hl,2
        add     hl,sp
        ld      a,(hl)                  ; inverse (0 or 1)
        xor     1                       ; the map is dark on light (the text is light on dark): the cursor is the other way round
        neg
        ld      c,a                     ; $FF, or $00 for the cursor
        inc     hl
        inc     hl
        inc     hl
        inc     hl                      ; (past the attribute)
        ld      e,(hl)
        inc     hl
        ld      d,(hl)
        inc     hl
        ld      b,(hl)                  ; row
        inc     hl
        inc     hl
        ld      a,(hl)                  ; col
        ld      h,c
        ld      c,a
        call    mp_cached               ; a cell that already shows this picture is left alone
        ret     c
        jp      mp_cell8

; The map is not repainted: a cell is written only when its picture changes (constant writes to the video RAM, which the VDG is reading, show on
; the screen).  mp_cache has a word for each cell of the map: the art address xor 1 if it is drawn as it is (the cursor), or $FFFF.

; hl = the cache entry of the cell at row b, column c; carry if it is not in the map's rows.  Keeps bc and de; uses a.
mp_entry:
        ld      a,b
        sub     MAP_ROW
        ret     c
        cp      MAP_ROWS
        jr      c,mp_ent_in
        scf
        ret
mp_ent_in:
        ld      l,a
        ld      h,0
        add     hl,hl
        add     hl,hl
        add     hl,hl
        add     hl,hl
        add     hl,hl                   ; row * 32
        ld      a,l
        add     a,c
        ld      l,a
        jr      nc,mp_ent_nc
        inc     h
mp_ent_nc:
        add     hl,hl                   ; a word each
        push    de
        ld      de,mp_cache
        add     hl,de
        pop     de
        or      a
        ret

; The cell at row b, column c has the 8 bytes of art at de and the mask h (0, or $FF for the complement).  Carry if it shows that already;
; else the entry is updated.  Keeps bc, de and h.
mp_cached:
        ld      a,h
        ld      (mp_mask),a
        call    mp_entry
        jr      c,mp_c_draw             ; (not in the map: always drawn)
        push    de
        ld      a,(mp_mask)
        and     1
        xor     e
        ld      e,a                     ; de = the key
        ld      a,(hl)
        cp      e
        jr      nz,mp_c_new
        inc     hl
        ld      a,(hl)
        cp      d
        jr      nz,mp_c_new1
        pop     de
        ld      a,(mp_mask)
        ld      h,a
        scf
        ret
mp_c_new:
        ld      (hl),e
        inc     hl
mp_c_new1:
        ld      (hl),d
        pop     de
mp_c_draw:
        ld      a,(mp_mask)
        ld      h,a
        or      a
        ret

; The cell at row b, column c is about to show something else.  Keeps bc and de; uses a and hl.
mp_forget:
        call    mp_entry
        ret     c
        ld      (hl),$FF
        inc     hl
        ld      (hl),$FF
        ret

; void plat_put_bitmap(uint8_t col, uint8_t row, const uint8_t *art) __smallc
        PUBLIC  _plat_put_bitmap
_plat_put_bitmap:
        ld      hl,2
        add     hl,sp
        ld      e,(hl)
        inc     hl
        ld      d,(hl)
        inc     hl
        ld      b,(hl)                  ; row
        inc     hl
        inc     hl
        ld      c,(hl)                  ; col
        call    mp_forget
        ld      h,$FF                   ; (as the map's pictures: dark on light)
        jp      mp_cell8

; void plat_put(uint8_t col, uint8_t row, uint8_t ch) __smallc
; The character's glyph.
        PUBLIC  _plat_put
_plat_put:
        ld      hl,2
        add     hl,sp
        ld      a,(hl)                  ; ch
        inc     hl
        inc     hl
        ld      b,(hl)                  ; row
        inc     hl
        inc     hl
        ld      c,(hl)                  ; col
mp_char:
        ld      d,a
        ld      a,(_mp_cg)
        or      a
        jp      nz,mp_char_cg         ; (a mini map's sidebar: 4 pixel cells of the small font)
        ld      a,d
        push    af
        call    mp_forget
        pop     af
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
        ld      h,0
        jp      mp_cell8
mp_ch_font:
        and     $7F
        ld      l,a
        ld      h,0
        add     hl,hl
        add     hl,hl
        add     hl,hl                   ; ch * 8
        ld      de,_font_8x8_bbc_system - 32 * 8
        add     hl,de
        ex      de,hl                   ; de = its glyph
        ld      h,0
        jp      mp_cell8

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
        ld      b,(hl)                  ; row
        inc     hl
        inc     hl
        ld      c,(hl)                  ; col
mp_puts_next:
        ld      a,c
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
        inc     c
        jr      mp_puts_next


; ---- the mini maps: the MC6847's CG6 mode, 128x192 pixels in four colours (a byte is four pixels, a line is 32 bytes as in RG6) ----
; The map is 96 columns by 192 lines, a tile a pixel wide and two lines tall, 24 bytes a line, and the sidebar the other 8 bytes: a text cell is one
; byte wide (a 3x5 font, yellow on blue) and eight lines tall.  Colour set 0: 0 green, 1 yellow, 2 blue, 3 red.
        defc    MODE_CG6 = $0A                  ; graphics, GM1 (set 0)
        defc    CG_BG = $AA                     ; four blue pixels, the sidebar's ground

        PUBLIC  _mp_cg
_mp_cg: defb    0                               ; the screen is the CG6 mini map

; void plat_minimap_mode(uint8_t on): the mini map's mode (the screen has just been cleared when it is opened), or the text mode again
        PUBLIC  _plat_minimap_mode
_plat_minimap_mode:
        ld      hl,2
        add     hl,sp
        ld      a,(hl)
        ld      (_mp_cg),a
        or      a
        jr      nz,mp_mm_on
        IFNDEF  VRAM_FLAT
        ld      bc,VRAM_MODE
        ld      a,MODE_RG6_WHITE
        out     (c),a
        ENDIF
        ret
mp_mm_on:
        IFNDEF  VRAM_FLAT
        ld      bc,VRAM_MODE
        ld      a,MODE_CG6
        out     (c),a
        ENDIF
        ld      b,0                             ; the sidebar's columns 24 to 31 blue: eight bytes of the ground on each of the 192 lines
        ld      c,24
        ld      l,24                            ; the rows
mp_bg_row:
        ld      de,mp_cg_bg
        push    hl
        push    bc
        ld      h,$00
        call    mp_cell8                        ; (one cell: line k at b*256 + k*32 + c)
        pop     bc
        pop     hl
        inc     c
        ld      a,c
        cp      32
        jr      nz,mp_bg_row
        ld      c,24
        inc     b
        dec     l
        jr      nz,mp_bg_row
        ret
mp_cg_bg:
        defs    8,CG_BG

; a character cell of the sidebar: a = ch (kept in d), bc = row and column.  Eight bytes at mp_cgbuf, the ground at the top and bottom and the
; glyph's five lines between.
mp_char_cg:
        ld      a,d
        cp      96
        jr      c,mp_cg_up
        and     $5F                             ; lower case is upper
        cp      96
        jr      c,mp_cg_up
        ld      a,' '
mp_cg_up:
        sub     32
        jr      nc,mp_cg_ok
        xor     a                               ; (the box pieces are not in a mini map)
mp_cg_ok:
        ld      l,a
        ld      h,0
        ld      d,h
        ld      e,l
        add     hl,hl
        add     hl,hl
        add     hl,de                           ; * 5
        ld      de,mp_font3
        add     hl,de
        push    bc
        ld      de,mp_cgbuf
        ld      a,CG_BG
        ld      (de),a
        inc     de
        ld      b,5
mp_cg_ln:
        ld      a,(hl)
        inc     hl
        push    hl
        push    de
        ld      l,a
        ld      h,0
        ld      de,mp_cg_px
        add     hl,de
        ld      a,(hl)
        pop     de
        pop     hl
        ld      (de),a
        inc     de
        djnz    mp_cg_ln
        ld      a,CG_BG
        ld      (de),a
        inc     de
        ld      (de),a
        pop     bc
        ld      de,mp_cgbuf
        ld      h,0
        jp      mp_cell8

; a three pixel row (3 bits, left first) as a byte: a ground pixel, then each pixel yellow (01) or ground (10)
mp_cg_px:
        defb    $AA,$A9,$A6,$A5,$9A,$99,$96,$95

        SECTION rodata_user
mp_font3:
        INCLUDE "font3x5.inc"
        SECTION code_user

; void plat_put_raw(uint8_t col, uint8_t row, const uint8_t *eight): a cell as it is: eight bytes, a byte a line (a CG6 cell is one byte wide)
        PUBLIC  _plat_put_raw
_plat_put_raw:
        ld      hl,2
        add     hl,sp
        ld      e,(hl)
        inc     hl
        ld      d,(hl)
        inc     hl
        ld      b,(hl)
        inc     hl
        inc     hl
        ld      c,(hl)
        ld      h,0
        jp      mp_cell8

; void plat_swatch(uint8_t col, uint8_t row, uint8_t pair): a key's colour: a byte of yellow edges and, between them, the colours of a palette byte
; (the even colour in bits 3-2 and the odd in bits 1-0: as the checker is drawn) in two pixels, six lines
        PUBLIC  _plat_swatch
_plat_swatch:
        ld      hl,2
        add     hl,sp
        ld      a,(hl)                  ; the pair
        ld      d,a
        rrca
        rrca
        and     3
        ld      e,a                     ; the even colour
        ld      a,d
        and     3
        ld      d,a                     ; the odd colour
        inc     hl
        inc     hl
        ld      b,(hl)                  ; row
        inc     hl
        inc     hl
        ld      c,(hl)                  ; col
        push    bc
        ld      hl,mp_cgbuf
        ld      a,CG_BG
        ld      (hl),a
        push    hl
        ld      a,e
        add     a,a
        add     a,a
        add     a,a
        add     a,a
        ld      h,a                     ; e << 4
        ld      a,d
        add     a,a
        add     a,a
        or      h
        or      $41                     ; 01 e o 01
        ld      (mp_sw0),a
        ld      a,d
        add     a,a
        add     a,a
        add     a,a
        add     a,a
        ld      h,a
        ld      a,e
        add     a,a
        add     a,a
        or      h
        or      $41                     ; 01 o e 01
        ld      (mp_sw1),a
        pop     hl
        inc     hl
        ld      a,(mp_sw0)
        ld      (hl),a
        inc     hl
        ld      a,(mp_sw1)
        ld      (hl),a
        inc     hl
        ld      a,(mp_sw0)
        ld      (hl),a
        inc     hl
        ld      a,(mp_sw1)
        ld      (hl),a
        inc     hl
        ld      a,(mp_sw0)
        ld      (hl),a
        inc     hl
        ld      a,(mp_sw1)
        ld      (hl),a
        inc     hl
        ld      a,CG_BG
        ld      (hl),a
        pop     bc
        ld      de,mp_cgbuf
        ld      h,0
        jp      mp_cell8
mp_sw0: defb    0
mp_sw1: defb    0
mp_cgbuf:
        defs    8


; void plat_put_minirow(uint8_t ty, const uint8_t *colours, const uint8_t *base, uint8_t view) __smallc
; Tile row ty (0..95) of the mini map from the builder's 96 colours (0..7, +8 for the city shown dim where a density has none): lines 2 ty and
; 2 ty + 1, a tile a pixel.  What a colour is depends on the view (a palette of 16 bytes: the colour of the even pixels of a line in bits 3-2 and
; of the odd in bits 1-0, the other way round on the next line, so two colours make a checker).  base is not used.
        PUBLIC  _plat_put_minirow
_plat_put_minirow:
        ld      hl,2
        add     hl,sp
        ld      a,(hl)                  ; view
        ld      hl,mp_pal_city
        cp      1
        jr      z,mm_pal_set
        ld      hl,mp_pal_power
        cp      6
        jr      z,mm_pal_set
        ld      hl,mp_pal_transport
        cp      7
        jr      z,mm_pal_set
        ld      hl,mp_pal_density
mm_pal_set:
        ld      (mm_pal),hl
        ld      hl,6
        add     hl,sp
        ld      e,(hl)
        inc     hl
        ld      d,(hl)                  ; de = the colours
        inc     hl
        ld      a,(hl)                  ; ty
        ld      l,a
        and     3
        rrca
        rrca
        ld      c,a                     ; (ty mod 4) * 64: the first line's offset in its text row
        ld      a,l
        srl     a
        srl     a
        ld      b,a                     ; the text row
        ld      (mm_dst),bc
        ld      hl,mm_buf
        ld      (mm_bp),hl
        ld      a,24
        ld      (mm_cnt),a
mm_group:
        ld      bc,0
        ld      a,(de)
        inc     de
        and     15
        ld      l,a
        ld      h,0
        push    de
        ld      de,(mm_pal)
        add     hl,de
        pop     de
        ld      a,(hl)
        ld      h,a
        rrca
        rrca
        and     3
        ld      l,a                     ; the even colour (l) and the odd (h bits 1-0)
        sla     b
        sla     b
        ld      a,l
        or      b
        ld      b,a
        sla     c
        sla     c
        ld      a,h
        and     3
        or      c
        ld      c,a
        ld      a,(de)
        inc     de
        and     15
        ld      l,a
        ld      h,0
        push    de
        ld      de,(mm_pal)
        add     hl,de
        pop     de
        ld      a,(hl)
        ld      h,a
        rrca
        rrca
        and     3
        ld      l,a                     ; the even colour (l) and the odd (h bits 1-0)
        sla     b
        sla     b
        ld      a,h
        and     3
        or      b
        ld      b,a
        sla     c
        sla     c
        ld      a,l
        or      c
        ld      c,a
        ld      a,(de)
        inc     de
        and     15
        ld      l,a
        ld      h,0
        push    de
        ld      de,(mm_pal)
        add     hl,de
        pop     de
        ld      a,(hl)
        ld      h,a
        rrca
        rrca
        and     3
        ld      l,a                     ; the even colour (l) and the odd (h bits 1-0)
        sla     b
        sla     b
        ld      a,l
        or      b
        ld      b,a
        sla     c
        sla     c
        ld      a,h
        and     3
        or      c
        ld      c,a
        ld      a,(de)
        inc     de
        and     15
        ld      l,a
        ld      h,0
        push    de
        ld      de,(mm_pal)
        add     hl,de
        pop     de
        ld      a,(hl)
        ld      h,a
        rrca
        rrca
        and     3
        ld      l,a                     ; the even colour (l) and the odd (h bits 1-0)
        sla     b
        sla     b
        ld      a,h
        and     3
        or      b
        ld      b,a
        sla     c
        sla     c
        ld      a,l
        or      c
        ld      c,a
        ld      hl,(mm_bp)
        ld      (hl),b
        inc     hl
        ld      (hl),c
        inc     hl
        ld      (mm_bp),hl
        ld      a,(mm_cnt)
        dec     a
        ld      (mm_cnt),a
        jp      nz,mm_group
        ld      hl,mm_buf               ; line 0: every other byte of the buffer from 0, line 1: from 1
        ld      bc,(mm_dst)
        call    mm_out
        ld      hl,mm_buf + 1
        ld      bc,(mm_dst)
        ld      a,c
        add     a,32
        ld      c,a
mm_out:
        IFDEF   VRAM_FLAT
        ld      a,b
        add     a,VRAM_BASE_HI
        ld      b,a
        ENDIF
        ld      e,24
mm_o:
        ld      a,(hl)
        inc     hl
        inc     hl
        IFDEF   VRAM_FLAT
        ld      (bc),a
        ELSE
        out     (c),a
        ENDIF
        inc     c
        dec     e
        jr      nz,mm_o
        ret

        SECTION rodata_user
; the palettes by the builder's colour: 0 land, 1 water, 2 civic, 3 industry, 4 trees, 5 houses, 6 shops, 7 roads (levels 1 to 7 in a density)
; and 8 to 15 the same dim.  The pixel colours: 0 green, 1 yellow, 2 blue, 3 red.
mp_pal_city:
        defb    $00,$0A,$0D,$0E,$00,$0F,$0C,$05, 0,0,0,0,0,0,0,0
mp_pal_power:                                   ; yellow where there is power, red where something is built without it
        defb    $00,$0A,$0F,$00,$00,$00,$05,$00, 0,0,0,0,0,0,0,0
mp_pal_transport:
        defb    $00,$0A,$00,$00,$00,$00,$00,$05, 0,0,0,0,0,0,0,0
mp_pal_density:
        defb    $00,$01,$05,$07,$0F,$0F,$0F,$0F, $00,$02,$03,$03,$00,$03,$03,$01
        SECTION code_user

        SECTION bss_user
mm_buf: defs    48                      ; the row's bytes: the pair for line 0 and line 1 of each of the 24 columns
        SECTION code_user
mm_pal: defw    0
mm_dst: defw    0
mm_bp:  defw    0
mm_cnt: defb    0

; void plat_init(void): the mode, a clear screen, the frame interrupt
        PUBLIC  _plat_init
_plat_init:
        IFNDEF  VRAM_FLAT
        ld      bc,VRAM_MODE
        ld      a,MODE_RG6_WHITE
        out     (c),a
        ENDIF
        ld      a,1                     ; in_GetKey's timings, in looks (about a frame each): a key registers at once, repeats after 14, then every 3
        ld      (_in_KeyDebounce),a
        ld      a,14
        ld      (_in_KeyStartRepeat),a
        ld      a,3
        ld      (_in_KeyRepeatPeriod),a
        IFDEF   HAVE_SOUND
        call    snd_init
        ENDIF
        ; fall into plat_clear

; void plat_clear(void): the screen to black
        PUBLIC  _plat_clear
        PUBLIC  _plat_text_clear
_plat_text_clear:
_plat_clear:
        IFDEF   VRAM_FLAT
        ld      bc,VRAM_FLAT
        ELSE
        ld      bc,0
        ENDIF
        xor     a
mp_clear_lp:
        REPT    16
        IFDEF   VRAM_FLAT
        ld      (bc),a
        ELSE
        out     (c),a
        ENDIF
        inc     bc
        ENDR
        ld      a,b
        IFDEF   VRAM_FLAT
        cp      VRAM_BASE_HI + $18
        ELSE
        cp      $18                     ; 6144 bytes
        ENDIF
        ld      a,0
        jr      nz,mp_clear_lp
        ld      hl,mp_cache             ; and no cell shows what the cache says
        ld      de,mp_cache + 1
        ld      bc,MAP_ROWS * 32 * 2 - 1
        ld      (hl),$FF
        ldir
        ret

; uint8_t plat_key(void)
; z88dk's in_GetKey: the debounce and repeat state machine over in_Inkey (the raw state of the matrix), counted in calls: the game looks about once
; a frame.  Only the keys the game takes get through: a cursor key, Enter, Esc, a character from space to z.  0 if none.
        PUBLIC  _plat_key
_plat_key:
        call    in_GetKey               ; hl = the code; carry if none
        jr      c,mp_k_none
        ld      a,l
        call    mp_ok
        jr      nc,mp_k_none
        ld      h,0
        ret
mp_k_none:
        ld      hl,0
        ret

; Carry if the code in a is one the game takes.  Keeps a.
mp_ok:
        cp      8
        ret     c                       ; (255 and the small control codes are not keys: carry clear)
        cp      12
        jr      c,mp_yes                ; 8 to 11: the cursor keys
        cp      13
        jr      z,mp_yes
        cp      27
        jr      z,mp_yes
        cp      32
        ret     c
        cp      128
        jr      c,mp_yes
        or      a                       ; no
        ret
mp_yes:
        scf
        ret

        IFDEF   VRAM_FLAT
; The host test's keyboard: in_Inkey as z88dk's SPC-1000 one is (the first key down in row order, from the table), but over the rows of each look that
; build/spc1000flat/script.inc has.
        PUBLIC  in_Inkey
        PUBLIC  _in_Inkey
in_Inkey:
_in_Inkey:
        ld      a,(mp_rep)              ; the script is runs of looks: a count, then the 9 rows
        or      a
        jr      nz,mp_rep_go
        ld      hl,mp_now               ; (none, unless there is another run)
        ld      b,9
        xor     a
mp_rd0:
        ld      (hl),a
        inc     hl
        djnz    mp_rd0
        ld      hl,(mp_stream_left)
        ld      a,h
        or      l
        jr      z,mp_ik_none            ; (the script is done: no keys)
        dec     hl
        ld      (mp_stream_left),hl
        ld      hl,(mp_stream_ptr)
        ld      a,(hl)
        inc     hl
        ld      de,mp_now
        ld      bc,9
        ldir
        ld      (mp_stream_ptr),hl
mp_rep_go:
        dec     a
        ld      (mp_rep),a
        ld      hl,in_keytranstbl + 8
        ld      de,mp_now
        ld      c,9
mp_ik_row:
        ld      a,(de)
        inc     de
        ld      b,8
mp_ik_bit:
        rlca
        jr      c,mp_ik_found
        inc     hl
        djnz    mp_ik_bit
        dec     c
        jr      nz,mp_ik_row
mp_ik_none:
        ld      hl,0
        scf
        ret
mp_ik_found:
        ld      l,(hl)
        ld      h,0
        or      a
        ret
        INCLUDE "script.inc"
mp_now: defs    9
        PUBLIC  mp_bad
mp_bad: defb    0
mp_rep: defb    0
        ENDIF

; uint16_t plat_clock(void), void plat_idle(void), void plat_flush(void): the frames the game has waited for, and a wait for the next one
        PUBLIC  _plat_clock
_plat_clock:
        ld      hl,(mp_clock)
        ret
        PUBLIC  _plat_idle
_plat_idle:
        ld      hl,(mp_clock)
        inc     hl
        ld      (mp_clock),hl
        ei
        halt                            ; the VDG's frame sync interrupts
        ret
        PUBLIC  _plat_flush
        PUBLIC  _plat_exit
_plat_flush:
_plat_exit:
        ret

; void plat_afford(uint16_t mask): the tools there is the money for, bit i for tool i; the icons of the others are drawn thinned
        PUBLIC  _plat_afford
_plat_afford:
        ld      hl,2
        add     hl,sp
        ld      a,(hl)
        ld      (mp_afford),a
        inc     hl
        ld      a,(hl)
        ld      (mp_afford + 1),a
        ret

; void plat_icons(uint8_t selected): the 14 tool icons in rows 1 and 2, two cells wide each from column 0 (28 columns), the selected one
; in inverse; the ones there is no money for thinned to a checkerboard (each byte AND %01010101 on the even lines, %10101010 on the odd)
        PUBLIC  _plat_icons
_plat_icons:
        ld      hl,2
        add     hl,sp
        ld      a,(hl)
        ld      (mp_sel),a
        ld      hl,mp_icons
        ld      de,(mp_afford)
        xor     a                       ; the icon
mp_ic:
        ld      (mp_ic_n),a
        ld      c,a
        ld      a,(mp_sel)
        cp      c
        ld      a,0
        jr      nz,mp_ic_nsel
        ld      a,$FF
mp_ic_nsel:
        ld      (mp_ic_x),a             ; the selected icon is complemented
        ld      a,$FF                   ; the masks of the even and the odd lines
        ld      (mp_ic_m0),a
        ld      (mp_ic_m1),a
        srl     d
        rr      e                       ; the icon's bit of the affordable mask, into carry
        jr      c,mp_ic_aff
        ld      a,$55
        ld      (mp_ic_m0),a
        ld      a,$AA
        ld      (mp_ic_m1),a
mp_ic_aff:
        push    de
        ld      a,(mp_ic_n)
        add     a,a
        ld      c,a                     ; the column of its left cell
        ld      b,1                     ; row 1: the top two cells
        call    mp_icon_cell
        inc     c
        call    mp_icon_cell
        dec     c
        inc     b                       ; row 2: the bottom two
        call    mp_icon_cell
        inc     c
        call    mp_icon_cell
        pop     de
        ld      a,(mp_ic_n)
        inc     a
        cp      NUM_ICONS
        jr      nz,mp_ic
        ret

; The cell of 8 bytes at hl (which goes on 8) drawn at row b, column c: masked with mp_ic_m0 and mp_ic_m1 (even and odd lines), then xor mp_ic_x.
; Keeps b and c.
mp_icon_cell:
        push    bc
        ld      de,mp_ic_buf
        ld      b,4
mp_ic_pair:
        ld      a,(mp_ic_m0)
        and     (hl)
        ld      c,a
        ld      a,(mp_ic_x)
        xor     c
        ld      (de),a
        inc     hl
        inc     de
        ld      a,(mp_ic_m1)
        and     (hl)
        ld      c,a
        ld      a,(mp_ic_x)
        xor     c
        ld      (de),a
        inc     hl
        inc     de
        djnz    mp_ic_pair
        pop     bc
        push    bc
        push    hl
        ld      de,mp_ic_buf
        ld      h,0
        call    mp_cell8
        pop     hl
        pop     bc
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

mp_mask:  defb  0
mp_clock: defw  0
mp_afford: defw $FFFF
mp_sel:   defb  0
mp_ic_n:  defb  0
mp_ic_x:  defb  0
mp_ic_m0: defb  $FF
mp_ic_m1: defb  $FF
mp_ic_buf: defs 8

; What each map cell shows (32 x 18 words)
        SECTION bss_user
mp_cache: defs  MAP_ROWS * 32 * 2
