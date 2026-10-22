; ZX Spectrum platform: the game draws pictures and text itself, straight into screen memory.
;
; A cell (8x8 pixels) is 8 bytes in screen memory 256 apart, and its colour is one attribute byte:
;     pixels     $4000 | (row & $18) << 8 | (row & 7) << 5 | col
;     attribute  $5800 + row * 32 + col
; Text is the ROM's font (character 32 is at $3D00, so a character's picture is at $3C00 + ch * 8) in the
; console's usual colours.  Nothing of z88dk's console is used.
;
; The routines take their arguments the way the game's C code passes them (smallc: first argument pushed
; first, the caller cleans up).  The alternate AF holds an attribute while the cell's address is worked out;
; the ROM's interrupt routine leaves it alone.

        SECTION code_user
        defc    TEXT_ATTR = $38         ; black on white
        defc    ROM_FONT = $3C00        ; + ch * 8
        defc    FRAMES = $5C78          ; the ROM's frame counter

        EXTERN  in_Inkey

; void plat_put_tile(uint8_t col, uint8_t row, const uint8_t *art, uint8_t attr, uint8_t inverse) __smallc
; The 8 bytes of art, inverted if `inverse`, and the cell's attribute.
        PUBLIC  _plat_put_tile
_plat_put_tile:
        ld      hl,2
        add     hl,sp
        ld      a,(hl)                  ; inverse
        add     a,255
        sbc     a,a
        ld      c,a                     ; c = 0 / 255: the xor mask
        inc     hl
        inc     hl
        ld      a,(hl)                  ; attr
        ex      af,af'
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
        ; a = row, b = col, c = mask, de = art, a' = attr
zx_cell:
        call    zx_cellptr
        ld      a,h                     ; the attribute is at $5800 + (the pixel address's high bits >> 3), same low byte
        rrca
        rrca
        rrca
        and     3
        or      $58
        push    hl
        ld      h,a
        ex      af,af'
        ld      (hl),a
        pop     hl
zx_copy:
        ld      b,8
zx_copy_row:
        ld      a,(de)
        xor     c
        ld      (hl),a
        inc     de
        inc     h
        djnz    zx_copy_row
        ret

; The address of a cell's first pixel row: a = row, b = column -> hl.  Keeps bc and de.
zx_cellptr:
        ld      h,a
        and     7
        rrca
        rrca
        rrca                            ; (row & 7) << 5
        or      b
        ld      l,a
        ld      a,h
        and     $18
        or      $40
        ld      h,a
        ret

; void plat_put_bitmap(uint8_t col, uint8_t row, const uint8_t *art) __smallc
; The 8 bytes of art; the cell's attribute is left as it is.
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
        ld      c,0
        call    zx_cellptr
        jr      zx_copy

; void plat_put(uint8_t col, uint8_t row, uint8_t ch) __smallc
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
zx_char:
        ld      l,a
        ld      h,0
        add     hl,hl
        add     hl,hl
        add     hl,hl                   ; ch * 8
        ld      de,ROM_FONT
        add     hl,de
        ex      de,hl                   ; de = the character's picture
        ld      a,TEXT_ATTR
        ex      af,af'                  ; a' = its attribute
        ld      a,c                     ; row
        ld      c,0                     ; not inverted
        jr      zx_cell

; void plat_puts(uint8_t col, uint8_t row, const char *s) __smallc
; A line that runs off the right edge carries on at the start of the next row, as the console did, and
; stops at the bottom of the screen (row 24 would be the attributes).
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
zx_puts_next:
        ld      a,b
        cp      32
        jr      c,zx_puts_draw
        ld      b,0                     ; the next row
        inc     c
        ld      a,c
        cp      24
        ret     nc
zx_puts_draw:
        ld      a,(de)
        or      a
        ret     z
        inc     de
        push    de
        push    bc
        call    zx_char
        pop     bc
        pop     de
        inc     b
        jr      zx_puts_next

; void plat_clear(void): the pixels 0 and the attributes black on white.  (plat_init and plat_exit are the same.)
        PUBLIC  _plat_clear
        PUBLIC  _plat_text_clear
        PUBLIC  _plat_init
        PUBLIC  _plat_exit
_plat_text_clear:
_plat_init:
_plat_exit:
_plat_clear:
        ld      hl,$4000
        ld      de,$4001
        ld      bc,6144 - 1
        ld      (hl),l
        ldir
        ld      hl,$5800
        ld      de,$5801
        ld      bc,768 - 1
        ld      (hl),TEXT_ATTR
        ldir
        ret

; uint8_t plat_key(void): the library's keyboard reader
        PUBLIC  _plat_key
_plat_key:
        jp      in_Inkey

; void plat_idle(void), uint16_t plat_clock(void): the frame counter with a count of the frames drawn
        PUBLIC  _plat_idle
        PUBLIC  _plat_clock
_plat_idle:
        ld      hl,(zx_frames)
        inc     hl
        ld      (zx_frames),hl
        ret
_plat_clock:
        ld      hl,(FRAMES)
        ld      de,(zx_frames)
        ld      a,h
        xor     d
        ld      h,a
        ld      a,l
        xor     e
        ld      l,a
        ret

; void plat_flush(void)
        PUBLIC  _plat_flush
_plat_flush:
        ret

        SECTION bss_user
zx_frames:
        defw    0
