; Toshiba Pasopia 7 platform (z88dk +pasopia7: a boot disc, the program at $0000 in all RAM, the ROMs not used): the game draws pictures and text itself.
;
; The screen is "fine graph, wide": 320x200 in 8 colours, a cell of 8x8 pixels in 40 columns and 25 rows.  The video RAM is four planes of 16 KB (blue, red, green and the
; attribute of each scan line) that are not in the Z80's memory but can be mapped over $8000-$BFFF (bit 2 of port $3C; the RAM there is hidden meanwhile).  The 6845 shows a
; cell as 8 contiguous bytes in each plane, the cell of row r and column c at (r * 40 + c) * 8, and a byte's bit 7 is its leftmost pixel.  The plane register (8255 #1 port A,
; $0C) chooses the planes a write goes to ($10 blue, $20 red, $40 green; the bits 0-2 say the data and not $FF) and a read looks at; a write to the green plane also stores the
; attribute (port B, $0D), which has bit 3 set: "dot mode", the scan line is the three planes, not text.  The 8000 bytes a plane shows leave 8384 of its 16384 beyond them: the
; map's pictures, the font and the icons are kept there (the window offset $2000: SPARE), as a cell is drawn by copying 8 bytes a plane from them, in the video RAM itself.
;
; The window hides the RAM at $8000-$BFFF, so what the drawing code touches while it is mapped (the buffers, the cache, the stack) is below $8000 or above $BFFF: the
; uninitialised data starts at $A000 (zpragma.inc) and the engine's big arrays come first, so what the platform has comes after them.  Interrupts are never on: the frame is
; the vertical sync bit of 8255 #0 port B (polled), the keyboard a matrix behind the Z80 PIO ($30 selects the rows, $31 has the keys).
;
; Arguments are the game's C calling convention (smallc).  A cell's attribute is the Spectrum's: ink in bits 0-2 (blue 1, red 2, green 4), paper in bits 3-5.  A plane's byte for a
; row g of the glyph is (g AND (ink XOR paper)) XOR paper, each of those a bit of the attribute made into a mask.

        SECTION code_user
        EXTERN  _view_tile_art          ; picture n is at 8 * n from it
        EXTERN  p7_time_init, p7_tick, p7_acc_f
        IFDEF   HAVE_SOUND
        EXTERN  ay_poll                 ; (target/common/ay_hooks.asm: a tick of the sound for each frame that has gone by)
        ENDIF
        EXTERN  asm_set_cursor_state    ; z88dk's: l = $20 for no cursor, h the last line

        defc    PORT_MODE = $08         ; 8255 #0 port A: the display mode
        defc    PIO1_A = $0C            ; 8255 #1 port A: the plane register
        defc    PIO1_B = $0D            ;               B: the attribute (low 4 bits)
        defc    PIO1_C = $0E            ;               C: bit 2 palette select, bit 3 hides the planes, bit 4 keeps the attribute
        defc    PIO1_CTL = $0F
        defc    MEMCTL = $3C            ; bits 0-1: 2 = all RAM; bit 2: the video window over $8000-$BFFF
        defc    PIO_SEL = $30           ; the Z80 PIO: the keyboard rows to read, and
        defc    PIO_KEY = $31           ; the keys, a pressed key a 0 bit
        defc    WON = 6
        defc    WOFF = 2
        defc    WIN = $8000
        defc    SPARE = $A000           ; window offset $2000: past the 8000 bytes that are displayed
        defc    FONT = SPARE + 2760     ; the 96 glyphs, 8 bytes each (in all three planes)
        defc    ICONS = SPARE + 3528    ; the tool icons: four cells of 16 bytes each (blue plane)
        defc    ART_B_LEN = 4424
        defc    ART_RG_LEN = 2760
        defc    PL_B = $11
        defc    PL_R = $22
        defc    PL_G = $44
        defc    TEXT_ATTR = 7           ; white on black
        defc    MAP_ROW = 6             ; the map's cell rows: the only ones with a cache entry
        defc    MAP_ROWS = 19
        defc    COLS = 40
        defc    SHADOW_ROWS = 24        ; the rows of text that mp_shadow remembers
        defc    SHADOW_SIZE = COLS * SHADOW_ROWS

        SECTION code_user

