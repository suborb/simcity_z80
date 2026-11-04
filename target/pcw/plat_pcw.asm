; Amstrad PCW screen: 720x256 pixels, one bit each, in memory the roller RAM maps.  A byte is 8 pixels across; the 8 bytes of one 8 pixel column of a text row are
; consecutive (720 bytes a text row).  The roller RAM (256 words, one for each pixel line) is at $B600 with the screen banks paged in; the address of line y
; is ((word << 1) & $FFF0) | (word & 7) (z88dk's w_pixeladdress), so the line 8r + k of a text row r is the line 8r's address + k.
;
; The game's 40 columns of cells are centred in the 720 pixels: rows[] is the address of the top of the text row plus the margin.
; A cell of the game is 16x8 pixels: two columns, 16 bytes.  pcw_cellbuf holds a cell as the C code expanded it (the 8 bytes of the left column, then of the
; right), and pcw_blit copies it to the screen.  The screen is paged in over banks 1 and 2 at $4000 and $8000, which takes the program (below $C000) away, so
; everything that runs then, and the buffer, and the stack, is in common memory (HIMEM, $EE48 up; the stack starts below it).
;
; Unverified on a PCW: the bank numbers (z88dk's pcw graphics library uses the same), and that CP/M's screen is where the roller RAM says.

        SECTION code_himem

        PUBLIC  _pcw_init
        PUBLIC  _pcw_blit
        PUBLIC  _pcw_clear
        PUBLIC  _pcw_invert
        PUBLIC  _pcw_cellbuf
        PUBLIC  _pcw_put
        PUBLIC  _pcw_move
        PUBLIC  _pcw_mini
        PUBLIC  _pcw_minibuf
        PUBLIC  _pcw_mv_src
        PUBLIC  _pcw_mv_len
        PUBLIC  _pcw_rows
        PUBLIC  _pcw_art
        PUBLIC  _pcw_xor

        DEFC    ROLLER = $B600
        DEFC    DBL_LEFT = $F200        ; two 256 byte tables (plat_init builds them, in common memory above the code: the TPA is 61K): a source byte's high four
        DEFC    DBL_RIGHT = $F300       ; pixels drawn twice across (the left column's byte) and its low four (the right's)
        DEFC    MARGIN = 40             ; the bytes left of the 40 columns: 40 bytes, 5 columns of 8 pixels

; Page the screen in (banks 1 and 2 over $4000-$BFFF) and out again (the program's banks 5 and 6).
        MACRO   SCREEN_IN
        ld      a,$81
        out     ($F1),a
        ld      a,$82
        out     ($F2),a
        ENDM
        MACRO   SCREEN_OUT
        ld      a,$85
        out     ($F1),a
        ld      a,$86
        out     ($F2),a
        ENDM

; void pcw_init(void): the address of the top of each text row, from the roller RAM (after CP/M has cleared the screen)
_pcw_init:
        di
        SCREEN_IN
        ld      hl,ROLLER
        ld      de,_pcw_rows
        ld      b,32
init_row:
        ld      c,(hl)                  ; roller word of line 8r: bc
        inc     hl
        ld      a,(hl)
        inc     hl
        push    hl
        ld      h,a
        ld      l,c
        ld      a,c
        and     7                       ; the low three bits of the word
        ld      c,a
        add     hl,hl
        ld      a,l
        and     $F0
        or      c
        add     a,MARGIN                ; (40 columns of 16 pixels: 640 of the 720)
        ld      l,a
        jr      nc,init_nc
        inc     h
init_nc:
        ex      de,hl
        ld      (hl),e
        inc     hl
        ld      (hl),d
        inc     hl
        ex      de,hl
        pop     hl
        push    bc
        ld      bc,14                   ; the next text row's line is 8 lines on: 16 bytes of roller RAM, two read already
        add     hl,bc
        pop     bc
        djnz    init_row
        SCREEN_OUT
        ei
        ret

; the address of cell (col, row) in hl: hl = rows[row] + 16 * col.  Entry: l = col, h = row.  Returns de = address; corrupts a, hl.
cell_address:
        ld      a,l                     ; col
        ld      l,h
        ld      h,0
        add     hl,hl
        ld      de,_pcw_rows
        add     hl,de
        ld      e,(hl)
        inc     hl
        ld      d,(hl)                  ; de = rows[row]
        ld      l,a
        ld      h,0
        add     hl,hl
        add     hl,hl
        add     hl,hl
        add     hl,hl                   ; 16 * col (at most 39 * 16: no overflow)
        add     hl,de
        ex      de,hl
        ret

; void pcw_put(uint16_t colrow) __z88dk_fastcall: l = column, h = row: the 8 bytes at pcw_art (xor pcw_xor), each pixel drawn twice across, onto the screen
_pcw_put:
        push    hl                      ; the cell
        push    ix                      ; (the C code's frame pointer)
        ld      ix,_pcw_cellbuf
        ld      hl,(_pcw_art)
        ld      a,(_pcw_xor)
        ld      c,a
        ld      b,8
        ld      d,DBL_LEFT / 256
put_byte:
        ld      a,(hl)
        inc     hl
        xor     c
        ld      e,a
        ld      a,(de)
        ld      (ix+0),a                ; the left column
        inc     d
        ld      a,(de)
        ld      (ix+8),a                ; the right
        dec     d
        inc     ix
        djnz    put_byte
        pop     ix
        pop     hl
                                        ; (and on to the blit)
; void pcw_blit(uint16_t colrow) __z88dk_fastcall: l = column, h = row: the 16 bytes of pcw_cellbuf onto the screen
_pcw_blit:
        di
        call    cell_address            ; de = address
        ld      hl,_pcw_cellbuf
        ld      bc,16
        SCREEN_IN
        ldir
        SCREEN_OUT
        ei
        ret

; void pcw_move(uint16_t dst) __z88dk_fastcall: pcw_mv_len bytes from pcw_mv_src to dst, both on the screen (the one the screen scroll moves: the source and
; the destination may overlap, as in a row moved sideways); the screen is paged in for the move only
_pcw_move:
        ex      de,hl                   ; de = dst
        ld      hl,(_pcw_mv_src)
        ld      bc,(_pcw_mv_len)
        push    hl
        or      a
        sbc     hl,de                   ; carry: the source is below the destination
        pop     hl
        di
        jr      c,mv_back
        SCREEN_IN
        ldir
        jr      mv_done
mv_back:
        add     hl,bc
        dec     hl
        ex      de,hl
        add     hl,bc
        dec     hl
        ex      de,hl
        SCREEN_IN
        lddr
mv_done:
        SCREEN_OUT
        ei
        ret

; void pcw_mini(uint16_t dst) __z88dk_fastcall: the 48 pairs of bytes in pcw_minibuf (a tile pair's pixels on one line, then on the next) onto the screen from dst, one column
; (8 bytes) on for each pair: the two lines of a mini map's tile row
_pcw_mini:
        ex      de,hl
        ld      hl,_pcw_minibuf
        ld      b,48
        di
        SCREEN_IN
mini_pair:
        ld      a,(hl)
        ld      (de),a
        inc     hl
        inc     de
        ld      a,(hl)
        ld      (de),a
        inc     hl
        ex      de,hl                   ; (de is one byte on: the next pair is a column, 8 bytes, from this one's first)
        ld      a,l
        add     a,7
        ld      l,a
        jr      nc,mini_nc
        inc     h
mini_nc:
        ex      de,hl
        djnz    mini_pair
        SCREEN_OUT
        ei
        ret

; void pcw_invert(uint16_t colrow) __z88dk_fastcall: the pcw_invert_n cells from (col, row) to the right, inverted in place
_pcw_invert:
        di
        call    cell_address
        ld      a,(_pcw_invert_n)
        ld      b,a                     ; n cells
        SCREEN_IN
        ex      de,hl                   ; hl = address
inv_cell:
        ld      c,16
inv_byte:
        ld      a,(hl)
        cpl
        ld      (hl),a
        inc     hl
        dec     c
        jr      nz,inv_byte
        djnz    inv_cell
        SCREEN_OUT
        ei
        ret

; void pcw_clear(void): all 32 text rows to blank
_pcw_clear:
        di
        push    ix                      ; the C code's frame pointer
        SCREEN_IN
        ld      ix,_pcw_rows
        ld      b,32
clr_row:
        ld      l,(ix+0)
        ld      h,(ix+1)
        inc     ix
        inc     ix
        ld      e,l
        ld      d,h
        inc     de
        ld      (hl),0
        push    bc
        ld      bc,639                  ; (640 pixels: the 40 columns, 16 bytes each)
        ldir
        pop     bc
        djnz    clr_row
        SCREEN_OUT
        pop     ix
        ei
        ret

        PUBLIC  _pcw_invert_n
        SECTION bss_himem
_pcw_cellbuf:   defs    16
_pcw_art:       defs    2
_pcw_xor:       defs    1
_pcw_mv_src:    defs    2
_pcw_mv_len:    defs    2
_pcw_minibuf:   defs    96
_pcw_invert_n:  defs    1
_pcw_rows:       defs    64

