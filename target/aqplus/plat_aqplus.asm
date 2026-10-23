; Aquarius+ bitmap renderer: pictures and text are both 8x8 cells put straight into the bitmap and the colour RAM.
        EXTERN  _font_8x8_bbc_system

; The 14 tool icons: four 8x8 cells each, then their colour bytes (tools/make_aq_assets.py writes assets/icons.bin).
        SECTION rodata_user
        PUBLIC  _aq_icons
_aq_icons:
        BINARY  "assets/icons.bin"

; Aquarius+ glyph placer: an 8x8 picture into a cell of the 320x200 bitmap, and the cell's colour byte.
;
;     void aq_blit8(uint8_t col, uint8_t row, const uint8_t *art, uint8_t colour, uint8_t inverse) __smallc
;     void plat_put_tile(...)            the same: the tile attributes are already colour bytes
;
; colour is the byte for the colour RAM (ink << 4 | paper).  inverse draws the picture's pixels inverted.
; The video RAM is paged into bank 3 ($C000) only while it is stored to: the engine's buffers live there too.
; When done, bank 3 is put back to the page above bank 2's, which is how the startup code (CRT_AQPLUS_BANK3_RAM)
; leaves it.  At $C000 the bitmap has 40 bytes to a pixel row, and the colour byte of a cell is at
; $E000 + row * 40 + col.  row * 40 is (row * 5) << 3 and row * 320 is (row * 5) << 6, and row * 5 fits a byte.

        SECTION code_user
        PUBLIC  _aq_blit8
        PUBLIC  _plat_put_tile
        defc    PORT_BANK2 = $F2
        IFDEF   AQ_VIDEO_BANK2          ; the all-RAM build (aqxboot): the video is paged over bank 2 ($8000); the stack and the buffers are in bank 3
        defc    VID_PORT = $F2
        defc    VID_BASE = $80          ; the high byte of the bitmap's address, and of the colour RAM's
        defc    VID_COLOUR = $A0
        MACRO   VID_PAGE_OUT
        ld      a,(aq_page2)            ; the RAM that was in bank 2 (plat_init read it)
        out     (PORT_BANK2),a
        ENDM
        ELSE                            ; the video is paged over bank 3 ($C000) where the buffers are
        defc    VID_PORT = $F3
        defc    VID_BASE = $C0
        defc    VID_COLOUR = $E0
        MACRO   VID_PAGE_OUT
        in      a,(PORT_BANK2)
        inc     a
        out     (PORT_BANK3),a
        ENDM
        ENDIF
        defc    PORT_BANK3 = $F3

_plat_put_tile:
_aq_blit8:
        ld      hl,2
        add     hl,sp
        ld      a,(hl)                  ; inverse
        or      a                       ; (nothing from here to the call changes the flags)
        inc     hl
        inc     hl
        ld      c,(hl)                  ; colour
        inc     hl
        inc     hl
        ld      e,(hl)
        inc     hl
        ld      d,(hl)                  ; de = art
        call    nz,aq_invert
        inc     hl
        ld      a,(hl)                  ; row
        inc     hl
        inc     hl
        ld      b,(hl)                  ; col
        ; falls into the cell: a = row, b = col, c = colour, de = the picture
aq_cell:
        ld      h,a
        ld      a,20                    ; the video RAM
        out     (VID_PORT),a
        ld      a,h
        add     a,a
        add     a,a
        add     a,h                     ; row * 5
        ld      l,a
        ex      af,af'                  ; keep it for the pixels
        ld      h,0
        add     hl,hl
        add     hl,hl
        add     hl,hl                   ; row * 40
        ld      a,b
        add     a,l
        ld      l,a
        ld      a,h
        adc     a,VID_COLOUR
        ld      h,a                     ; + col, in the colour RAM
        ld      (hl),c
        ex      af,af'
        ld      h,a
        ld      l,0
        srl     h
        rr      l
        srl     h
        rr      l                       ; row * 320
        ld      a,l
        or      b                       ; + col: its low bits are free
        ld      l,a
        ld      a,h
        or      VID_BASE
        ld      h,a
        ld      bc,40
        REPT    7
        ld      a,(de)
        ld      (hl),a
        inc     de
        add     hl,bc
        ENDR
        ld      a,(de)
        ld      (hl),a
        VID_PAGE_OUT
        ret

