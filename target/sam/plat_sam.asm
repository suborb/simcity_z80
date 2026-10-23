; MGT SAM Coupe platform (-subtype=allram, screen mode 4): the game draws pictures and text itself.
;
; Mode 4 is 256x192 pixels of 4 bits, a byte two pixels (the left in the high nibble) and a line 128 bytes, so the game's 32 x 24
; cells of 8x8 pixels are each 4 bytes wide and 8 lines tall, and a cell's first byte is
;     $8000 + row * 1024 + col * 4          its lines 128 bytes apart.
; The screen is 24 KB in the pages from SCRPAGE and is paged in at $8000 by HMPR; the game's own data is in what is normally there,
; so the placer works in the low 32 KB (the program, the stack, and the variables below, which are in the code section so
; that they are there) and reads nothing from the high window while the screen is in.  A picture is first copied to mp_pix with
; the data (or the baked pictures, which are in a block of their own) paged in, and then to the screen.
;
; The image is one file: the low 32 KB (code and stack), the next 32 KB, which the startup code pages in at $8000 (the rest of
; the code's constants, the font and the data; the uninitialised data follows it), and then the baked pictures, 32 bytes each
; (tools/st_tiles_3bpp.py --sam) after a 16 byte palette and the 8 palette entries of the attribute colours.  The routines take their
; arguments the way the game's C code passes them (smallc: first argument first, the caller cleans up).  Interrupts are off.

        SECTION code_user
        EXTERN  _font_8x8_bbc_system
        EXTERN  _view_tile_art          ; picture n is at 8 * n from it

        defc    HMPR = 251
        defc    VMPR = 252
        defc    CLUT = 248
        defc    SCRPAGE = 8             ; the screen's first page (and the video mode: 4 is bits 6 and 5)
        defc    SCREEN = $8000
        defc    ICONS = $8000 + 24      ; the 14 tool icons in the block: after the palette and the attribute colours, 14 rows of 12 bytes each
        defc    ICON_BYTES = 14 * 12
        defc    TILES = ICONS + 14 * ICON_BYTES        ; the baked pictures: after the icons
        defc    TEXT_ATTR = 7           ; white on black
        defc    MAP_ROW = 7             ; the map's cell rows: the only ones with a cache entry
        defc    MAP_ROWS = 17
        defc    COLS = 32

; The 14 tool icons: four cells each, then their attributes
        SECTION rodata_user
        PUBLIC  _mp_icons
_mp_icons:
        BINARY  "assets/icons_spec.bin"

        SECTION code_user

; void plat_put_tile(uint8_t col, uint8_t row, const uint8_t *art, uint8_t attr, uint8_t inverse) __smallc
; A map picture: art is _view_tile_art + 8 * n, drawn from block 3 (32 bytes a picture).  The attribute is not used; `inverse`
; draws the complement of each byte (the cursor).
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
        ld      de,TILES
        add     hl,de
        ld      a,(mp_tpage)
        out     (HMPR),a
        ld      de,mp_pix
        REPT    32
        ldi
        ENDR
        pop     bc
        bit     0,c
        jr      z,mp_t_draw
        ld      hl,mp_pix               ; the complement
        ld      d,32
mp_t_cpl:
        ld      a,(hl)
        cpl
        ld      (hl),a
        inc     hl
        dec     d
        jr      nz,mp_t_cpl
mp_t_draw:
        pop     af
        call    mp_scraddr
        ex      de,hl
        ld      hl,mp_pix
        jp      mp_blit

; hl = the screen address of cell a = row, b = column.  Uses a.
mp_scraddr:
        add     a,a
        add     a,a
        or      $80                     ; (row * 4 is below $60)
        ld      h,a
        ld      a,b
        add     a,a
        add     a,a
        ld      l,a
        ret

; The 32 bytes at hl (low memory) to the cell at de (a screen address), with the screen in for the time it takes.
mp_blit:
        ld      a,SCRPAGE
        out     (HMPR),a
        REPT    8
        ldi
        ldi
        ldi
        ldi
        ld      a,e
        add     a,124
        ld      e,a
        jr      nc,ASMPC + 3
        inc     d
        ENDR
mp_back:
        ld      a,(mp_dpage)
        out     (HMPR),a
        ret

; A map cell that already shows this picture is left alone: mp_cache has a word for each cell of the map, its art address
; xor the inverse flag (art addresses differ by 8 or more), or $FFFF if it shows something else.  a = row, b = col, c = inverse,
; de = art.  Carry if it is as wanted; else the entry is updated.  Keeps a, b, c, de.
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
        add     hl,hl
        add     hl,hl                   ; row * 64
        ld      e,b
        ld      d,0
        add     hl,de
        add     hl,de                   ; and the column * 2
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

; Other drawing in a cell: the cache no longer applies.  a = row, b = column, c = attribute, de = 8 bytes of 1 bit art.
mp_cell:
        call    mp_forget
        push    af
        push    bc
        push    de
        ld      a,c
        call    mp_mktab                ; the attribute's nibble table
        pop     hl                      ; hl = art
        ld      de,mp_gl
        REPT    8
        ldi
        ENDR
        ld      hl,mp_gl
        ld      de,mp_pix
        ld      b,8
mp_cv:
        ld      a,(hl)
        inc     hl
        ld      c,a
        and     $F0
        rrca
        rrca
        rrca
        push    hl
        ld      l,a
        ld      a,(mp_tabhi)
        ld      h,a
        ld      a,(hl)
        ld      (de),a
        inc     de
        inc     l
        ld      a,(hl)
        ld      (de),a
        inc     de
        ld      a,c
        and     $0F
        add     a,a
        ld      l,a
        ld      a,(hl)
        ld      (de),a
        inc     de
        inc     l
        ld      a,(hl)
        ld      (de),a
        inc     de
        pop     hl
        djnz    mp_cv
        pop     bc
        pop     af
        call    mp_scraddr
        ex      de,hl
        ld      hl,mp_pix
        jp      mp_blit

; The table for attribute a (ink in bits 0-2, paper in 3-5; the palette entries of those colours are mp_attrs): 16 entries of two bytes,
; the four pixels of each nibble, at the start of the aligned tables (the overlay's are at +32).  The last one is kept.
mp_mktab:
        ld      hl,mp_cattr
        cp      (hl)
        ret     z
        ld      (hl),a
        ld      c,a
        and     7
        ld      e,a
        ld      d,0
        ld      hl,mp_attrs
        add     hl,de
        ld      b,(hl)                  ; the ink's palette entry
        ld      a,c
        rrca
        rrca
        rrca
        and     7
        ld      e,a
        ld      hl,mp_attrs
        add     hl,de
        ld      c,(hl)                  ; the paper's
        ; the four pairs of pixels: mp_pr + q for q = the left pixel * 2 + the right (a set pixel is the ink)
        ld      hl,mp_pr
        ld      a,c
        add     a,a
        add     a,a
        add     a,a
        add     a,a
        ld      d,a                     ; the paper in the high nibble
        or      c
        ld      (hl),a                  ; paper, paper
        inc     hl
        ld      a,d
        or      b
        ld      (hl),a                  ; paper, ink
        inc     hl
        ld      a,b
        add     a,a
        add     a,a
        add     a,a
        add     a,a
        ld      d,a                     ; the ink in the high nibble
        or      c
        ld      (hl),a                  ; ink, paper
        inc     hl
        ld      a,d
        or      b
        ld      (hl),a                  ; ink, ink
        ; entry n = (pairs[n >> 2], pairs[n & 3])
        ld      a,(mp_tabhi)
        ld      h,a
        ld      l,0
        ld      b,0                     ; n
mp_mk:
        ld      a,b
        rrca
        rrca
        and     3
        ld      e,a
        ld      d,0
        push    hl
        ld      hl,mp_pr
        add     hl,de
        ld      a,(hl)
        pop     hl
        ld      (hl),a
        inc     hl
        ld      a,b
        and     3
        ld      e,a
        push    hl
        ld      hl,mp_pr
        add     hl,de
        ld      a,(hl)
        pop     hl
        ld      (hl),a
        inc     hl
        inc     b
        ld      a,b
        cp      16
        jr      nz,mp_mk
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
        call    mp_forget
        push    af
        push    bc
        ex      de,hl                   ; hl = art
        ld      de,mp_pix
        ld      c,8
mp_ov_cv:
        ld      a,(hl)
        inc     hl
        ld      b,a
        and     $F0
        rrca
        rrca
        rrca
        or      32                      ; (the overlay's half of the table)
        push    hl
        ld      l,a
        ld      a,(mp_tabhi)
        ld      h,a
        ld      a,(hl)
        ld      (de),a
        inc     de
        inc     l
        ld      a,(hl)
        ld      (de),a
        inc     de
        ld      a,b
        and     $0F
        add     a,a
        or      32
        ld      l,a
        ld      a,(hl)
        ld      (de),a
        inc     de
        inc     l
        ld      a,(hl)
        ld      (de),a
        inc     de
        pop     hl
        dec     c
        jr      nz,mp_ov_cv
        pop     bc
        pop     af
        call    mp_scraddr
        ex      de,hl
        ld      hl,mp_pix
        ld      a,SCRPAGE
        out     (HMPR),a
        REPT    8
        ld      a,(de)
        or      (hl)
        ld      (de),a
        inc     hl
        inc     de
        ld      a,(de)
        or      (hl)
        ld      (de),a
        inc     hl
        inc     de
        ld      a,(de)
        or      (hl)
        ld      (de),a
        inc     hl
        inc     de
        ld      a,(de)
        or      (hl)
        ld      (de),a
        inc     hl
        inc     de
        ld      a,e
        add     a,124
        ld      e,a
        jr      nc,ASMPC + 3
        inc     d
        ENDR
        jp      mp_back

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

; void plat_icons(uint8_t selected) __smallc
; The 14 tools as the ST game's buttons, 24x14 pixels, in two rows of seven: icon i is at cell column 3 * (i mod 7) and row
; 1 + 2 * (i div 7), in a 24x16 area (a blank line above and below); the selected one has a yellow frame (colour 14).
        PUBLIC  _plat_icons
_plat_icons:
        ld      hl,2
        add     hl,sp
        ld      a,(hl)
        ld      (mp_isel),a
        ld      a,(mp_ilast)            ; what is on the screen: only the two icons that change are drawn
        cp      $FF
        jr      z,pi_all
        ld      hl,mp_isel
        cp      (hl)
        ret     z                       ; the same tool
        ld      (mp_ii),a               ; the one that was selected,
        call    pi_one
        ld      a,(mp_isel)             ; and the one that is
        ld      (mp_ii),a
        call    pi_one
        jr      pi_done
pi_all:
        xor     a                       ; a new screen: all of them
        ld      (mp_ii),a
pi_each:
        call    pi_one
        ld      hl,mp_ii
        inc     (hl)
        ld      a,(hl)
        cp      14
        jr      nz,pi_each
pi_done:
        ld      a,(mp_isel)
        ld      (mp_ilast),a
        ret

; Draw icon mp_ii (the selected one, mp_isel, in its frame)
pi_one:
        ld      hl,mp_ibuf              ; a blank button area: 16 lines of 12 bytes
        ld      de,mp_ibuf + 1
        ld      bc,16 * 12 - 1
        ld      (hl),0
        ldir
        ld      a,(mp_ii)               ; the icon's pictures: ICONS + 168 * i in the pictures' block
        ld      hl,ICONS
        ld      de,ICON_BYTES
        or      a
pi_mul:
        jr      z,pi_got
        add     hl,de
        dec     a
        jr      pi_mul
pi_got:
        ld      a,(mp_tpage)
        out     (HMPR),a
        ld      de,mp_ibuf + 12
        ld      bc,ICON_BYTES
        ldir
        ld      a,(mp_dpage)
        out     (HMPR),a
        ld      a,(mp_ii)
        ld      hl,mp_isel
        cp      (hl)
        jr      nz,pi_place
        ld      hl,mp_ibuf              ; selected: the frame, yellow
        ld      de,mp_ibuf + 1
        ld      (hl),$EE
        ld      bc,11
        ldir
        ld      hl,mp_ibuf + 15 * 12
        ld      de,mp_ibuf + 15 * 12 + 1
        ld      (hl),$EE
        ld      bc,11
        ldir
        ld      hl,mp_ibuf + 12
        ld      b,14
pi_ring:
        ld      a,(hl)
        and     $0F
        or      $E0
        ld      (hl),a
        push    hl
        ld      de,11
        add     hl,de
        ld      a,(hl)
        and     $F0
        or      $0E
        ld      (hl),a
        pop     hl
        ld      de,12
        add     hl,de
        djnz    pi_ring
pi_place:
        ld      a,(mp_ii)               ; its cell: column 3 * (i mod 7), row 1 + 2 * (i div 7)
        ld      c,0
pi_div:
        cp      7
        jr      c,pi_dd
        sub     7
        inc     c
        jr      pi_div
pi_dd:
        ld      b,a
        add     a,a
        add     a,b
        ld      b,a                     ; the column
        ld      a,c
        add     a,a
        inc     a                       ; the row
        call    mp_scraddr
        ex      de,hl                   ; de = the screen
        ld      hl,mp_ibuf
        ld      a,SCRPAGE
        out     (HMPR),a
        ld      b,16
pi_line:
        ld      c,12
pi_byte:
        ld      a,(hl)
        ld      (de),a
        inc     hl
        inc     de
        dec     c
        jr      nz,pi_byte
        ld      a,e
        add     a,128 - 12
        ld      e,a
        jr      nc,pi_nc
        inc     d
pi_nc:
        djnz    pi_line
        ld      a,(mp_dpage)
        out     (HMPR),a
        ret

; void plat_demand(uint8_t col, uint8_t row, char name, int8_t level) __smallc
; A demand indicator as a bar chart: the letter in the cell (col, row), then seven cells, each a solid colour bar six lines tall with
; a gap on its right and black above and below.  The middle one is the zero mark (white); `level` (-3..3) cells from it to the right
; are green and to the left red, and the rest dark grey.  (ST palette entries: 10 light green, 12 light red, 8 dark grey, 15 white.)
        PUBLIC  _plat_demand
        defc    DM_GREEN = 10
        defc    DM_RED = 12
        defc    DM_EMPTY = 8
        defc    DM_ZERO = 15
_plat_demand:
        ld      hl,2
        add     hl,sp
        ld      a,(hl)
        ld      (mp_dlev),a
        inc     hl
        inc     hl
        ld      a,(hl)                  ; the letter
        inc     hl
        inc     hl
        ld      c,(hl)                  ; row
        inc     hl
        inc     hl
        ld      b,(hl)                  ; col
        ld      (mp_drc),bc             ; (c = the row first, then b = the column)
        call    mp_char                 ; white on black
        xor     a
        ld      (mp_dk),a
dm_cell:
        ld      a,(mp_dk)
        sub     3
        ld      e,a                     ; this cell's place from the middle: -3..3
        jr      z,dm_zero
        jp      m,dm_left
        ld      a,(mp_dlev)             ; to the right of the middle: green if the level reaches it
        bit     7,a
        jr      nz,dm_empty
        cp      e
        jr      c,dm_empty
        ld      a,DM_GREEN
        jr      dm_draw
dm_left:
        ld      a,(mp_dlev)             ; to the left: red if the (negative) level reaches it
        bit     7,a
        jr      z,dm_empty
        cp      e
        jr      c,dm_red
        jr      nz,dm_empty
dm_red:
        ld      a,DM_RED
        jr      dm_draw
dm_zero:
        ld      a,DM_ZERO
        jr      dm_draw
dm_empty:
        ld      a,DM_EMPTY
dm_draw:
        ld      c,a                     ; the colour: eight lines of four bytes
        rlca
        rlca
        rlca
        rlca
        ld      e,a                     ; the colour in the high nibble (the cell's last byte: its right pixel is the gap)
        or      c
        ld      d,a                     ; the colour in both
        ld      hl,mp_pix
        xor     a
        ld      (hl),a                  ; line 0 black
        inc     hl
        ld      (hl),a
        inc     hl
        ld      (hl),a
        inc     hl
        ld      (hl),a
        inc     hl
        ld      b,6
dm_line:
        ld      (hl),d
        inc     hl
        ld      (hl),d
        inc     hl
        ld      (hl),d
        inc     hl
        ld      (hl),e
        inc     hl
        djnz    dm_line
        xor     a
        ld      (hl),a                  ; line 7 black
        inc     hl
        ld      (hl),a
        inc     hl
        ld      (hl),a
        inc     hl
        ld      (hl),a
        ld      a,(mp_dk)               ; the cell: column + 1 + k
        ld      hl,(mp_drc)             ; l = the row, h = the column
        add     a,h
        inc     a
        ld      b,a
        ld      a,l
        call    mp_scraddr
        ex      de,hl
        ld      hl,mp_pix
        call    mp_blit
        ld      hl,mp_dk
        inc     (hl)
        ld      a,(hl)
        cp      7
        jp      nz,dm_cell
        ret

; Read a cell back from the screen: hl = its address; the 32 bytes go to mp_pix.
mp_fetch:
        ld      a,SCRPAGE
        out     (HMPR),a
        ld      de,mp_pix
        REPT    8
        ldi
        ldi
        ldi
        ldi
        ld      a,l
        add     a,124
        ld      l,a
        jr      nc,ASMPC + 3
        inc     h
        ENDR
        jp      mp_back

; void plat_text_attr(uint8_t col, uint8_t row, uint8_t n, uint8_t attr) __smallc
; Recolours n cells of text already drawn (white on black): the pixels that are set take the ink of the attribute (the Spectrum's
; format: ink in bits 0-2, paper in bits 3-5) and the others the paper.
        PUBLIC  _plat_text_attr
_plat_text_attr:
        ld      hl,2
        add     hl,sp
        ld      a,(hl)                  ; attr
        inc     hl
        inc     hl
        ld      c,(hl)                  ; n
        inc     hl
        inc     hl
        ld      d,(hl)                  ; row
        inc     hl
        inc     hl
        ld      e,(hl)                  ; col
        ld      (mp_tn),bc
        ld      (mp_tc),de
        call    mp_mktab                ; the four byte values of the pixel pairs
ta_cell:
        ld      hl,(mp_tc)              ; e = col, d = row
        ld      a,(mp_tc)
        ld      b,a
        ld      a,(mp_tc + 1)
        call    mp_scraddr
        push    hl
        call    mp_fetch
        ld      hl,mp_pix
        ld      b,32
ta_byte:
        ld      a,(hl)
        or      a
        jr      z,ta_0
        cp      $0F
        jr      z,ta_1
        cp      $F0
        jr      z,ta_2
        cp      $FF
        jr      nz,ta_next              ; (not text: left as it is)
        ld      a,(mp_pr + 3)
        jr      ta_set
ta_0:
        ld      a,(mp_pr)
        jr      ta_set
ta_1:
        ld      a,(mp_pr + 1)
        jr      ta_set
ta_2:
        ld      a,(mp_pr + 2)
ta_set:
        ld      (hl),a
ta_next:
        inc     hl
        djnz    ta_byte
        pop     de
        ld      hl,mp_pix
        call    mp_blit
        ld      hl,mp_tc
        inc     (hl)
        ld      hl,mp_tn
        dec     (hl)
        jr      nz,ta_cell
        ret

; void plat_bar(uint8_t col, uint8_t row, uint8_t cells, uint8_t fill, uint8_t attr) __smallc
; A horizontal bar chart `cells` cells wide: the first `fill` pixels (0 to 8 * cells) in the ink of the attribute, the rest in its
; paper; each cell is six lines tall with black above and below.
        PUBLIC  _plat_bar
_plat_bar:
        ld      hl,2
        add     hl,sp
        ld      a,(hl)                  ; attr
        inc     hl
        inc     hl
        ld      c,(hl)                  ; fill
        inc     hl
        inc     hl
        ld      b,(hl)                  ; cells
        inc     hl
        inc     hl
        ld      d,(hl)                  ; row
        inc     hl
        inc     hl
        ld      e,(hl)                  ; col
        ld      (mp_bn),bc              ; (the fill, then the cells: c, then b)
        ld      (mp_tc),de
        call    mp_mktab
        ld      hl,mp_pr                ; a black paper is the dark grey of the demand bars: the track the bar is on
        ld      b,4
br_trk:
        ld      a,(hl)
        ld      c,a
        and     $F0
        jr      nz,br_t1
        ld      a,c
        or      $80
        ld      c,a
br_t1:
        ld      a,c
        and     $0F
        jr      nz,br_t2
        ld      a,c
        or      $08
        ld      c,a
br_t2:
        ld      (hl),c
        inc     hl
        djnz    br_trk
br_cell:
        ld      a,(mp_bn)               ; pixels still to fill: this cell's share, 0 to 8
        ld      c,8
        cp      8
        jr      nc,br_full
        ld      c,a
        xor     a
        jr      br_part
br_full:
        sub     8
br_part:
        ld      (mp_bn),a
        ; c = the pixels of ink in this cell: the pattern of one line, four bytes
        ld      hl,mp_bp
        ld      b,0
br_byte:
        ld      a,b
        cp      c
        ld      e,0
        jr      nc,br_l
        ld      e,2
br_l:
        ld      a,b
        inc     a
        cp      c
        jr      nc,br_r
        inc     e
br_r:
        push    hl
        ld      hl,mp_pr
        ld      d,0
        add     hl,de
        ld      a,(hl)
        pop     hl
        ld      (hl),a
        inc     hl
        inc     b
        inc     b
        ld      a,b
        cp      8
        jr      nz,br_byte
        ld      hl,mp_pix               ; black, six lines of the pattern, black
        xor     a
        ld      (hl),a
        inc     hl
        ld      (hl),a
        inc     hl
        ld      (hl),a
        inc     hl
        ld      (hl),a
        inc     hl
        ex      de,hl
        ld      b,6
br_line:
        ld      hl,mp_bp
        ld      c,4
br_copy:
        ld      a,(hl)
        ld      (de),a
        inc     hl
        inc     de
        dec     c
        jr      nz,br_copy
        djnz    br_line
        xor     a
        ld      (de),a
        inc     de
        ld      (de),a
        inc     de
        ld      (de),a
        inc     de
        ld      (de),a
        ld      a,(mp_tc)
        ld      b,a
        ld      a,(mp_tc + 1)
        call    mp_scraddr
        ex      de,hl
        ld      hl,mp_pix
        call    mp_blit
        ld      hl,mp_tc
        inc     (hl)
        ld      hl,mp_bn + 1
        dec     (hl)
        jp      nz,br_cell
        ld      a,$FF
        ld      (mp_cattr),a            ; (mp_pr is not what the text's table is made from now)
        ret

; void mp_tile1(uint8_t col, uint8_t row, const uint8_t *art, uint8_t attr, uint8_t inverse) __smallc
; 8 bytes of 1 bit art in the colours of an attribute (the icons); inverse swaps them.
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
        jp      mp_cell

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

; void plat_init(void): screen mode 4 with its pages at SCRPAGE, and the palette; the game calls this again for a new city.
        PUBLIC  _plat_init
_plat_init:
        di
        in      a,(HMPR)
        and     31
        ld      hl,mp_up
        bit     0,(hl)
        jr      nz,mp_up_done
        set     0,(hl)
        ld      (mp_dpage),a            ; the page the startup code gave the data (a second call finds it unchanged)
        add     a,2
        ld      (mp_tpage),a            ; and the pictures are in the 32 KB after it
        ld      a,(mp_tpage)
        out     (HMPR),a
        ld      hl,SCREEN
        ld      de,mp_pal
        ld      bc,24
        ldir
        ld      a,(mp_dpage)
        out     (HMPR),a
mp_up_done:
        ld      hl,mp_space             ; the nibble tables are on a 256 byte boundary: the first one in mp_space
        ld      a,l
        or      a
        jr      z,mp_aligned
        inc     h
mp_aligned:
        ld      a,h
        ld      (mp_tabhi),a
        ld      l,0
        ld      de,32
        add     hl,de
        ex      de,hl
        ld      hl,mp_ov16
        ld      bc,32
        ldir                            ; (the overlay's half is constant)
        call    mp_screen
        ld      de,mp_attrs
        ld      hl,mp_pal + 16
        ld      bc,8
        ldir
        ld      a,$FF
        ld      (mp_cattr),a            ; (no table made yet)

; The video mode, the palette and the border: what a ROM routine (the DOS) may have changed.  Uses a, b, c, hl.
        PUBLIC  mp_screen
mp_screen:
        ld      a,SCRPAGE + $60
        out     (VMPR),a
        ld      hl,mp_pal
        ld      b,0
mp_clut:
        ld      c,CLUT
        ld      a,(hl)
        out     (c),a
        inc     hl
        inc     b
        ld      a,b
        cp      16
        jr      nz,mp_clut
        xor     a
        out     ($FE),a                 ; a black border
        ret

; void plat_clear_map(void): the screen below the status panel's first six rows (from line 48) to colour 0, and the cache: what
; a mini map covers.  The panel, and the icons, stay.
        PUBLIC  _plat_clear_map
_plat_clear_map:
        ld      a,SCRPAGE
        out     (HMPR),a
        ld      hl,SCREEN + 48 * 128
        ld      de,SCREEN + 48 * 128 + 1
        ld      bc,(192 - 48) * 128 - 1
        ld      (hl),0
        ldir
        ld      a,(mp_dpage)
        out     (HMPR),a
        jr      mp_clear_cache

; void plat_clear(void): the screen to colour 0
        PUBLIC  _plat_clear
        PUBLIC  _plat_text_clear
_plat_text_clear:
_plat_clear:
        ld      a,$FF
        ld      (mp_ilast),a            ; (the icons have to be drawn again)
        ld      a,SCRPAGE
        out     (HMPR),a
        ld      hl,SCREEN
        ld      de,SCREEN + 1
        ld      bc,128 * 192 - 1
        ld      (hl),0
        ldir
        ld      a,(mp_dpage)
        out     (HMPR),a
mp_clear_cache:
        ld      hl,mp_cache             ; and no cell shows what the cache says
        ld      de,mp_cache + 1
        ld      bc,COLS * MAP_ROWS * 2 - 1
        ld      (hl),$FF
        ldir
        ret

; void plat_put_minirow(uint8_t sy, const uint8_t *colours) __smallc
; Row sy (0..47) of the mini map: 96 colours (0..7, bit 0 blue, 1 red, 2 green), one a tile, each 2 pixels wide (a byte) and 3 lines
; tall, centred in the 144 lines under the status panel (lines MM_LINE0 + 3 sy to + 2).
        PUBLIC  _plat_put_minirow
        defc    MM_LINE0 = 48
        defc    MM_BYTE = 16            ; (128 - 96) / 2: centred
_plat_put_minirow:
        ld      hl,2
        add     hl,sp
        ld      e,(hl)
        inc     hl
        ld      d,(hl)                  ; de = the colours
        inc     hl
        ld      c,(hl)                  ; sy
        ex      de,hl                   ; hl = colours
        ld      de,mm_buf
        ld      b,96
mm_conv:
        ld      a,(hl)
        inc     hl
        and     7
        push    hl
        ld      l,a
        ld      h,0
        push    de
        ld      de,mp_attrs
        add     hl,de
        pop     de
        ld      a,(hl)                  ; the palette entry of the colour
        pop     hl
        ld      (de),a
        inc     de
        djnz    mm_conv
        ; the nibbles doubled: entry * 17
        ld      hl,mm_buf
        ld      b,96
mm_dup:
        ld      a,(hl)
        ld      d,a
        add     a,a
        add     a,a
        add     a,a
        add     a,a
        or      d
        ld      (hl),a
        inc     hl
        djnz    mm_dup
        ld      a,c
        ld      l,a
        add     a,a
        add     a,l
        add     a,MM_LINE0              ; the row's first line
        srl     a                       ; its address: line * 128 + $8000
        ld      e,0
        rr      e                       ; (bit 7 of the low byte is the line's low bit)
        or      $80
        ld      d,a
        ld      a,e
        or      MM_BYTE
        ld      e,a
        ld      a,SCRPAGE
        out     (HMPR),a
        ld      c,3
mm_line:
        ld      hl,mm_buf
        ld      b,0
        push    de
        ld      b,96
mm_copy:
        ld      a,(hl)
        ld      (de),a
        inc     hl
        inc     de
        djnz    mm_copy
        pop     de
        ld      a,e
        add     a,128
        ld      e,a
        jr      nc,mm_nc
        inc     d
mm_nc:
        dec     c
        jr      nz,mm_line
        jp      mp_back

; void plat_exit(void)
        PUBLIC  _plat_exit
_plat_exit:
        ret

; uint8_t plat_key(void): the key pressed since the last call, or 0, in the game's codes (letters lower case).  The SAM's matrix is
; read as the ZX Spectrum's is: a row for each bit of the port's high byte that is low, its keys in bits 0-4 of port $FE; the
; function keys and the like are in bits 5-7 of port $F9; the shift key and the cursor keys are on their own rows.
        PUBLIC  _plat_key
_plat_key:
        call    mp_keyscan
        ld      a,(mp_event)
        ld      l,a
        ld      h,0
        xor     a
        ld      (mp_event),a
        ret

; The lowest key down is the key; one coming down is kept as the event.  Uses a, bc, de, hl.
mp_keyscan:
        ld      bc,$FEFE
        in      a,(c)
        cpl
        and     1
        ld      (mp_shift),a            ; shift (row 0, bit 0)
        ld      hl,mp_ktab
        ld      de,$FE00                ; d = the rows' select bits, e = the row
mp_ks_row:
        ld      b,d
        ld      c,$FE
        in      a,(c)
        and     $1F
        push    af
        ld      c,$F9
        in      a,(c)
        and     $E0
        ld      c,a
        pop     af
        or      c
        cpl
        ld      c,a                     ; the keys down in this row
        ld      a,e
        or      a
        ld      a,c
        jr      nz,mp_ks_any
        and     $FE                     ; (not shift: row 0 bit 0)
mp_ks_any:
        or      a
        jr      nz,mp_ks_down
        ld      bc,8
        add     hl,bc
        rlc     d
        inc     e
        ld      a,e
        cp      8
        jr      c,mp_ks_row
        jr      nz,mp_ks_none
        ld      d,$FF                   ; the ninth row: CONTROL and the cursor keys
        jr      mp_ks_row
mp_ks_none:
        xor     a
        ld      (mp_held),a             ; none down
        ret
mp_ks_down:
        ld      b,0                     ; its bit
mp_ks_bit:
        rrca
        jr      c,mp_ks_found
        inc     b
        jr      mp_ks_bit
mp_ks_found:
        ld      c,b
        ld      b,0
        add     hl,bc
        ld      a,(hl)
        ld      hl,mp_held
        cp      (hl)
        ret     z                       ; the same key, still down
        ld      (hl),a
        ld      b,a
        ld      a,(mp_shift)
        or      a
        jr      z,mp_ks_ev
        ld      a,b                     ; shift: the cursor keys go eight cells (28-31)
        sub     8
        cp      4
        jr      nc,mp_ks_ev
        ld      a,b
        add     a,20
        ld      b,a
mp_ks_ev:
        ld      a,b
        ld      (mp_event),a
        ret

; The keys, a row of eight each: row 0 SHIFT Z X C V F1 F2 F3, 1 A S D F G F4 F5 F6, 2 Q W E R T F7 F8 F9, 3 1 2 3 4 5 ESC TAB CAPS,
; 4 0 9 8 7 6 - + DELETE, 5 P O I U Y = " F0, 6 RETURN L K J H ; : EDIT, 7 SPACE SYMBOL M N B , . INV, 8 CONTROL UP DOWN LEFT RIGHT
mp_ktab:
        defb    0,'z','x','c','v',0,0,0
        defb    'a','s','d','f','g',0,0,0
        defb    'q','w','e','r','t',0,0,0
        defb    '1','2','3','4','5',27,0,0
        defb    '0','9','8','7','6','-','+',127
        defb    'p','o','i','u','y','=',0,0
        defb    13,'l','k','j','h',';',':',0
        defb    ' ',0,'m','n','b',',','.',0
        defb    0,11,10,8,9,0,0,0

; The overlay's nibble table: 16 entries of two bytes, a nibble's four pixels as a byte pair, a set pixel white (palette entry 15), the
; others left as they are.  It is copied to the second half of the aligned tables at mp_space, whose first half is made for the text's
; colours by mp_mktab (the same, with the ink and paper of the attribute).
mp_ov16:
        defb    $00,$00
        defb    $00,$0F
        defb    $00,$F0
        defb    $00,$FF
        defb    $0F,$00
        defb    $0F,$0F
        defb    $0F,$F0
        defb    $0F,$FF
        defb    $F0,$00
        defb    $F0,$0F
        defb    $F0,$F0
        defb    $F0,$FF
        defb    $FF,$00
        defb    $FF,$0F
        defb    $FF,$F0
        defb    $FF,$FF

; The placer's variables: in the code section so that they stay in the low RAM
mp_space: defs  256 + 64                ; room for 64 bytes of tables on a 256 byte boundary
mp_tabhi: defb  0                       ; the boundary's high byte
mp_pix:   defs  32                      ; the picture on its way to the screen
mp_ibuf:  defs  16 * 12                 ; a tool icon's button on its way to the screen
mp_isel:  defb  0                       ; plat_icons: the selected tool, and the icon being drawn
mp_ii:    defb  0
mp_drc:   defw  0                       ; plat_demand: the row and the column, the level, the cell
mp_dlev:  defb  0
mp_dk:    defb  0
mp_tn:    defw  0                       ; plat_text_attr: the count; plat_bar: the fill (low byte), the cells (high)
mp_tc:    defw  0                       ; the column and the row of the cell
mp_bn:    defw  0
mp_bp:    defs  4                       ; plat_bar: a line of the cell
mp_ilast: defb  $FF                    ; the tool whose icon is framed on the screen, or $FF if the icons are not drawn
mm_buf:   defs  96                      ; the mini map's row on its way to the screen
mp_gl:    defs  8
mp_pr:    defs  4                       ; the four pairs of pixels of the current attribute
mp_pal:   defs  24                      ; the palette, then the palette entries of the attribute's colours
mp_attrs: defs  8
mp_cattr: defb  $FF                     ; the attribute mp_t16 is made for
mp_dpage: defb  0                       ; HMPR while the game runs, and for its baked pictures
mp_tpage: defb  0
mp_up:    defb  0                       ; plat_init has been called
mp_shift: defb  0
mp_held:  defb  0                       ; the code of the key that is down, or 0
mp_event: defb  0                       ; the key pressed since plat_key last looked, or 0

; What each map cell shows (32 x 18 words): in the data, so used only with it paged in
        SECTION bss_user
mp_cache: defs  COLS * MAP_ROWS * 2