; The mini map's pairs of pixels: for each of the three planes (blue, red, green) and each of the two lines, the 16 colours (bit 0 blue, 1 red, 2 green, 3 dim): 3 if the plane has
; the colour, and if it is dim a checker: 2 (the left pixel) on the first line and 1 on the second
mm_pair:
        defb    0,3,0,3,0,3,0,3, 0,2,0,2,0,2,0,2
        defb    0,3,0,3,0,3,0,3, 0,1,0,1,0,1,0,1
        defb    0,0,3,3,0,0,3,3, 0,0,2,2,0,0,2,2
        defb    0,0,3,3,0,0,3,3, 0,0,1,1,0,0,1,1
        defb    0,0,0,0,3,3,3,3, 0,0,0,0,2,2,2,2
        defb    0,0,0,0,3,3,3,3, 0,0,0,0,1,1,1,1

; The keys: the row n of the matrix (the PIO select value mp_rows[n], then the keys in $31) bit b is mp_keys[8 * n + b], the game's key codes (the cursor keys are 8 left,
; 9 right, 10 down and 11 up, and 28 to 31 with the shift key: eight cells), 0 for no key
mp_rows:
        defb    $41,$42,$44,$48,$21,$22,$24,$28,$11,$12,$14,$18
mp_keys:
        defb    '-','5','6','f','h','9',':',0
        defb    'q','w','e','g','j','i','o','p'
        defb    'a','s','d','v','n','k','l',';'
        defb    'z','x','c','b','m',',','.','/'
        defb    0,0,0,0,8,12,0,' '               ; (12: the up key, which is down with the shift key: the cursor cluster has no key for down)
        defb    0,0,0,0,0,0,0,0                 ; (F1 to F8)
        defb    '1','0','4','r','y',0,0,0
        defb    '2','3','8','t','u','7','@',0
        defb    0,0,0,0,0,0,0,0                 ; (the modifiers)
        defb    0,0,0,0,0,0,0,0                 ; (the keypad 0 to 7)
        defb    0,0,0,10,11,0,0,13
        defb    9,0,8,27,0,0,0,0

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

; a = a plane register value, hl = a window address, de = where in the RAM, bc = the count: copied out of the video RAM.  Uses a.
mp_vcopy:
        push    af
        ld      a,WON
        out     (MEMCTL),a
        pop     af
        out     (PIO1_A),a
        ldir
        ld      a,WOFF
        out     (MEMCTL),a
        ret

; hl = a picture's offset in the spare area (8 * n): mp_pix gets its three planes.  Uses all but IX.
mp_fetch24:
        ld      de,SPARE
        add     hl,de
        ld      (mp_ts),hl
        ld      de,mp_pix
        ld      bc,8
        ld      a,PL_B
        call    mp_vcopy
        ld      hl,(mp_ts)
        ld      bc,8
        ld      a,PL_R
        call    mp_vcopy
        ld      hl,(mp_ts)
        ld      bc,8
        ld      a,PL_G
        jp      mp_vcopy

; The 24 bytes of mp_pix (blue, red, green: eight rows each) to the three planes at the cell mp_scr.  Uses all but IX.
mp_draw:
        ld      a,WON
        out     (MEMCTL),a
        ld      hl,mp_pix
        ld      de,(mp_scr)
        ld      a,PL_B
        out     (PIO1_A),a
        ld      bc,8
        ldir
        ld      de,(mp_scr)
        ld      a,PL_R
        out     (PIO1_A),a
        ld      bc,8
        ldir
        ld      de,(mp_scr)
        ld      a,PL_G
        out     (PIO1_A),a
        ld      bc,8
        ldir
        ld      a,WOFF
        out     (MEMCTL),a
        ret

; hl = a picture's offset in the spare area (8 * n): the three planes of the picture are copied to the cell mp_scr inside the video RAM.  Uses all but IX.
mp_draw_atlas:
        ld      de,SPARE
        add     hl,de
        ld      (mp_ts),hl
        ld      a,WON
        out     (MEMCTL),a
        ld      de,(mp_scr)
        ld      a,PL_B
        out     (PIO1_A),a
        ld      bc,8
        ldir
        ld      hl,(mp_ts)
        ld      de,(mp_scr)
        ld      a,PL_R
        out     (PIO1_A),a
        ld      bc,8
        ldir
        ld      hl,(mp_ts)
        ld      de,(mp_scr)
        ld      a,PL_G
        out     (PIO1_A),a
        ld      bc,8
        ldir
        ld      a,WOFF
        out     (MEMCTL),a
        ret

