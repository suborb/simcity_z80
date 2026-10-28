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
        defc    VID_PORT = $F3          ; the video RAM is paged over bank 3 ($C000), where the buffers are
        defc    VID_BASE = $C0          ; the high byte of the bitmap's address, and of the colour RAM's
        defc    VID_COLOUR = $E0
        MACRO   VID_PAGE_OUT
        in      a,(PORT_BANK2)
        inc     a
        out     (PORT_BANK3),a
        ENDM
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
        ld      a,(_aq_mm4)             ; a cell over the 4bpp mini map (a dialogue): the 1bpp screen first
        or      a
        jp      nz,aq_cell_leave
aq_cell_go:
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
        IFDEF   HAVE_SOUND
        EXTERN  ay_poll
        jp      ay_poll                 ; (the sound's ticks go on while the screen is drawn)
        ELSE
        ret
        ENDIF

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
        cp      32
        jr      nc,aq_ch_font
        ld      l,a                     ; a line piece of the boxes' frames: codes 1 to 6
        ld      h,0
        add     hl,hl
        add     hl,hl
        add     hl,hl
        ld      de,aq_box - 8
        add     hl,de
        ex      de,hl
        ld      a,c                     ; row
        ld      c,TEXT_COLOUR
        jp      aq_cell
aq_ch_font:
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
        call    set_default_palette
        ld      a,VCTRL_BITMAP
        out     (PORT_VCTRL),a
        ; and clear it

; void plat_clear(void): the bitmap (40 x 25 cells of 8 bytes) to 0 and the colour RAM (1000 bytes) to white on black
        PUBLIC  _plat_clear
_plat_clear:
        ld      a,(_aq_mm_want)
        or      a
        jp      nz,_aq_mm_enter         ; (the mini map is up: its picture and text are cleared instead)
aq_clear_1bpp:
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

; void aq_colours(uint8_t col, uint8_t row, uint8_t n, uint8_t colour) __smallc
; The colour bytes of n cells from (col, row) to `colour` (ink << 4 | paper), and nothing else: the pictures stay as they are, so a
; screen of text is coloured by this alone.  The cells are on one row (the colour RAM is 40 bytes a row).
        PUBLIC  _aq_colours
_aq_colours:
        ld      a,(_aq_mm4)
        or      a
        call    nz,_aq_mm_leave
        ld      hl,2
        add     hl,sp
        ld      c,(hl)                  ; colour
        inc     hl
        inc     hl
        ld      b,(hl)                  ; n
        inc     hl
        inc     hl
        ld      e,(hl)                  ; row
        inc     hl
        inc     hl
        ld      a,(hl)                  ; col
        ld      d,0
        ld      h,d
        ld      l,e
        add     hl,hl
        add     hl,hl
        add     hl,de                   ; row * 5
        add     hl,hl
        add     hl,hl
        add     hl,hl                   ; row * 40
        ld      e,a
        add     hl,de                   ; + col
        ld      de,VID_COLOUR * 256
        add     hl,de
        ld      a,b
        or      a
        ret     z
        ld      a,20                    ; the video RAM
        out     (VID_PORT),a
aq_col_fill:
        ld      (hl),c
        inc      hl
        djnz    aq_col_fill
        VID_PAGE_OUT
        ret

; void aq_vcopy(uint16_t offset, const uint8_t *src, uint8_t n) __smallc
; n bytes from src into the video RAM page at `offset` (the bitmap from 0: 40 bytes a pixel row, 320 a cell row; the colour RAM from $2000).
; src must be below the video window (the mini map's row buffer is: aq_mm_buf, in the code section).
        PUBLIC  _aq_vcopy
        PUBLIC  _aq_mm_buf
_aq_vcopy:
        ld      hl,2
        add     hl,sp
        ld      b,(hl)                  ; n
        inc     hl
        inc     hl
        ld      e,(hl)
        inc     hl
        ld      d,(hl)                  ; src
        inc     hl
        ld      c,(hl)
        inc     hl
        ld      a,(hl)                  ; the offset
        add     a,VID_BASE
        ld      h,a
        ld      l,c                     ; hl = where, de = from
        ld      a,b
        or      a
        ret     z
        ld      c,b
        ld      b,0
        ld      a,20                    ; the video RAM
        out     (VID_PORT),a
        ex      de,hl
        ldir
        VID_PAGE_OUT
        IFDEF   HAVE_SOUND
        jp      ay_poll                 ; (the frames are counted, and the sound's ticks go on, as the mini map's rows are drawn)
        ELSE
        ret
        ENDIF

; ---- The 4bpp mini map: the 160x200 bitmap (two display pixels wide, so a tile is one pixel by two lines), the text layer over it for the sidebar
; (our font in the character RAM: ASCII 32 to 127 as the characters 160 to 255, the sidebar's own pictures from 128).  _aq_mm_want says a mini map is up (plat_clear then clears its picture, not the 1bpp screen); _aq_mm4 that the
; hardware is in its mode.
        PUBLIC  _aq_mm4
        PUBLIC  _aq_mm_want
        PUBLIC  _aq_mm_enter
        PUBLIC  _aq_mm_leave
        PUBLIC  _aq_tcell
        PUBLIC  _aq_defchar
        defc    VCTRL_MM4 = $1F                 ; text on and in front, mode 3, sprites
        defc    VCTRL_1BPP = $0C                ; mode 2, sprites, text off
        defc    CHR_SAVED = 128                 ; the characters 128 to 255 are ours while the mini map is up
_aq_mm4:
        defb    0
_aq_mm_want:
        defb    0

; void aq_mm_enter(void): into the mode (when not in it already), the picture and the text cleared
_aq_mm_enter:
        ld      a,(_aq_mm4)
        or      a
        jr      nz,aq_mm_clear
        inc     a
        ld      (_aq_mm4),a
        ld      a,21                    ; the character RAM: keep characters 128 to 255, ours from the font (160 up) and 128 to 159 blank
        out     (VID_PORT),a
        ld      hl,VID_BASE * 256 + CHR_SAVED * 8
        ld      de,aq_chr_save
        ld      bc,1024
        ldir
        ld      hl,VID_BASE * 256 + CHR_SAVED * 8
        ld      de,VID_BASE * 256 + CHR_SAVED * 8 + 1
        ld      (hl),0
        ld      bc,32 * 8 - 1
        ldir
        ld      hl,_font_8x8_bbc_system
        ld      de,VID_BASE * 256 + 160 * 8
        ld      bc,96 * 8
        ldir
        VID_PAGE_OUT
aq_mm_clear:
        ld      a,20                    ; the 4bpp bitmap to 0 (black)
        out     (VID_PORT),a
        ld      hl,VID_BASE * 256
        ld      de,VID_BASE * 256 + 1
        ld      (hl),0
        ld      bc,16000 - 1
        ldir
        in      a,(PORT_BANK2)          ; the text: blanks (character 160) with colour 0, through the overlay window
        inc     a
        or      $40
        out     (VID_PORT),a
        ld      hl,$F000
        ld      de,$F001
        ld      (hl),160
        ld      bc,40 * 25 - 1
        ldir
        ld      hl,$F400
        ld      de,$F401
        ld      (hl),0
        ld      bc,40 * 25 - 1
        ldir
        VID_PAGE_OUT
        ld      a,VCTRL_MM4
        out     (PORT_VCTRL),a
        ret

; void aq_mm_leave(void): back to the 1bpp screen, cleared; the character RAM as it was
_aq_mm_leave:
        xor     a
        ld      (_aq_mm4),a
        ld      a,VCTRL_1BPP
        out     (PORT_VCTRL),a
        ld      a,21
        out     (VID_PORT),a
        ld      hl,aq_chr_save
        ld      de,VID_BASE * 256 + CHR_SAVED * 8
        ld      bc,1024
        ldir
        VID_PAGE_OUT
        jp      aq_clear_1bpp

aq_cell_leave:                          ; (in aq_cell: h = the row, b, c and de are the cell's)
        push    hl
        push    bc
        push    de
        call    _aq_mm_leave
        pop     de
        pop     bc
        pop     hl
        jp      aq_cell_go

; void aq_tcell(uint8_t col, uint8_t row, uint8_t ch, uint8_t colour) __smallc: a cell of the text layer
_aq_tcell:
        ld      hl,2
        add     hl,sp
        ld      c,(hl)                  ; colour
        inc     hl
        inc     hl
        ld      b,(hl)                  ; ch
        inc     hl
        inc     hl
        ld      e,(hl)                  ; row
        inc     hl
        inc     hl
        ld      a,(hl)                  ; col
        ld      d,0
        ld      h,d
        ld      l,e
        add     hl,hl
        add     hl,hl
        add     hl,de                   ; row * 5
        add     hl,hl
        add     hl,hl
        add     hl,hl                   ; row * 40
        ld      e,a
        add     hl,de
        ld      de,$F000
        add     hl,de                   ; in the overlay window: the characters here, the colours $400 on
        in      a,(PORT_BANK2)
        inc     a
        or      $40
        out     (VID_PORT),a
        ld      (hl),b
        ld      de,$0400
        add     hl,de
        ld      (hl),c
        VID_PAGE_OUT
        ret

; void aq_defchar(uint8_t ch, const uint8_t *art) __smallc: character ch (128 to 255) of the character RAM from 8 bytes (below $C000)
_aq_defchar:
        ld      hl,2
        add     hl,sp
        ld      e,(hl)
        inc     hl
        ld      d,(hl)                  ; de = art
        inc     hl
        ld      l,(hl)                  ; ch
        ld      h,0
        add     hl,hl
        add     hl,hl
        add     hl,hl
        ld      bc,VID_BASE * 256
        add     hl,bc
        ex      de,hl                   ; de = where, hl = art
        ld      a,21
        out     (VID_PORT),a
        ld      bc,8
        ldir
        VID_PAGE_OUT
        ret

aq_chr_save:
        defs    1024                    ; (in the code section, not under the video window)

; The mini map's row buffers (the pixel lines of a row of tiles, 24 bytes each, then the 24 colour bytes of the cells), in the code section
; so that it is not under the video RAM.
_aq_mm_buf:
        defs    72

; void plat_exit(void): back to the text screen
        PUBLIC  _plat_exit
_plat_exit:
        ld      a,(_aq_mm4)
        or      a
        call    nz,_aq_mm_leave         ; (the character RAM as it was)
        ld      a,VCTRL_TEXT
        out     (PORT_VCTRL),a
        ret

; The inverted copy of a picture that aq_invert makes: in the code section, so that it is not under the video RAM.
; The line pieces of the boxes' frames, pipes two pixels thick with rounded corners: 1 top left, 2 top right, 3 bottom left, 4 bottom right,
; 5 across, 6 down (the codes of BOX_TOP, BOX_BOTTOM and BOX_SIDE in plat_config.h, below the space; in the code section like aq_scratch)
aq_box:
        defb    $00,$00,$00,$0F,$1F,$18,$18,$18
        defb    $00,$00,$00,$F0,$F8,$18,$18,$18
        defb    $18,$18,$18,$1F,$0F,$00,$00,$00
        defb    $18,$18,$18,$F8,$F0,$00,$00,$00
        defb    $00,$00,$00,$FF,$FF,$00,$00,$00
        defb    $18,$18,$18,$18,$18,$18,$18,$18
aq_scratch:
        defs    8


; uint8_t plat_pointer_keys(void): the keys that are down, for the pointer (target/common/pointer.c): bit 0 left (O), 1 right (P), 2 up (Q), 3 down (A),
; 4 fire (Space or Enter), 5 fast (Shift).  The keyboard matrix has a row to each port high byte, a key down reading 0.
        PUBLIC  _plat_pointer_keys
_plat_pointer_keys:
        ld      e,0
        ld      bc,$7FFF
        in      a,(c)                   ; Shift (bit 4) and Q (bit 3)
        bit     4,a
        jr      nz,pk_nshift
        set     5,e
pk_nshift:
        bit     3,a
        jr      nz,pk_nq
        set     2,e
pk_nq:  ld      b,$BF
        in      a,(c)                   ; A (bit 5) and Space (bit 4)
        bit     5,a
        jr      nz,pk_na
        set     3,e
pk_na:  bit     4,a
        jr      nz,pk_nspace
        set     4,e
pk_nspace:
        ld      b,$FB
        in      a,(c)                   ; O (bit 1)
        bit     1,a
        jr      nz,pk_no
        set     0,e
pk_no:  ld      b,$FD
        in      a,(c)                   ; P (bit 3)
        bit     3,a
        jr      nz,pk_np
        set     1,e
pk_np:  ld      b,$FE
        in      a,(c)                   ; Enter (bit 3)
        bit     3,a
        jr      nz,pk_nenter
        set     4,e
pk_nenter:
        ld      l,e
        ld      h,0
        ret
