; ZX Spectrum Next platform (Layer 2, 256x192, a byte a pixel: the palette entry of the pixel): the drawing primitives plat_zxn.c uses.
;
; Layer 2 is in 8 KB pages from ZXN_SCREEN_PAGE, 32 lines of 256 bytes to a page, so the 8 lines of a character cell (and a line
; of any width up to 256) are in one page.  The page is mapped into the MMU's slot 7 ($E000-$FFFF, NextReg $57) for as long as a
; routine draws, and the baked pictures (the atlas, in three 16 KB banks, 8 KB pages ZXN_ATLAS_PAGE up) into slot 6 ($C000, NextReg
; $56).  The game's own RAM is there normally: the program is at $0000 (slots 0 to 4: the low 16 KB in a bank
; appmake's loader maps), then the stack and the uninitialised data from $A400, so these two windows are over the big arrays (the
; maps), which nothing reads while a routine here draws; the routines put the pages back (PAGE_SLOT6, 7) before they return.  What they use (the
; stack, the placer's buffers) is below $C000.
;
; The routines take their arguments the way the game's C code passes them (smallc: first argument first, the caller cleans up), a
; byte argument being the low byte of a word.  Uses all registers but IX.

        SECTION code_user

        defc    ZXN_SCREEN_PAGE = 18   ; Layer 2's first 8 KB page (16 KB bank 9, where NextReg $12 puts it by default)
        defc    ZXN_ATLAS_PAGE = 40    ; the pictures: the first 16 KB bank is bank 20, the second 21 and the third 22 (zxn_data.asm), 128 pictures to each of the 8 KB pages 40 to 44
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
; uint8_t plat_pointer_keys(void): the keys that drive the pointer, as what is down now (the game's own plat_key reports a key once, when it goes down):
; bit 0 left, 1 right, 2 up, 3 down, 4 fire, 5 fast.  Q A O P, and Caps Shift with 5 6 7 8 (the Next's cursor keys); fire is Space (not with Caps Shift:
; that is Esc) or Enter; fast is a letter with Caps Shift, or anything with Symbol Shift.  Uses all registers but IX.
        PUBLIC  _plat_pointer_keys
_plat_pointer_keys:
        ld      d,0                     ; the letters' directions
        ld      e,0                     ; the cursor keys' (then everything)
        ld      bc,$FEFE
        in      a,(c)
        and     1
        ld      h,a                     ; 0 if Caps Shift is down
        ld      b,$7F
        in      a,(c)
        ld      l,a                     ; Space (bit 0) and Symbol Shift (bit 1)
        ld      b,$FB
        in      a,(c)
        rra
        jr      c,pk_nq
        set     2,d                     ; Q up
pk_nq:  ld      b,$FD
        in      a,(c)
        rra
        jr      c,pk_na
        set     3,d                     ; A down
pk_na:  ld      b,$DF
        in      a,(c)
        rra
        jr      c,pk_np
        set     1,d                     ; P right
pk_np:  rra
        jr      c,pk_no
        set     0,d                     ; O left
pk_no:  ld      a,h
        or      a
        jr      nz,pk_nocur             ; the cursor keys are Caps Shift with 5 to 8
        ld      b,$F7
        in      a,(c)
        bit     4,a
        jr      nz,pk_n5
        set     0,e                     ; 5 left
pk_n5:  ld      b,$EF
        in      a,(c)
        bit     4,a
        jr      nz,pk_n6
        set     3,e                     ; 6 down
pk_n6:  bit     3,a
        jr      nz,pk_n7
        set     2,e                     ; 7 up
pk_n7:  bit     2,a
        jr      nz,pk_nocur
        set     1,e                     ; 8 right
pk_nocur:
        ld      a,d
        or      e
        ld      e,a                     ; the directions
        bit     1,l
        jr      nz,pk_nosym
        set     5,e                     ; Symbol Shift: fast
pk_nosym:
        ld      a,h
        or      a
        jr      nz,pk_space
        ld      a,d
        or      a
        jr      z,pk_nospace            ; Caps Shift: a letter's direction is fast, and Space is Esc
        set     5,e
        jr      pk_nospace
pk_space:
        bit     0,l
        jr      nz,pk_nospace
        set     4,e                     ; Space: fire
pk_nospace:
        ld      b,$BF
        in      a,(c)
        rra
        jr      c,pk_noenter
        set     4,e                     ; Enter: fire
pk_noenter:
        ld      l,e
        ld      h,0
        ret

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

; The pointer's arrow, hardware sprite 0 (zxn_mouse.c).  Its 16x16 pixels, the tip at the top left, are a row of outline and fill words each: the outline black (pen 1),
; the fill white (pen 2) over it, the rest the transparent index.  The pens are the first sprite palette's, which this sets, and the sprites are turned on.
        PUBLIC  _zxn_sprite_define
        defc    PEN_CLEAR = $E3
_zxn_sprite_define:
        ld      bc,$243B
        ld      a,$43                   ; REG_PALETTE_CONTROL
        out     (c),a
        inc     b
        in      a,(c)
        ld      e,a                     ; as it was
        and     $0F
        or      $20                     ; the first sprite palette
        nextreg $43,a
        nextreg $40,1
        nextreg $41,$00                 ; pen 1 black
        nextreg $40,2
        nextreg $41,$FF                 ; pen 2 white
        ld      a,e
        nextreg $43,a
        ld      bc,$303B
        xor     a
        out     (c),a                   ; pattern 0
        ld      ix,arrow_rows
        ld      c,16
sd_row: ld      e,(ix+0)
        ld      d,(ix+1)                ; the outline
        ld      l,(ix+2)
        ld      h,(ix+3)                ; the fill
        ld      b,16
sd_px:  ld      a,PEN_CLEAR
        add     hl,hl
        jr      nc,sd_nofill
        ld      a,2
        ex      de,hl
        add     hl,hl
        ex      de,hl
        jr      sd_put
sd_nofill:
        ex      de,hl
        add     hl,hl
        ex      de,hl
        jr      nc,sd_put
        ld      a,1
sd_put: out     ($5B),a
        djnz    sd_px
        inc     ix
        inc     ix
        inc     ix
        inc     ix
        dec     c
        jr      nz,sd_row
        ld      bc,$243B
        ld      a,$15                   ; REG_SPRITE_LAYER_SYSTEM
        out     (c),a
        inc     b
        in      a,(c)
        or      1                       ; the sprites visible
        nextreg $15,a
        ret

; void zxn_sprite_at(int16_t x, int16_t y) __smallc: sprite 0's tip at screen pixel (x,y) (the sprites' origin is (32,32)), or hidden with x < 0
        PUBLIC  _zxn_sprite_at
_zxn_sprite_at:
        ld      bc,$303B
        xor     a
        out     (c),a
        ld      hl,2
        add     hl,sp
        ld      a,(hl)                  ; y
        add     a,32
        ld      d,a
        inc     hl
        inc     hl
        ld      e,(hl)
        inc     hl
        ld      h,(hl)
        ld      l,e                     ; x
        ld      e,$80                   ; visible, pattern 0
        bit     7,h
        jr      z,sa_shown
        ld      e,0
sa_shown:
        ld      bc,32
        add     hl,bc
        ld      c,$57
        out     (c),l                   ; x, low 8 bits
        out     (c),d
        out     (c),h                   ; no palette offset or mirrors; the x's top bit
        out     (c),e
        ret

arrow_rows:                             ; outline, fill: a word each, the leftmost pixel the top bit
        defw    $8000,$0000, $C000,$0000, $A000,$4000, $9000,$6000
        defw    $8800,$7000, $8400,$7800, $8200,$7C00, $8100,$7E00
        defw    $8080,$7F00, $8040,$7F80, $83E0,$7C00, $9200,$6C00
        defw    $A900,$4600, $C900,$0600, $8480,$0300, $0700,$0000