; a = row, b = col: hl and mp_scr = the cell's address in the window, WIN + (row * 40 + col) * 8.  Uses a, de, hl.
mp_scraddr:
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
        add     hl,hl
        add     hl,hl
        add     hl,hl                   ; * 8
        ld      de,WIN
        add     hl,de
        ld      (mp_scr),hl
        ret

; mp_pix = its complement
mp_cpl_pix:
        ld      hl,mp_pix
        ld      b,24
mp_cpl_lp:
        ld      a,(hl)
        cpl
        ld      (hl),a
        inc     hl
        djnz    mp_cpl_lp
        ret

; void plat_put_tile(uint8_t col, uint8_t row, const uint8_t *art, uint8_t attr, uint8_t inverse) __smallc
; A map picture: art is _view_tile_art + 8 * n, which is also the picture's offset in the spare area.  The attribute is not used; `inverse` draws the complement (the cursor).
        PUBLIC  _plat_put_tile
_plat_put_tile:
        call    mp_snd
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
        push    bc
        push    af
        ex      de,hl
        ld      de,_view_tile_art
        or      a
        sbc     hl,de                   ; 8 * n
        pop     af
        pop     bc
        push    hl
        push    bc
        call    mp_scraddr
        pop     bc
        pop     hl
        bit     0,c
        jp      z,mp_draw_atlas
        call    mp_fetch24
        call    mp_cpl_pix
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
        ex      de,hl
        ld      de,mp_pix
        ld      bc,24
        ldir
        pop     bc
        pop     af
        bit     0,c
        jr      z,mp_pl_draw
        push    af
        push    bc
        call    mp_cpl_pix
        pop     bc
        pop     af
mp_pl_draw:
        call    mp_scraddr
        jp      mp_draw

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

; Text is kept in a shadow screen (mp_shadow: a character a cell, bit 7 set while the cell is not drawn yet; mp_shadow + SHADOW_SIZE: its attribute) and drawn
; by mp_flush, once, in its final colours: plat_put and plat_text_attr only note what the cell is to show, and a cell that already shows it is not
; drawn at all.  The cell is (0, 0) when it shows no text (a black cell after a clear, or a picture).
; a = row, b = col (row under SHADOW_ROWS): hl = the cell's character in mp_shadow.  Uses de.
mp_shptr:
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
        ld      de,mp_shadow
        add     hl,de
        ret

; a = a row: it has text not drawn yet.  Keeps bc, de.
mp_rowdirty:
        push    hl
        push    de
        ld      e,a
        ld      d,0
        ld      hl,mp_rowd
        add     hl,de
        ld      (hl),1
        ld      a,1
        ld      (mp_dirty),a
        pop     de
        pop     hl
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

; The art at mp_src in the colours of mp_attr as the cell mp_pix: for each plane a row of the glyph g is (g AND A) XOR B,
; A = a mask of ink xor paper and B = one of paper.
mp_build:
        ld      a,(mp_attr)
        ld      d,a
        ld      hl,mp_pix
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
mp_b2:  call    mp_pl8
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
mp_r2:  call    mp_pl8
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
mp_g2:                                  ; fall into mp_pl8

; 8 bytes of a plane at hl from the glyph at mp_src: (g AND c) XOR b; hl goes on.  Keeps b, c, d.
mp_pl8:
        push    de
        ld      de,(mp_src)
        REPT    8
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
        ld      a,(mp_ta + 1)
        call    mp_rowdirty
ta_next:
        ld      hl,mp_ta + 2
        inc     (hl)
        ld      hl,mp_ta
        dec     (hl)
        jr      nz,ta_cell
        ret

; The sound's ticks: called at the start of the drawing routines and of the waits (the sound has no interrupt: the frames are counted by looking).  Uses af, bc, de, hl.
mp_snd:
        IFDEF   HAVE_SOUND
        jp      ay_poll
        ELSE
        ret
        ENDIF

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
        ld      a,PL_B
        call    mp_vcopy                ; the glyph out of the video RAM
        ld      de,mp_g8t
        ret