; The pixels of the picture at de, inverted, into aq_scratch; de = aq_scratch.  Keeps hl and c.
aq_invert:
        push    hl
        ld      hl,aq_scratch
        ex      de,hl
        ld      b,8
aq_invert_row:
        ld      a,(hl)
        cpl
        ld      (de),a
        inc     hl
        inc     de
        djnz    aq_invert_row
        ld      de,aq_scratch
        pop     hl
        ret


; Text: the characters are the 8x8 glyphs of the console's font, white on black.
        defc    TEXT_COLOUR = $70

; void plat_aq_printc(uint8_t col, uint8_t row, uint8_t ch) __smallc
        PUBLIC  _plat_aq_printc
        PUBLIC  _plat_put                       ; the same
_plat_put:
_plat_aq_printc:
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
aq_char:
        ld      l,a
        ld      h,0
        add     hl,hl
        add     hl,hl
        add     hl,hl                   ; ch * 8
        ld      de,_font_8x8_bbc_system - 32 * 8
        add     hl,de
        ex      de,hl                   ; de = its glyph
        ld      a,c                     ; row
        ld      c,TEXT_COLOUR
        jp      aq_cell

; void plat_puts(uint8_t col, uint8_t row, const char *s) __smallc
; Not past the right edge (column 39): it would wrap.
        PUBLIC  _plat_puts
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
aq_puts_next:
        ld      a,b
        cp      40
        ret     nc
        ld      a,(de)
        or      a
        ret     z
        inc     de
        push    de
        push    bc
        call    aq_char
        pop     bc
        pop     de
        inc     b
        jr      aq_puts_next

; The video mode and the screen, without the generic console: the game draws everything itself.
        defc    PORT_VCTRL = $E0
        defc    VCTRL_TEXT = 1                  ; the text screen
        defc    VCTRL_BITMAP = 4                ; the 320x200 bitmap, text off

; void plat_init(void): the default palette (the colour numbers of tools/make_aq_assets.py), then the bitmap, cleared
        EXTERN  set_default_palette
        PUBLIC  _plat_init
_plat_init:
        IFDEF   AQ_VIDEO_BANK2
        in      a,(PORT_BANK2)          ; the RAM page the video is paged over, to put back after every cell
        ld      (aq_page2),a
        ENDIF
        call    set_default_palette
        ld      a,VCTRL_BITMAP
        out     (PORT_VCTRL),a
        ; and clear it

; void plat_clear(void): the bitmap (40 x 25 cells of 8 bytes) to 0 and the colour RAM (1000 bytes) to white on black
        PUBLIC  _plat_clear
_plat_clear:
        ld      a,20                    ; the video RAM
        out     (VID_PORT),a
        ld      hl,VID_BASE * 256
        ld      de,VID_BASE * 256 + 1
        ld      bc,40 * 25 * 8 - 1
        ld      (hl),l
        ldir
        ld      hl,VID_COLOUR * 256
        ld      de,VID_COLOUR * 256 + 1
        ld      bc,40 * 25 - 1
        ld      (hl),TEXT_COLOUR
        ldir
        VID_PAGE_OUT
        ret

; void plat_exit(void): back to the text screen
        PUBLIC  _plat_exit
_plat_exit:
        ld      a,VCTRL_TEXT
        out     (PORT_VCTRL),a
        ret

; The inverted copy of a picture that aq_invert makes: in the code section, so that it is not under the video RAM (bank 2 in the all-RAM build).
aq_scratch:
        defs    8
        IFDEF   AQ_VIDEO_BANK2
aq_page2:
        defb    0                       ; (in the code section, not under the video RAM)
        ENDIF
