; ZX Spectrum Next platform (Layer 2, 256x192, a byte a pixel: the palette entry of the pixel): the drawing primitives plat_zxn.c uses.
;
; Layer 2 is in 8 KB pages from ZXN_SCREEN_PAGE, 32 lines of 256 bytes to a page, so the 8 lines of a character cell (and a line
; of any width up to 256) are in one page.  The page is mapped into the MMU's slot 7 ($E000-$FFFF, NextReg $57) for as long as a
; routine draws, and the baked pictures (the atlas, in two 16 KB banks, 8 KB pages ZXN_ATLAS_PAGE up) into slot 6 ($C000, NextReg
; $56).  The game's own RAM is there normally: the program is at $0000 (slots 0 to 4: the low 16 KB in a bank
; appmake's loader maps), then the stack and the uninitialised data from $A400, so these two windows are over the big arrays (the
; maps), which nothing reads while a routine here draws; the routines put the pages back (PAGE_SLOT6, 7) before they return.  What they use (the
; stack, the placer's buffers) is below $C000.
;
; The routines take their arguments the way the game's C code passes them (smallc: first argument first, the caller cleans up), a
; byte argument being the low byte of a word.  Uses all registers but IX.

        SECTION code_user

        defc    ZXN_SCREEN_PAGE = 18   ; Layer 2's first 8 KB page (16 KB bank 9, where NextReg $12 puts it by default)
        defc    ZXN_ATLAS_PAGE = 40    ; the pictures: the first 16 KB bank is bank 20, the second 21 (the Makefile's BANK_20 and BANK_21)
        defc    REG_ATLAS = $56                 ; slot 6, the atlas window, at $C000
        defc    REG_SCREEN = $57                ; slot 7, the screen window, at $E000
        defc    PAGE_SLOT6 = 0                  ; what the loader maps in slots 6 and 7: 8 KB pages 0 and 1 (bank 0), the uninitialised data's
        defc    PAGE_SLOT7 = 1

; Maps the page of pixel line a into slot 7 and gives the address of the line in hl (x = 0).  Uses a.
zxn_line_addr:
        ld      h,a
        rlca
        rlca
        rlca
        and     7
        add     a,ZXN_SCREEN_PAGE
        nextreg REG_SCREEN,a
        ld      a,h
        and     31
        or      $E0
        ld      h,a
        ld      l,0
        ret

; The data's pages back in the windows
zxn_done:
        ld      a,PAGE_SLOT6
        nextreg REG_ATLAS,a
zxn_done2:
        ld      a,PAGE_SLOT7
        nextreg REG_SCREEN,a
        ret

; hl = the address of the cell at row a, column b, with its page mapped.  Uses a.
zxn_cell_addr:
        add     a,a
        add     a,a
        add     a,a                     ; the cell's first pixel line
        call    zxn_line_addr
        ld      a,b
        add     a,a
        add     a,a
        add     a,a
        ld      l,a
        ret

; void zxn_tile(uint8_t col, uint8_t row, uint16_t pic, uint8_t inverse) __smallc
; Picture number `pic` of the atlas at the cell: inverse draws the colour indexes 64 up (the same colours inverted in the palette: the cursor).
; The art's pixels are the palette entries 16 to 79 (tools/st_tiles_3bpp.py --zxn); the interface's colours are entries 0 to 15.
        PUBLIC  _zxn_tile
_zxn_tile:
        ld      hl,2
        add     hl,sp
        ld      c,(hl)                  ; inverse
        inc     hl
        inc     hl
        ld      e,(hl)                  ; pic
        inc     hl
        ld      d,(hl)
        inc     hl
        ld      a,(hl)                  ; row
        inc     hl
        inc     hl
        ld      b,(hl)                  ; col
        push    af
        ex      de,hl                   ; hl = pic
        push    hl
        add     hl,hl
        ld      a,h                     ; pic >> 7: the 8 KB page of the picture
        add     a,ZXN_ATLAS_PAGE
        nextreg REG_ATLAS,a
        pop     hl
        add     hl,hl
        add     hl,hl
        add     hl,hl
        add     hl,hl
        add     hl,hl
        add     hl,hl                   ; * 64
        ld      a,h
        and     $1F
        or      $C0
        ld      h,a                     ; the picture in slot 6
        push    hl
        pop     de                      ; (de = it)
        pop     af                      ; the row
        call    zxn_cell_addr
        ex      de,hl                   ; hl = the picture, de = the cell
        ld      a,c
        or      a
        jp      nz,nt_inv
        REPT    8
        push    de
        ldi
        ldi
        ldi
        ldi
        ldi
        ldi
        ldi
        ldi
        pop     de
        inc     d
        ENDR
        jp      zxn_done
nt_inv:
        ld      b,8
nt_line:
        push    de
        ld      c,8
nt_px:
        ld      a,(hl)
        add     a,64
        ld      (de),a
        inc     hl
        inc     de
        dec     c
        jr      nz,nt_px
        pop     de
        inc     d
        djnz    nt_line
        jp      zxn_done

; void zxn_glyph(uint8_t col, uint8_t row, const uint8_t *art, uint8_t ink, uint8_t paper) __smallc
; 8 bytes of 1 bit art (a byte a line, bit 7 on the left) as a cell: a set pixel in colour ink, the others paper.
        PUBLIC  _zxn_glyph
_zxn_glyph:
        ld      hl,2
        add     hl,sp
        ld      b,(hl)                  ; paper
        inc     hl
        inc     hl
        ld      c,(hl)                  ; ink
        inc     hl
        inc     hl
        ld      e,(hl)                  ; art
        inc     hl
        ld      d,(hl)
        inc     hl
        ld      a,(hl)                  ; row
        inc     hl
        inc     hl
        push    de
        push    bc
        ld      b,(hl)                  ; col
        call    zxn_cell_addr            ; hl = the cell
        pop     bc
        pop     de                      ; de = art
        ld      a,8
        ld      (ng_n),a
ng_line:
        ld      a,(de)
        inc     de
        REPT    8
        add     a,a
        jr      c,ASMPC + 5
        ld      (hl),b
        jr      ASMPC + 3
        ld      (hl),c
        inc     l
        ENDR
        ld      a,l
        sub     8
        ld      l,a
        inc     h
        ld      a,(ng_n)
        dec     a
        ld      (ng_n),a
        jr      nz,ng_line
        jp      zxn_done2
ng_n:   defb    0

; void zxn_overlay(uint8_t col, uint8_t row, const uint8_t *art, uint8_t colour) __smallc
; The pixels set in 8 bytes of art in `colour`, over the cell: the others are left as they are.
        PUBLIC  _zxn_overlay
_zxn_overlay:
        ld      hl,2
        add     hl,sp
        ld      c,(hl)                  ; colour
        inc     hl
        inc     hl
        ld      e,(hl)                  ; art
        inc     hl
        ld      d,(hl)
        inc     hl
        ld      a,(hl)                  ; row
        inc     hl
        inc     hl
        push    de
        ld      b,(hl)                  ; col
        call    zxn_cell_addr            ; hl = the cell
        pop     de                      ; de = art
        ld      a,8
        ld      (ng_n),a
no_line:
        ld      a,(de)
        inc     de
        REPT    8
        add     a,a
        jr      nc,ASMPC + 3
        ld      (hl),c
        inc     l
        ENDR
        ld      a,l
        sub     8
        ld      l,a
        inc     h
        ld      a,(ng_n)
        dec     a
        ld      (ng_n),a
        jr      nz,no_line
        jp      zxn_done2

; void zxn_wr(uint8_t y, uint8_t x, const uint8_t *src, uint16_t len) __smallc
; len bytes from src to pixel line y from column x (x + len is at most 256).
        PUBLIC  _zxn_wr
_zxn_wr:
        ld      hl,2
        add     hl,sp
        ld      c,(hl)                  ; len
        inc     hl
        ld      b,(hl)
        inc     hl
        ld      e,(hl)                  ; src
        inc     hl
        ld      d,(hl)
        inc     hl
        ld      a,(hl)                  ; x
        inc     hl
        inc     hl
        push    af
        ld      a,(hl)                  ; y
        push    de
        call    zxn_line_addr
        pop     de
        pop     af
        ld      l,a
        ex      de,hl                   ; hl = src, de = the line
        ld      a,b
        or      c
        jp      z,zxn_done2
        ldir
        jp      zxn_done2

; void zxn_rd(uint8_t y, uint8_t x, uint8_t *dst, uint16_t len) __smallc
; len bytes of pixel line y from column x to dst.
        PUBLIC  _zxn_rd
_zxn_rd:
        ld      hl,2
        add     hl,sp
        ld      c,(hl)                  ; len
        inc     hl
        ld      b,(hl)
        inc     hl
        ld      e,(hl)                  ; dst
        inc     hl
        ld      d,(hl)
        inc     hl
        ld      a,(hl)                  ; x
        inc     hl
        inc     hl
        push    af
        ld      a,(hl)                  ; y
        push    de
        call    zxn_line_addr
        pop     de
        pop     af
        ld      l,a                     ; hl = the line
        ld      a,b
        or      c
        jp      z,zxn_done2
        ldir
        jp      zxn_done2

; void zxn_fill(uint8_t y, uint8_t x, uint16_t len, uint8_t colour) __smallc
; len pixels of line y from column x in a colour (x + len is at most 256).
        PUBLIC  _zxn_fill
_zxn_fill:
        ld      hl,2
        add     hl,sp
        ld      e,(hl)                  ; colour
        inc     hl
        inc     hl
        ld      c,(hl)                  ; len
        inc     hl
        ld      b,(hl)
        inc     hl
        ld      d,(hl)                  ; x
        inc     hl
        inc     hl
        ld      a,(hl)                  ; y
        push    de
        call    zxn_line_addr
        pop     de
        ld      l,d
        ld      a,b
        or      c
        jp      z,zxn_done2
        ld      (hl),e
        dec     bc
        ld      a,b
        or      c
        jp      z,zxn_done2
        ld      d,h
        ld      e,l                     ; (the colour is in the first pixel now)
        ld      a,(hl)
        inc     de
        ldir
        jp      zxn_done2

; void zxn_palette(const uint8_t *entries, uint8_t first, uint8_t count) __smallc
; count (up to 127) Layer 2 palette entries from `first`, two bytes each (RRRGGGBB, then the low bit of blue).
        PUBLIC  _zxn_palette
_zxn_palette:
        ld      hl,2
        add     hl,sp
        ld      b,(hl)                  ; count
        inc     hl
        inc     hl
        ld      a,(hl)                  ; first
        inc     hl
        inc     hl
        ld      e,(hl)                  ; entries
        inc     hl
        ld      d,(hl)
        ex      de,hl
        nextreg $43,%00010000           ; Layer 2's first palette is the one written
        nextreg $40,a
        sla     b                       ; two bytes an entry
np_loop:
        ld      a,(hl)
        inc     hl
        nextreg $44,a
        djnz    np_loop
        ret

; void zxn_show(void): Layer 2 on, over the ULA screen
        PUBLIC  _zxn_show
_zxn_show:
        ld      bc,$123B
        ld      a,2
        out     (c),a
        ret

; uint8_t zxn_in(uint16_t port) __smallc: the byte read from the port (the whole 16 bits are the address, as the keyboard needs)
        PUBLIC  _zxn_in
_zxn_in:
        ld      hl,2
        add     hl,sp
        ld      c,(hl)
        inc     hl
        ld      b,(hl)
        in      l,(c)
        ld      h,0
        ret

; void zxn_out(uint16_t port, uint8_t value) __smallc
        PUBLIC  _zxn_out
_zxn_out:
        ld      hl,2
        add     hl,sp
        ld      a,(hl)
        inc     hl
        inc     hl
        ld      c,(hl)
        inc     hl
        ld      b,(hl)
        out     (c),a
        ret

; void zxn_reg(uint8_t reg, uint8_t value) __smallc: a Next register
        PUBLIC  _zxn_reg
_zxn_reg:
        ld      hl,2
        add     hl,sp
        ld      e,(hl)                  ; value
        inc     hl
        inc     hl
        ld      a,(hl)                  ; reg
        ld      bc,$243B
        out     (c),a                   ; the register number to port $243B ...
        inc     b
        out     (c),e                   ; ... and the value to $253B
        ret

; void zxn_dma(uint8_t srcpage, uint16_t srcoff, uint8_t dstpage, uint16_t dstoff, uint16_t len, uint8_t dec) __smallc
; `len` bytes between two 8 KB pages of the screen by the DMA, which stops the CPU while it moves them: page srcpage is mapped into slot 6 and dstpage
; into slot 7 (the same page may be both: the move is then a memmove, upwards with dec = 0 from the first bytes, downwards with dec = 1 from the
; last, srcoff and dstoff being the offsets in the pages of the bytes it starts at).  The windows' pages are put back.  The zxnDMA is
; programmed through port $6B: WR6 disable, WR0 (a to b, the address and length follow), WR1 and WR2 (memory, up or down), WR4
; (continuous, b's address follows), WR5, load, enable.
        PUBLIC  _zxn_dma
_zxn_dma:
        ld      hl,2
        add     hl,sp
        ld      a,(hl)                  ; dec
        ld      (nd_dec),a
        inc     hl
        inc     hl
        ld      e,(hl)                  ; len
        inc     hl
        ld      d,(hl)
        ld      (nd_len),de
        inc     hl
        ld      e,(hl)                  ; dstoff
        inc     hl
        ld      d,(hl)
        set     5,d
        set     6,d
        set     7,d                     ; + $E000: the window of slot 7
        ld      (nd_dst),de
        inc     hl
        ld      a,(hl)                  ; dstpage
        inc     hl
        inc     hl
        ld      c,a
        ld      e,(hl)                  ; srcoff
        inc     hl
        ld      d,(hl)
        set     6,d
        set     7,d                     ; + $C000: the window of slot 6
        ld      (nd_src),de
        inc     hl
        ld      a,(hl)                  ; srcpage
        inc     hl
        inc     hl
        nextreg REG_ATLAS,a
        ld      a,c
        nextreg REG_SCREEN,a
        ld      bc,$006B
        ld      a,$83                   ; WR6: disable DMA
        out     (c),a
        ld      a,$7D                   ; WR0: a to b, a's address and the length follow
        out     (c),a
        ld      hl,(nd_src)
        out     (c),l
        out     (c),h
        ld      hl,(nd_len)
        out     (c),l
        out     (c),h
        ld      a,(nd_dec)
        or      a
        ld      a,$14                   ; WR1: a is memory, incrementing
        jr      z,nd_a
        ld      a,$04                   ;                  or decrementing
nd_a:   out     (c),a
        ld      a,(nd_dec)
        or      a
        ld      a,$10                   ; WR2: b is memory, incrementing
        jr      z,nd_b
        xor     a                       ;                  or decrementing
nd_b:   out     (c),a
        ld      a,$AD                   ; WR4: continuous, b's address follows
        out     (c),a
        ld      hl,(nd_dst)
        out     (c),l
        out     (c),h
        ld      a,$82                   ; WR5: stop at the end of the block
        out     (c),a
        ld      a,$CF                   ; load
        out     (c),a
        ld      a,$87                   ; enable
        out     (c),a
        jp      zxn_done
nd_dec: defb    0
nd_len: defw    0
nd_src: defw    0
nd_dst: defw    0

; void zxn_bank_read(uint8_t *dst, uint8_t page, uint16_t off, uint16_t len) __smallc
; len bytes from offset off (below 8192) of the 8 KB page `page`, which is mapped into slot 6 for the time, to dst (below $C000): the tool icons are in
; a bank of their own (zxn_data.asm).
        PUBLIC  _zxn_bank_read
_zxn_bank_read:
        ld      hl,2
        add     hl,sp
        ld      c,(hl)                  ; len
        inc     hl
        ld      b,(hl)
        inc     hl
        ld      e,(hl)                  ; off
        inc     hl
        ld      d,(hl)
        set     6,d
        set     7,d                     ; + $C000: the window of slot 6
        inc     hl
        ld      a,(hl)                  ; page
        inc     hl
        inc     hl
        push    de
        ld      e,(hl)                  ; dst
        inc     hl
        ld      d,(hl)
        nextreg REG_ATLAS,a
        pop     hl                      ; hl = the source in the window
        ld      a,b
        or      c
        jp      z,zxn_done
        ldir
        jp      zxn_done