; Draws the cells of text that are not drawn yet (mp_dirty says there are some), in the order of the screen: only the rows that have any (mp_rowd).  A glyph in the plain
; colours (white on black) is one copy of its 8 bytes out of the font, into all three planes at once (the plane register $77: the planes read are ANDed, and the font is the
; same in each).
mp_flush:
        ld      a,(mp_dirty)
        or      a
        ret     z
        call    mp_snd
        xor     a
        ld      (mp_dirty),a
        ld      (mp_fr),a
mp_fl_row:
        ld      a,(mp_fr)
        ld      e,a
        ld      d,0
        ld      hl,mp_rowd
        add     hl,de
        ld      a,(hl)
        or      a
        jp      z,mp_fl_nrow            ; (nothing to draw in this row)
        ld      (hl),0
        ld      a,(mp_fr)
        ld      b,0
        call    mp_shptr
        ld      (mp_fp),hl
        xor     a
        ld      (mp_fc),a
mp_fl_col:
        ld      hl,(mp_fp)
        ld      a,(hl)
        bit     7,a
        jp      z,mp_fl_next
        res     7,(hl)
        and     $7F
        ld      (mp_fch),a
        ld      de,SHADOW_SIZE
        add     hl,de
        ld      c,(hl)                  ; its attribute
        ld      a,c
        ld      (mp_fa),a
        cp      TEXT_ATTR
        jr      nz,mp_fl_gen
        ld      a,(mp_fch)
        cp      32
        jr      c,mp_fl_gen
        ld      l,a                     ; the plain colours: the glyph's 8 bytes from the font to the cell, in all three planes
        ld      h,0
        add     hl,hl
        add     hl,hl
        add     hl,hl
        ld      de,FONT - 32 * 8
        add     hl,de
        push    hl
        ld      a,(mp_fc)
        ld      b,a
        ld      a,(mp_fr)
        call    mp_scraddr
        pop     hl
        ld      de,(mp_scr)
        ld      a,WON
        out     (MEMCTL),a
        ld      a,$77
        out     (PIO1_A),a
        ld      bc,8
        ldir
        ld      a,WOFF
        out     (MEMCTL),a
        jp      mp_fl_next
mp_fl_gen:
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
        cp      COLS
        jp      nz,mp_fl_col
mp_fl_nrow:
        ld      hl,mp_fr
        inc     (hl)
        ld      a,(hl)
        cp      SHADOW_ROWS
        jp      nz,mp_fl_row
        ret

; void plat_put_overlay(uint8_t col, uint8_t row, const uint8_t *art) __smallc
; The pixels set in 8 bytes of art, white, over the cell: a sprite.  The cell's own picture is fetched again (the cache knows it) and the
; sprite ORed over it.
        PUBLIC  _plat_put_overlay
_plat_put_overlay:
        call    mp_snd
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
        call    mp_fetch24
        ld      a,(mp_ov + 2)
        or      a
        call    nz,mp_cpl_pix
        jr      mp_ov_or
mp_ov_blank:
        ld      hl,mp_pix
        ld      b,24
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

; hl = 8 bytes of sprite art: mp_pix gets its pixels ORed in, in all three planes (white).  Uses all but IX.
mp_orsprite:
        ld      c,3
        ld      de,mp_pix
mp_ov_pl:
        push    hl
        ld      b,8
mp_ov_b:
        ld      a,(de)
        or      (hl)
        ld      (de),a
        inc     hl
        inc     de
        djnz    mp_ov_b
        pop     hl
        dec     c
        jr      nz,mp_ov_pl
        ret

; void mp_chart_cell(uint8_t col, uint8_t row, const uint8_t *fill, const uint8_t *dots, uint8_t ink) __smallc   (plat_charts.c, HAVE_CHART_CELL)
; A cell of a bar chart: 8 bytes of art in the colour ink on black, and the white pixels of 8 more over it, drawn once.
        PUBLIC  _mp_chart_cell
_mp_chart_cell:
        call    mp_snd
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
; The 16 bytes of the icon cell n (0 to 55) out of the video RAM.
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
        ld      a,PL_B
        jp      mp_vcopy

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
        ld      a,c
        jp      mp_rowdirty
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
        ld      a,PL_B
        call    mp_vcopy
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
        cp      COLS
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

