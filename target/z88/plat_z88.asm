; Z88 OZ support, icons and generic-console font pointers.
;
;     void z88_sop(const char *s) __z88dk_fastcall      write a string to the current OZ window
;
; This is GN_Sop, OZ's own string output: it understands the VDU codes (1,'3','@',x,y positions the
; cursor, 12 clears the window, 1,'2','C',n selects window n), which is how the status text is put in
; the Z88's text window while the console itself is drawing the map into the graphics window.

        SECTION code_clib
        PUBLIC  _z88_sop
        INCLUDE "stdio.def"
        INCLUDE "director.def"

; The 14 tool icons as OZ character rows (tools/make_z88_icons.py): 4 cells of 8 rows each.
        SECTION rodata_user
        PUBLIC  _z88_icons
_z88_icons:
        BINARY  "assets/z88_icons.bin"

        SECTION code_clib
; void plat_set_name(const char *name) __z88dk_fastcall: the city's name for OZ's Index (DC_Nam, which keeps IX)
        PUBLIC  _plat_set_name
_plat_set_name:
        call_oz (dc_nam)
        ret

_z88_sop:
        call_oz (gn_sop)                ;HL = the string; preserves IX and IY
        ret

; The generic console's three drawing variables, defined here instead of taking the library's copies.
;
; The console draws the map by paging the map's RAM bank into segment 1 ($4000-$7FFF), and while it is
; there it reads these variables.  The library keeps them in the data section, which a ROM build puts
; after all of the BSS, and the engine's buffers make the BSS 16 KB, so the variables ended up above $4000:
; the console then read the map's own memory in place of its font pointer and drew junk.  Here they are
; in bss_compiler, low in RAM.  (The library's definitions are not linked once these exist.)  They start
; at zero; plat_init sets the font and UDG pointers.

        SECTION bss_compiler
        PUBLIC  generic_console_flags
        PUBLIC  generic_console_font32
        PUBLIC  generic_console_udg32

generic_console_flags:  defb    0
generic_console_font32: defw    0
generic_console_udg32:  defw    0

        SECTION code_clib
        PUBLIC  _plat_set_font
        PUBLIC  _plat_set_udgs
_plat_set_font:
        ld      (generic_console_font32),hl
        ret
_plat_set_udgs:
        ld      (generic_console_udg32),hl
        ret

; void plat_demand(uint8_t col, uint8_t row, char name, int8_t level) __smallc
; A demand indicator: the letter, then 3 cells to the left of the zero mark, the mark and 3 cells to the right.  `level` is -27..27
; zones of imbalance, shown as 0 to 18 pixels each side of the mark, 1.5 zones a pixel (rounded up: any demand shows).  The cells are the
; user defined characters of plat_z88.c (define_icons): DEMAND_FIRST is the zero mark, then bars of 1 to 5 pixels from a cell's left
; edge, then the track (a cell with no bar).  A "-" comes before the cells and a "+" after them.  A full cell is a space in reverse video, and a bar to the left is the bar of the other 6 - n pixels in reverse video.
        SECTION code_clib
        PUBLIC  _plat_demand
        EXTERN  _icons_ok
        EXTERN  _define_icons
        defc    DEMAND_FIRST = 120
        defc    Z88_TEXT_X = 2                  ; (the same as plat_z88.c's)

_plat_demand:
        ld      a,(_icons_ok)
        or      a
        call    z,_define_icons
        ld      hl,2
        add     hl,sp
        ld      a,(hl)                  ; the level
        ld      e,0                     ; e = 1 if it is more demand
        or      a
        jr      z,dm_abs
        jp      p,dm_pos
        neg
        jr      dm_abs
dm_pos: inc     e
dm_abs: add     a,a
        inc     a
        ld      b,0
dm_div: sub     3                       ; b = (2 * |level| + 1) / 3: the pixels
        jr      c,dm_done
        inc     b
        jr      dm_div
dm_done:
        ld      a,b
        ld      (dm_total),a
        ld      a,e
        ld      (dm_right),a
        inc     hl
        inc     hl
        ld      a,(hl)                  ; the letter
        ld      (dm_buf + 5),a
        inc     hl
        inc     hl
        ld      a,(hl)                  ; the row
        add     a,32 + 1
        ld      (dm_buf + 4),a
        inc     hl
        inc     hl
        ld      a,(hl)                  ; the column
        add     a,32 + 1 + Z88_TEXT_X
        ld      (dm_buf + 3),a
        ld      hl,dm_buf
        ld      (hl),1
        inc     hl
        ld      (hl),'3'
        inc     hl
        ld      (hl),'@'
        ld      de,dm_buf + 6
        ld      a,'-'                   ; "- ... | ... +": too much on the left, more wanted on the right
        ld      (de),a
        inc     de
        ld      c,0
dm_cell:
        ld      a,c
        sub     3
        ld      h,0                     ; h = 1 for a cell left of the mark
        ld      b,DEMAND_FIRST          ; (the zero mark)
        jr      z,dm_zero
        jr      nc,dm_side
        neg
        inc     h
dm_side:
        dec     a                       ; 0..2 cells from the mark
        ld      b,a
        add     a,a
        add     a,b
        add     a,a                     ; 6 pixels a cell
        ld      b,a
        ld      a,(dm_total)
        sub     b
        jr      c,dm_blank
        jr      z,dm_blank
        cp      7
        jr      c,dm_px
        ld      a,6
dm_px:  ld      b,a                     ; b = the pixels in this cell, 1..6
        ld      a,(dm_right)
        xor     h
        jr      z,dm_blank              ; the other side of the mark
        ld      a,h
        or      a
        jr      z,dm_rt
        ld      a,6                     ; to the left: the bar of the other 6 - n pixels, reversed
        sub     b
        ld      b,a
        jr      dm_rv
dm_rt:  ld      a,b                     ; to the right: 1..5 pixels a bar, 6 a full cell: a space reversed
        cp      6
        jr      nz,dm_plain
        ld      b,0
dm_rv:  ld      a,b
        ld      l,1                     ; reversed
        jr      dm_chr
dm_plain:
        ld      l,0
dm_chr: or      a                       ; a = the pixels of the bar: none is a space, else a character
        ld      b,32
        jr      z,dm_set
        add     a,DEMAND_FIRST
        ld      b,a
dm_set: ld      a,l
        jr      dm_emit
dm_blank:
        ld      b,DEMAND_FIRST + 6      ; the track
dm_zero:
        xor     a                       ; (the zero mark: a is 0 from the sub; a blank: not reversed)
dm_emit:
        ld      h,a                     ; the reverse flag
        or      a
        call    nz,dm_rev
        ld      a,b
        cp      32
        jr      z,dm_raw
        ld      a,1
        ld      (de),a
        inc     de
        ld      a,'2'
        ld      (de),a
        inc     de
        ld      a,'?'
        ld      (de),a
        inc     de
        ld      a,b
dm_raw: ld      (de),a
        inc     de
        ld      a,h
        or      a
        call    nz,dm_rev
        inc     c
        ld      a,c
        cp      7
        jr      nz,dm_cell
        ld      a,'+'
        ld      (de),a
        inc     de
        xor     a
        ld      (de),a
        ld      hl,dm_buf
        jp      _z88_sop

dm_rev: ld      a,1
        ld      (de),a
        inc     de
        ld      a,'R'
        ld      (de),a
        inc     de
        ret

        SECTION bss_compiler
dm_buf:   defs  6 + 1 + 7 * 5 + 1 + 1
dm_total: defb  0
dm_right: defb  0

; void plat_icons(uint8_t selected) __smallc
; The 14 tool icons, 2 x 2 user defined characters each (plat_z88.c's define_icons), in rows 3 and 4 of the text area: the selected tool
; in reverse video, and the tools that cost more than the money greyed out (the costs are the game's: tool_costs in ui/game.c, the
; coal power station).
        SECTION code_clib
        PUBLIC  _plat_icons
        EXTERN  _V_money
        defc    ICON_FIRST = 64

_plat_icons:
        ld      a,(_icons_ok)
        or      a
        call    z,_define_icons
        ld      hl,2
        add     hl,sp
        ld      a,(hl)
        ld      (ic_sel),a
        xor     a
        ld      (ic_row),a
ic_rows:
        ld      de,ic_buf
        ld      a,1
        ld      (de),a
        inc     de
        ld      a,'3'
        ld      (de),a
        inc     de
        ld      a,'@'
        ld      (de),a
        inc     de
        ld      a,32 + 1 + Z88_TEXT_X
        ld      (de),a
        inc     de
        ld      a,(ic_row)
        add     a,32 + 1 + 3
        ld      (de),a
        inc     de
        ld      c,0                     ; the icon
ic_icon:
        ld      a,(ic_sel)
        cp      c
        call    z,dm_rev                ; the selected one in reverse
        call    ic_afford
        call    c,ic_grey               ; no money for it: grey
        ld      a,c
        add     a,a
        add     a,a
        ld      b,a
        ld      a,(ic_row)
        add     a,a
        add     a,b
        add     a,ICON_FIRST
        ld      b,a
        call    ic_udg
        inc     b
        call    ic_udg
        call    ic_afford
        call    c,ic_grey
        ld      a,(ic_sel)
        cp      c
        call    z,dm_rev
        inc     c
        ld      a,c
        cp      14
        jr      nz,ic_icon
        xor     a
        ld      (de),a
        ld      hl,ic_buf
        call    _z88_sop
        ld      hl,ic_row
        inc     (hl)
        ld      a,(hl)
        cp      2
        jr      nz,ic_rows
        ret

; carry set if the money does not reach the cost of icon c (de and c are kept)
ic_afford:
        ld      a,(_V_money + 2)
        or      a
        ret     nz                      ; (carry clear)
        push    de
        ld      hl,ic_cost
        ld      e,c
        ld      d,0
        add     hl,de
        add     hl,de
        ld      e,(hl)
        inc     hl
        ld      d,(hl)
        ld      hl,(_V_money)
        or      a
        sbc     hl,de
        pop     de
        ret

ic_udg: ld      a,1                     ; the character b
        ld      (de),a
        inc     de
        ld      a,'2'
        ld      (de),a
        inc     de
        ld      a,'?'
        ld      (de),a
        inc     de
        ld      a,b
        ld      (de),a
        inc     de
        ret

ic_grey:                                ; 1, 'G': the grey toggle (the window is not greyed otherwise)
        ld      a,1
        ld      (de),a
        inc     de
        ld      a,'G'
        ld      (de),a
        inc     de
        ret

ic_cost:
        defw    1, 10, 5, 20, 10, 100, 100, 100, 500, 500, 3000, 3000, 5000, 10000

        SECTION bss_compiler
ic_buf: defs    5 + 14 * 16 + 1                ; (a reverse and a grey toggle on each side of the 8 bytes of two characters)
ic_sel: defb    0
ic_row: defb    0