; The art (tools/pasopia7_art.py's blocks, 9944 bytes) from the disk: appmake +pasopia7 --data puts it from the track after the program's (the program has 8 sectors a track
; from track 2), sector 1 on.  It is read at once into the room that the engine's mini maps and the map will have (they are not in use yet), where plat_init stashes it.
; A read that fails is not tried again (the driver tried): the art is not there.
        EXTERN  __DATA_END_tail
        EXTERN  asm_pasopia7_disk_rw
        EXTERN  _minimaps
        defc    ART_TRACK = 2 + (__DATA_END_tail + 2047) / 2048
        defc    ART_SECTORS = (ART_B_LEN + 2 * ART_RG_LEN + 255) / 256

mp_loadart:
        xor     a                       ; read
        ld      e,0                     ; drive 0
        ld      d,ART_TRACK
        ld      c,1
        ld      b,ART_SECTORS
        ld      hl,_minimaps
        jp      asm_pasopia7_disk_rw

; hl = a source in the RAM, de = a destination in the window (a plane's spare area), bc = the count, a = the plane register value: copied 256 bytes at a time through
; mp_stage, as the RAM at $8000-$BFFF is hidden while the window is on.  Uses all.
mp_stash:
        ld      (mp_sp),a
mp_st_lp:
        ld      a,b
        or      c
        ret     z
        ld      (mp_dst),de
        push    bc                      ; what is left
        ld      a,b
        or      a
        jr      z,mp_st_part
        ld      bc,256
mp_st_part:
        ld      (mp_pc),bc
        ld      de,mp_stage
        ldir                            ; window off: the RAM to the stage
        ld      (mp_hl),hl
        ld      hl,mp_stage
        ld      de,(mp_dst)
        ld      bc,(mp_pc)
        ld      a,WON
        out     (MEMCTL),a
        ld      a,(mp_sp)
        out     (PIO1_A),a
        ldir                            ; the stage to the video RAM
        ld      a,WOFF
        out     (MEMCTL),a
        pop     hl                      ; what was left, less the piece
        ld      bc,(mp_pc)
        or      a
        sbc     hl,bc
        ld      b,h
        ld      c,l
        ld      hl,(mp_hl)
        jr      mp_st_lp

; void plat_init(void): the display, the palette, the art into the video RAM, the screen cleared
        PUBLIC  _plat_init
_plat_init:
        di
        ld      a,(mp_up)
        or      a
        jp      nz,mp_up_done
        inc     a
        ld      (mp_up),a
        call    p7_time_init            ; the frames and the sound's ticks come from the CTC
        ld      a,$80
        out     (PIO1_CTL),a            ; 8255 #1: all outputs, all zero
        ld      a,$80
        out     (PORT_MODE),a           ; fine graph, wide (40 columns)
        ld      hl,$0720                ; the 6845's cursor: off ($20), its last line 7 (z88dk's mc6845 library; the console does this, and is not used here)
        call    asm_set_cursor_state
        ld      a,$04
        out     (PIO1_C),a              ; palette select
        xor     a
        out     (PIO1_A),a              ; plane register 0: a write is a palette write
        ld      a,WON
        out     (MEMCTL),a
        ld      hl,WIN
        ld      b,16
        xor     a
mp_pal: ld      c,a                     ; the colour of index i is i & 7 (blue 1, red 2, green 4), for both the even and the odd pixel of a doubled one
        and     7
        ld      (hl),a
        inc     hl
        ld      a,c
        inc     a
        djnz    mp_pal
        ld      a,WOFF
        out     (MEMCTL),a
        xor     a
        out     (PIO1_C),a              ; palette select off
        ld      a,$08
        out     (PIO1_B),a              ; the attribute: dot mode
        call    mp_loadart              ; the art from the disk into the video RAM: the blue block, then the red and the green
        ld      hl,_minimaps
        ld      de,SPARE
        ld      bc,ART_B_LEN
        ld      a,PL_B
        call    mp_stash
        ld      de,SPARE
        ld      bc,ART_RG_LEN
        ld      a,PL_R
        call    mp_stash
        ld      de,SPARE
        ld      bc,ART_RG_LEN
        ld      a,PL_G
        call    mp_stash
        ld      hl,FONT                 ; the font into the red and green planes too, from the blue one, 256 bytes at a time
        ld      (mp_ts),hl
        ld      b,3
mp_fcp: push    bc
        ld      hl,(mp_ts)
        ld      de,mp_stage
        ld      bc,256
        ld      a,PL_B
        call    mp_vcopy
        ld      hl,mp_stage
        ld      de,(mp_ts)
        ld      bc,256
        ld      a,PL_R
        call    mp_stash
        ld      hl,mp_stage
        ld      de,(mp_ts)
        ld      bc,256
        ld      a,PL_G
        call    mp_stash
        ld      hl,(mp_ts)
        inc     h
        ld      (mp_ts),hl
        pop     bc
        djnz    mp_fcp
mp_up_done:
        ; fall into plat_clear

; void plat_clear(void): the three planes to 0 (in the video window; the 8000 bytes of the screen), and nothing is remembered of the screen
        PUBLIC  _plat_clear
        PUBLIC  _plat_text_clear
_plat_text_clear:
_plat_clear:
        ld      (mp_spsave),sp          ; the window has no RAM under it, so SP can be the store pointer: a PUSH writes two bytes of the planes
        ld      de,0
        ld      bc,250                  ; 8000 bytes in blocks of 32
        ld      a,WON
        out     (MEMCTL),a
        ld      a,$77
        out     (PIO1_A),a              ; blue, red and green (and the attribute) all written
        ld      sp,WIN + 8000
mp_clr:
        REPT    16
        push    de
        ENDR
        dec     bc
        ld      a,b
        or      c
        jp      nz,mp_clr
        ld      a,WOFF
        out     (MEMCTL),a
        ld      sp,(mp_spsave)
        ld      hl,mp_cache             ; no cell shows what the cache says
        ld      de,mp_cache + 1
        ld      bc,COLS * MAP_ROWS * 2 - 1
        ld      (hl),$FF
        ldir
        ld      hl,mp_shadow            ; and there is no text, drawn or not
        ld      de,mp_shadow + 1
        ld      bc,2 * SHADOW_SIZE - 1
        ld      (hl),0
        ldir
        xor     a
        ld      (mp_dirty),a
        ld      hl,mp_rowd
        ld      de,mp_rowd + 1
        ld      bc,SHADOW_ROWS - 1
        ld      (hl),a
        ldir
        ld      hl,mp_istate            ; no icon is on the screen
        ld      de,mp_istate + 1
        ld      bc,13
        ld      (hl),0
        ldir
        ret

; uint8_t plat_key(void): the key pressed since the last call, or 0: a new key at once, a held one again after a delay and then at a rate.
; Letters are lower case (upper case with the shift key), the cursor keys 8 left, 9 right, 10 down, 11 up (28 to 31 with the shift key, but for the up key: the cursor cluster's
; down is shift and up).
        PUBLIC  _plat_key
_plat_key:
        call    mp_snd
        call    mp_flush                ; (a screen of text is drawn before it waits for a key)
        call    mp_frames
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
        cp      12
        jr      nz,mp_k_nu
        ld      l,11                    ; the up key: up, and down with the shift key
        ld      a,(mp_shift)
        or      a
        ret     z
        ld      l,10
        ret
mp_k_nu:
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

; Counts the frames (260 counts of the CTC clock, plat_time.asm: 60 a second) that have gone by since it was last called: mp_vbl.  Called whenever the game polls or waits, so
; the time is added up (the clock is read at least every 4 seconds).  Uses a, hl.
mp_frames:
        call    p7_tick
        push    de
        ld      hl,(p7_acc_f)
        ld      de,260
mp_fr1: or      a
        sbc     hl,de
        jr      c,mp_fr2
        ld      (p7_acc_f),hl           ; a frame
        ld      a,(mp_vbl)
        inc     a
        ld      (mp_vbl),a
        jr      mp_fr1
mp_fr2: pop     de
        ret

; a = the first key down (its code, 0 if there is none); mp_shift is 1 if the shift key is down.  Uses all.
mp_scan:
        ld      a,$11                   ; the modifier row: the shift key is bit 1, a pressed key a 0
        out     (PIO_SEL),a
        in      a,(PIO_KEY)
        cpl
        rrca
        and     1
        ld      (mp_shift),a
        ld      d,0                     ; the row
mp_sc_row:
        ld      hl,mp_rows
        ld      e,d
        ld      c,e
        ld      b,0
        add     hl,bc
        ld      a,(hl)
        out     (PIO_SEL),a
        in      a,(PIO_KEY)
        cpl
        ld      e,a                     ; the keys of the row that are down, a bit each
        ld      a,d
        add     a,a
        add     a,a
        add     a,a
        ld      l,a
        ld      h,0
        ld      bc,mp_keys
        add     hl,bc                   ; the row's line of the table
        ld      b,8
mp_sc_bit:
        srl     e
        jr      nc,mp_sc_nb
        ld      a,(hl)
        or      a
        ret     nz                      ; a key (not a modifier, which has no code)
mp_sc_nb:
        inc     hl
        djnz    mp_sc_bit
        inc     d
        ld      a,d
        cp      12
        jr      nz,mp_sc_row
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
        ld      a,(mp_vbl)
        ld      c,a
        ld      de,$3000                ; (a bound, a few frames' worth of looks: a machine whose sync bit does not change is not waited for for ever)
mp_id:  push    bc
        push    de
        call    mp_snd
        pop     de
        pop     bc
        call    mp_frames               ; the wait: until a frame has begun
        ld      a,(mp_vbl)
        cp      c
        ret     nz
        dec     de
        ld      a,d
        or      e
        jr      nz,mp_id
        ld      hl,mp_vbl
        inc     (hl)                    ; (the clock did not run: a frame all the same)
        ret

        PUBLIC  _plat_flush
        PUBLIC  _plat_exit
_plat_flush:
        jp      mp_flush
_plat_exit:
        ret

; void plat_put_minirow(uint8_t ty, const uint8_t *colours, const uint8_t *base, uint8_t view) __smallc
; Draws tile row ty (0..95) of the mini map from its 96 colours (bit 0 blue, 1 red, 2 green, 3 dim: a checker), one a tile column.  A tile is 2 pixels wide and
; 2 lines high, so a row is 192 pixels (24 bytes a plane) by two lines, lines 2 ty and 2 ty + 1, from the left of the screen: the cell row ty / 4, the lines 2 * (ty mod 4) and
; one on in each cell, a byte of a line a cell (8 bytes) on.  base and view are not used.
        PUBLIC  _plat_put_minirow
_plat_put_minirow:
        call    mp_snd
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
        ld      c,a                     ; the first line in the cell
        ld      a,l
        srl     a
        srl     a                       ; the cell row
        ld      l,a
        ld      h,0
        add     hl,hl
        add     hl,hl
        add     hl,hl                   ; row * 8
        push    de
        ld      d,h
        ld      e,l
        add     hl,hl
        add     hl,hl                   ; row * 32
        add     hl,de                   ; row * 40
        pop     de
        add     hl,hl
        add     hl,hl
        add     hl,hl                   ; * 8
        ld      b,0
        add     hl,bc                   ; + the line
        push    de
        ld      de,WIN
        add     hl,de
        pop     de
        ld      (mm_dst),hl
        ld      hl,mm_buf
        ld      (mm_out),hl
        ld      a,24
        ld      (mm_cnt),a
mm_g:                                   ; a group: four tiles, a byte of each of the six lines (a plane's two)
        ld      hl,mm_c0
        ld      b,4
mm_rd:  ld      a,(de)
        inc     de
        and     15
        ld      (hl),a
        inc     hl
        djnz    mm_rd
        push    de                      ; (the colours go on)
        ld      de,(mm_out)
        ld      hl,mm_pair
        ld      b,6
mm_t:   push    bc
        push    hl
        ld      c,0                     ; the byte: a pair of pixels a tile
        ld      a,(mm_c0)
        call    mm_acc
        ld      a,(mm_c1)
        call    mm_acc
        ld      a,(mm_c2)
        call    mm_acc
        ld      a,(mm_c3)
        call    mm_acc
        ld      a,c
        ld      (de),a
        ld      a,e                     ; the next table's buffer: 24 on
        add     a,24
        ld      e,a
        jr      nc,mm_t1
        inc     d
mm_t1:  pop     hl
        ld      bc,16
        add     hl,bc                   ; the next table
        pop     bc
        djnz    mm_t
        ld      hl,(mm_out)
        inc     hl
        ld      (mm_out),hl
        pop     de
        ld      hl,mm_cnt
        dec     (hl)
        jr      nz,mm_g
        ; the buffer to the window: for each plane its two lines
        ld      hl,mm_buf
        ld      a,WON
        out     (MEMCTL),a
        ld      a,PL_B
        call    mm_wr
        ld      a,PL_R
        call    mm_wr
        ld      a,PL_G
        call    mm_wr
        ld      a,WOFF
        out     (MEMCTL),a
        ret

; a = a colour, hl = a table of 16 pairs of pixels, c = the byte so far: c = c * 4 + the colour's pair.  Keeps hl.
mm_acc:
        push    hl
        add     a,l
        ld      l,a
        jr      nc,mm_a1
        inc     h
mm_a1:  ld      b,(hl)
        pop     hl
        ld      a,c
        add     a,a
        add     a,a
        or      b
        ld      c,a
        ret

; plane register a, hl = the buffer's two lines of 24 bytes: written at mm_dst and the next line, a byte a cell on; hl goes on
mm_wr:
        out     (PIO1_A),a
        ld      de,(mm_dst)
        call    mm_line
        ld      de,(mm_dst)
        inc     de
mm_line:
        ld      b,24
mm_lb:  ld      a,(hl)
        inc     hl
        ld      (de),a
        ld      a,e
        add     a,8
        ld      e,a
        jr      nc,mm_ln
        inc     d
mm_ln:  djnz    mm_lb
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

        SECTION bss_user
mp_cache: defs  COLS * MAP_ROWS * 2     ; what each map cell shows (40 x 19 words)
mp_shadow: defs 2 * SHADOW_SIZE         ; the character in each cell of the first rows (0: none; bit 7: not drawn yet), then its attribute
mp_pix:  defs   24                      ; a cell as drawn: blue, red and green, 8 bytes each
mp_g8t:  defs   8                       ; a glyph fetched from the video RAM
mp_stage: defs  256                     ; the art on its way into the video RAM
mm_buf:  defs   144                     ; the mini map row: blue, red and green, two lines of 24 bytes each
mp_rowd: defs   SHADOW_ROWS             ; the rows that have text not drawn yet
mp_istate: defs 14                      ; how each icon was drawn: bit 0 selected, 1 affordable, 2 it is on the screen (0: not known)

        SECTION code_user
mp_up:   defb   0                       ; plat_init has run
mp_attr: defb   0                       ; the cell's attribute
mp_ch:   defb   0                       ; the character being drawn
mp_src:  defw   0                       ; the art being drawn
mp_scr:  defw   0                       ; the cell's address in the window
mp_ts:   defw   0                       ; a picture's address in the spare area
mp_sp:   defb   0                       ; mp_stash: the plane register value
mp_dst:  defw   0                       ; mp_stash: where the piece goes, how long it is, and where the source goes on from
mp_pc:   defw   0
mp_hl:   defw   0
mp_clock: defw  0
mp_dirty: defb  0                       ; there is text not drawn yet
mp_fp:   defw   0                       ; mp_flush: the cell it is at, and its row and column
mp_fr:   defb   0
mp_fc:   defb   0
mp_fa:   defb   0                       ; mp_flush: the attribute and the character of the cell
mp_fch:  defb   0
mp_spsave: defw 0                       ; the stack pointer, while plat_clear uses it to store
mp_vbl:  defb   0                       ; the frames counted
mp_shift: defb  0                       ; the shift key is down
mp_lastkey: defb 0                      ; the key that was down at the last plat_key (0: none)
mp_keyt: defb   0                       ; the frame count when it went down or last repeated
mp_keyd: defb   0                       ; the frames until it repeats
mp_ta:   defs   4                       ; plat_text_attr: the count, the row, the column and the attribute
mp_ovp:  defw   0                       ; mp_chart_cell: the dots' art
mp_ov:   defs   3                       ; plat_put_overlay: the row, the column and the inverse flag
mm_dst:  defw   0                       ; the mini map row's first line in the window
mm_out:  defw   0                       ; the byte of the first buffer being made
mm_cnt:  defb   0
mm_c0:   defb   0                       ; the colours of the four tiles of a group
mm_c1:   defb   0
mm_c2:   defb   0
mm_c3:   defb   0
