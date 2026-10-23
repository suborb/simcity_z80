; NEC PC-8801 platform (all-RAM mode, +pc88 -subtype=disk): the game draws pictures and text itself.
;
; The screen is three planes (blue, red, green: a Spectrum attribute's bit order) of 80 bytes a pixel row, 200 rows, with
; pixels twice as tall as wide.  A game cell is 8x8 with every pixel doubled across: two bytes by eight rows, 40 columns.
; A cell's first byte is $C000 + row * 640 + col * 2, and its rows are 80 bytes apart.  The planes are paged in over
; $C000-$FFFF, so nothing there can be used while one is: the placer's variables are in the low RAM (end of this file).
; Interrupts are off.
;
; Every PC-8801 pages the planes in one at a time (ports $5C-$5E, $5F for the RAM).  The V2 machines also have an ALU:
; with port $32 bit 6 and port $35 bit 7 one store reaches all three planes, and port $34 says what it does to each (set the
; stored byte's pixels, clear them, or nothing).  Text, solid cells, sprites and clearing use it; the map's pictures, which
; have a colour a pixel, are written a plane at a time on both.  __CLIB_PC8800_V2_ENABLED chooses (-clib=v1: no ALU).
;
; Each drawing routine looks at the keyboard now and then (mp_poll).  Arguments are the game's C calling convention (smallc).
; A cell's attribute is the Spectrum's: ink in bits 0-2, paper in 3-5.  A plane's byte for a pixel row:
;     ink  paper     byte
;      1     0       the picture
;      0     1       its inverse
;      1     1       $FF
;      0     0       0
; The picture is doubled across with a table (mp_dbl_init) first.

        SECTION code_user
        EXTERN  _font_8x8_bbc_system
        EXTERN  _view_tile_art          ; picture n is at 8 * n from it
        EXTERN  __CLIB_PC8800_V2_ENABLED

        defc    PLANE0 = $5C            ; blue; red is $5D and green $5E
        defc    PLANE_OFF = $5F         ; the RAM again
        defc    PORT_MODE = $32         ; bit 6: the ALU
        defc    PORT_ALU = $34          ; what a store does to each plane
        defc    PORT_GAM = $35          ; bit 7: the screen is paged in
        defc    SCREEN = $C000
        IFDEF   DBL_AT                  ; (the test has the screen in flat memory)
        defc    DBL = DBL_AT
        ELSE
        defc    DBL = $A600             ; 512 bytes, low RAM: pictures are drawn with a plane paged in
        ENDIF
        defc    DBL_HI = DBL / 256
        defc    TEXT_ATTR = 7           ; white on black

; The baked map pictures
        SECTION data_fcntl
mp_tiles:
        BINARY  "build/common/tiles_640x200_3bpp.bin"

; The 14 tool icons: four cells each, then their attributes
        SECTION rodata_user
        PUBLIC  _mp_icons
_mp_icons:
        BINARY  "assets/icons_spec.bin"

        SECTION code_user

; ALU and screen on and off (mp_mode is port $32 with the ALU off).  Uses a.
mp_alu_on:
        ld      a,(mp_mode)
        or      $40
        out     (PORT_MODE),a
        ld      a,$80
        out     (PORT_GAM),a
        ret
mp_alu_off:
        xor     a
        out     (PORT_GAM),a
        ld      a,(mp_mode)
        out     (PORT_MODE),a
        ret

; void plat_put_tile(uint8_t col, uint8_t row, const uint8_t *art, uint8_t attr, uint8_t inverse) __smallc
; A map picture: art is _view_tile_art + 8 * n, drawn from mp_tiles (24 bytes: a plane of eight rows after another).  The
; attribute is not used; `inverse` draws the complement (the cursor).
        PUBLIC  _plat_put_tile
_plat_put_tile:
        ld      hl,2
        add     hl,sp
        ld      a,(hl)
        ld      c,$80                   ; the cache key: $80, or $81 inverted
        or      a
        jr      z,mp_t_plain
        inc     c
mp_t_plain:
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
        ; a = row, b = col, c = key, de = art: the picture's three planes
        push    af
        push    bc
        ex      de,hl
        ld      de,_view_tile_art
        or      a
        sbc     hl,de                   ; 8 * n
        ld      d,h
        ld      e,l
        add     hl,hl
        add     hl,de                   ; 24 * n
        ld      de,mp_tiles
        add     hl,de
        ex      de,hl                   ; de = its planes
        pop     bc
        bit     0,c
        jr      nz,mp_bake_inv
        pop     af
        call    mp_scraddr
        jp      mp_tile_fast
        ; the cursor, the complement: doubled across into mp_pix3 first
mp_bake_inv:
        push    bc                      ; (the column)
        push    ix                      ; (the C code's frame pointer: kept)
        ld      ix,mp_pix3
        ld      b,24
mp_bake_lp:
        ld      a,(de)
        inc     de
        ld      l,a
        ld      h,DBL_HI
        ld      a,(hl)                  ; the high nibble doubled: the left byte
        ld      (ix+0),a
        inc     ix
        inc     h
        ld      a,(hl)                  ; the low nibble: the right byte
        ld      (ix+0),a
        inc     ix
        djnz    mp_bake_lp
        pop     ix
        pop     bc
        ld      hl,mp_pix3              ; the complement (the row, which a is for, is still on the stack)
        ld      d,48
mp_bake_cpl:
        ld      a,(hl)
        cpl
        ld      (hl),a
        inc     hl
        dec     d
        jr      nz,mp_bake_cpl
mp_bake_draw:
        pop     af
        call    mp_scraddr
        ld      de,mp_pix3
        xor     a                       ; blue, red, green: each in turn, from the next 16 bytes
        call    mp_one
        ld      a,1
        call    mp_one
        ld      a,2
        call    mp_one
        xor     a
        out     (PLANE_OFF),a
        jp      mp_poll

; A picture straight to the planes: de = its 24 bytes, mp_scr = the cell.  Each byte is doubled by the table (bc = DBL + byte;
; +256 for the low nibble) and stored; hl' is the screen and de' the step to the next row.  Keeps the other register set.
mp_tile_fast:
        exx
        push    hl
        push    de
        ld      de,79                   ; a row less the byte stepped over
        exx
        ld      b,DBL_HI
        xor     a
mp_tf_pl:
        push    af
        call    mp_plane                ; (this plane in; keeps b and de)
        exx
        ld      hl,(mp_scr)
        exx
        REPT    8
        ld      a,(de)
        inc     de
        ld      c,a
        ld      a,(bc)                  ; the left byte
        exx
        ld      (hl),a
        inc     hl
        exx
        inc     b
        ld      a,(bc)                  ; the right byte
        exx
        ld      (hl),a
        add     hl,de
        exx
        dec     b
        ENDR
        pop     af
        inc     a
        cp      3
        jp      nz,mp_tf_pl
        xor     a
        out     (PLANE_OFF),a
        exx
        pop     de
        pop     hl
        exx
        jp      mp_poll

; The cell's 16 bytes from de into plane a (0 blue, 1 red, 2 green)
mp_one:
        call    mp_plane
        ld      hl,(mp_scr)
        ld      bc,79
        jp      mp_copy

; Page in plane a.  Uses a, c.
mp_plane:
        add     a,PLANE0
        ld      c,a
        out     (c),a
        ret

; void mp_tile1(uint8_t col, uint8_t row, const uint8_t *art, uint8_t attr, uint8_t inverse) __smallc
; 8 bytes of art in the colours of attr (swapped if `inverse`): the icons.
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
        and     $3F                     ; the colours: the cache's key
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
        call    mp_cached
        ret     c
        jr      mp_cell_nc

; A cell that already shows this picture is left alone: mp_cache has each cell's art address and key (colours, or $80/$81 for
; map pictures), $40 if drawn some other way.  a = row, b = col, c = key, de = art.  Carry if it is as wanted; else the
; entry is updated.  Keeps a, b, c, de.
mp_cached:
        push    af
        push    de
        call    mp_entry
        pop     de
        ld      a,(hl)
        cp      e
        jr      nz,mp_miss
        inc     hl
        ld      a,(hl)
        cp      d
        jr      nz,mp_miss1
        inc     hl
        ld      a,(hl)
        cp      c
        jr      nz,mp_miss2
        pop     af
        scf
        ret
mp_miss:
        ld      (hl),e
        inc     hl
mp_miss1:
        ld      (hl),d
        inc     hl
mp_miss2:
        ld      (hl),c
        pop     af
        or      a
        ret

; hl = the cache entry of cell a = row, b = column.  Keeps a, b, c.
mp_entry:
        push    af
        push    de
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
        ld      d,h
        ld      e,l
        add     hl,hl
        add     hl,de                   ; * 3
        ld      de,mp_cache
        add     hl,de
        pop     de
        pop     af
        ret

; Other drawing in a cell: the cache no longer applies
mp_cell:
        push    de
        call    mp_entry
        inc     hl
        inc     hl
        ld      (hl),$40
        pop     de
mp_cell_nc:
        call    mp_scraddr
        ld      a,c
        ld      (mp_attr),a
        rrca                            ; ink == paper: a plain fill, with no picture to draw
        rrca
        rrca
        xor     c
        and     7
        jr      z,mp_solid
        call    mp_double               ; the picture doubled across, into mp_pix
        ld      a,__CLIB_PC8800_V2_ENABLED
        or      a
        jr      z,mp_planes
        ; with the ALU: the picture's pixels set to the ink, then the others cleared to the paper
        call    mp_alu_on
        ld      a,(mp_attr)
        and     7
        out     (PORT_ALU),a
        ld      hl,(mp_scr)
        ld      de,mp_pix
        ld      bc,79
        call    mp_copy
        ld      a,(mp_attr)
        rrca
        rrca
        rrca
        and     7
        out     (PORT_ALU),a
        ld      hl,(mp_scr)
        ld      de,mp_pix
        ld      bc,79
        call    mp_cpl
mp_alu_end:
        call    mp_alu_off
        jp      mp_poll

; A cell of one colour: one ALU store; without it mp_planes (each plane is all ones or zeros)
mp_solid:
        ld      a,__CLIB_PC8800_V2_ENABLED
        or      a
        jr      z,mp_planes
        call    mp_alu_on
        ld      a,(mp_attr)
        and     7
        out     (PORT_ALU),a
        ld      hl,(mp_scr)
        ld      bc,79
        call    mp_ones
        jr      mp_alu_end

; Each plane is drawn one of four ways by its ink and paper bits: mp_k[plane] = ink | paper << 1
mp_planes:
        ld      hl,mp_k
        ld      a,(mp_attr)
        ld      c,a
        ld      b,3
mp_pl_k:
        ld      a,c
        and     1
        ld      d,a                     ; the ink bit
        ld      a,c
        rrca
        rrca
        and     2                       ; the paper bit (bit 3 of the attribute)
        or      d
        ld      (hl),a
        inc     hl
        srl     c                       ; the next plane's bits
        djnz    mp_pl_k
        xor     a
mp_pl_d:
        ld      (mp_pn),a
        ld      e,a
        ld      d,0
        ld      hl,mp_k
        add     hl,de
        ld      a,(hl)                  ; how this plane is drawn
        add     a,a
        ld      e,a
        ld      hl,mp_ways
        add     hl,de
        ld      e,(hl)
        inc     hl
        ld      d,(hl)                  ; de = the routine
        ld      hl,mp_pl_next
        push    hl                      ; where it returns to
        push    de
        ld      a,(mp_pn)
        call    mp_plane
        ld      hl,(mp_scr)
        ld      de,mp_pix
        ld      bc,79
        ret                             ; into the routine
mp_pl_next:
        ld      a,(mp_pn)
        inc     a
        cp      3
        jr      nz,mp_pl_d
        xor     a
        out     (PLANE_OFF),a
        ; fall into mp_poll

; Every 16th call scans the keyboard (a scan costs 11 port reads).  Uses a, and bc, de, hl when it scans.
mp_poll:
        ld      a,(mp_tick)
        inc     a
        ld      (mp_tick),a
        and     15
        ret     nz

; Scan the keyboard matrix (ports 1-10, a bit a key, 0 = down; only the keys in mp_kmask): the lowest key of the first row
; with one down.  A key coming down is kept as the event for plat_key.  Uses a, bc, de, hl.
mp_keyscan:
        ld      hl,mp_kmask
        ld      c,1
mp_ks_row:
        in      a,(c)
        cpl
        and     (hl)
        jr      nz,mp_ks_down
        inc     hl
        inc     c
        ld      a,c
        cp      11
        jr      c,mp_ks_row
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
        ld      a,c
        add     a,a
        add     a,a
        add     a,a
        add     a,b                     ; row * 8 + bit
        ld      e,a
        ld      d,0
        ld      hl,mp_ktab
        add     hl,de
        ld      a,(hl)
        ld      hl,mp_held
        cp      (hl)
        ret     z                       ; the same key, still down
        ld      (hl),a
        ld      b,a
        in      a,(8)                   ; row 8, bit 6: shift
        and     $40
        jr      nz,mp_ks_ev
        ld      a,b                     ; shift: cursor keys go eight cells (28-31), ; is +
        cp      ';'
        jr      nz,mp_ks_cur
        ld      b,'+'
        jr      mp_ks_ev
mp_ks_cur:
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

; uint8_t plat_key(void): the key pressed since the last call, or 0, in the game's codes (letters lower case).
        PUBLIC  _plat_key
_plat_key:
        call    mp_keyscan
        ld      a,(mp_event)
        ld      l,a
        ld      h,0
        xor     a
        ld      (mp_event),a
        ret

; The keys looked at, rows 1 to 10
mp_kmask:
        defb    $88                     ; row 1: keypad + and RETURN
        defb    $FF,$FF,$FF,$FF,$FF,$FF ; rows 2 to 7: @ A-Z [ \ ] ^ - 0-9 : ; , . / _
        defb    $06                     ; row 8: cursor up and right
        defb    $C0                     ; row 9: space and escape
        defb    $26                     ; row 10: cursor down and left, keypad -
; and what they are (row * 8 + bit)
mp_ktab:
        defs    8
        defb    0,0,0,'+',0,0,0,13
        defb    '@','a','b','c','d','e','f','g'
        defb    'h','i','j','k','l','m','n','o'
        defb    'p','q','r','s','t','u','v','w'
        defb    'x','y','z','[',92,']','^','-'
        defb    '0','1','2','3','4','5','6','7'
        defb    '8','9',':',';',',','.','/','_'
        defb    0,11,9,0,0,0,0,0
        defb    0,0,0,0,0,0,' ',27
        defb    0,10,8,0,0,'-',0,0

; Draw the cell one way: hl = the cell, de = mp_pix, bc = 79 (80 less the byte stepped over)
mp_zero:
        REPT    8
        ld      (hl),0
        inc     hl
        ld      (hl),0
        add     hl,bc
        ENDR
        ret
mp_ones:
        REPT    8
        ld      (hl),$FF
        inc     hl
        ld      (hl),$FF
        add     hl,bc
        ENDR
        ret
mp_copy:
        REPT    8
        ld      a,(de)
        ld      (hl),a
        inc     de
        inc     hl
        ld      a,(de)
        ld      (hl),a
        inc     de
        add     hl,bc
        ENDR
        ret
mp_cpl:
        REPT    8
        ld      a,(de)
        cpl
        ld      (hl),a
        inc     de
        inc     hl
        ld      a,(de)
        cpl
        ld      (hl),a
        inc     de
        add     hl,bc
        ENDR
        ret
mp_ways:
        defw    mp_zero, mp_copy, mp_cpl, mp_ones

; mp_scr = the address of cell a = row, b = column: row * 640 is (row * 5) << 7.  Uses a, hl.
mp_scraddr:
        ld      h,a
        add     a,a
        add     a,a
        add     a,h                     ; row * 5
        rrca                            ; bit 7 = its low bit
        ld      l,a
        and     $7F
        or      SCREEN / 256            ; (the rest is below $40)
        ld      h,a
        ld      a,l
        and     $80
        ld      l,a
        ld      a,b
        add     a,a                     ; col * 2, below $80
        or      l
        ld      l,a
        ld      (mp_scr),hl
        ret

; The 8 bytes at de doubled across into mp_pix.  Uses a, bc, de, hl.
mp_double:
        ld      hl,mp_pix
        REPT    8
        ld      a,(de)
        inc     de
        ld      c,a
        ld      b,DBL_HI
        ld      a,(bc)                  ; the high nibble, doubled: the left byte
        ld      (hl),a
        inc     hl
        inc     b
        ld      a,(bc)                  ; the low nibble: the right byte
        ld      (hl),a
        inc     hl
        ENDR
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
        push    af
        push    bc
        call    mp_double
        pop     bc
        pop     af
        push    af
        push    bc
        call    mp_entry                ; the cell no longer shows what the cache says
        inc     hl
        inc     hl
        ld      (hl),$40
        pop     bc
        pop     af
        call    mp_scraddr
        ld      a,__CLIB_PC8800_V2_ENABLED
        or      a
        jr      z,mp_ov_planes
        call    mp_alu_on               ; white: set the pixels in every plane with one store
        ld      a,7
        out     (PORT_ALU),a
        ld      hl,(mp_scr)
        ld      de,mp_pix
        ld      bc,79
        call    mp_copy
        jp      mp_alu_end
mp_ov_planes:
        xor     a                       ; the pixels into each plane in turn: or them in
        call    mp_or
        ld      a,1
        call    mp_or
        ld      a,2
        call    mp_or
        xor     a
        out     (PLANE_OFF),a
        jp      mp_poll

; mp_pix ORed into plane a
mp_or:
        call    mp_plane
        ld      hl,(mp_scr)
        ld      de,mp_pix
        ld      bc,79
        REPT    8
        ld      a,(de)
        or      (hl)
        ld      (hl),a
        inc     hl
        inc     de
        ld      a,(de)
        or      (hl)
        ld      (hl),a
        inc     de
        add     hl,bc
        ENDR
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
        cp      40
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

; DBL[x] is the high nibble of x with every bit doubled (the left byte), DBL[256 + x] the low nibble
mp_dbl_init:
        ld      hl,DBL
        ld      de,mp_nibbles
        ld      b,16
mp_dbl_hi:
        ld      a,(de)
        inc     de
        ld      c,16
mp_dbl_fill:
        ld      (hl),a
        inc     hl
        dec     c
        jr      nz,mp_dbl_fill
        djnz    mp_dbl_hi
        ld      de,DBL + 256
        ld      b,16
mp_dbl_lo:
        push    bc
        ld      hl,mp_nibbles
        ld      bc,16
        ldir
        pop     bc
        djnz    mp_dbl_lo
        ret

; void plat_init(void)
;
; Port $32 bit 4 picks which of two 4 KB RAMs is at $F000-$FFFF, and the startup code cleared the uninitialised data (which
; reaches into it) in whichever was there: so the port is set first, and that 4 KB cleared, before anything is kept there.
; Once only: the game calls this again for a new city.
        PUBLIC  _plat_init
_plat_init:
        di
        ld      a,(mp_up)
        or      a
        jr      nz,mp_up_done
        inc     a
        ld      (mp_up),a
        ld      a,__CLIB_PC8800_V2_ENABLED
        or      a
        jr      z,mp_ram
        ld      a,$98                   ; the machine's start state: analog RGB, main RAM at $F000, digital palette
        ld      (mp_mode),a
        out     (PORT_MODE),a
mp_ram:
        ld      hl,$F000
        ld      de,$F001
        ld      bc,$0FFF
        ld      (hl),0
        ldir
mp_up_done:
        call    mp_dbl_init
        ld      a,$10                   ; port $40 bit 4: no waits on the screen RAM (the original PC-8801 has them)
        out     ($40),a
        ld      a,1                     ; text screen off
        out     ($53),a
        xor     a
        out     ($52),a                 ; a black background
mp_pal:
        xor     a                       ; palette entry n is colour n
        ld      c,$54
mp_pal_lp:
        out     (c),a
        inc     c
        inc     a
        cp      8
        jr      nz,mp_pal_lp

; void plat_clear(void): the three planes to 0
        PUBLIC  _plat_clear
        PUBLIC  _plat_text_clear
_plat_text_clear:
_plat_clear:
        ld      a,__CLIB_PC8800_V2_ENABLED
        or      a
        jr      z,mp_clear_planes
        call    mp_alu_on
        xor     a
        out     (PORT_ALU),a            ; clear the pixels a store has set, in every plane
        ld      hl,SCREEN
        ld      bc,80 * 200 / 16        ; (not an ldir: that reads through the ALU)
        ld      e,$FF
mp_clear_lp:
        REPT    16
        ld      (hl),e
        inc     hl
        ENDR
        dec     bc
        ld      a,b
        or      c
        jr      nz,mp_clear_lp
        call    mp_alu_off
        jr      mp_clear_cache
mp_clear_planes:
        xor     a
mp_clear_pl:
        push    af
        call    mp_plane
        ld      hl,SCREEN
        ld      de,SCREEN + 1
        ld      bc,80 * 200 - 1
        ld      (hl),0
        ldir
        pop     af
        inc     a
        cp      3
        jr      nz,mp_clear_pl
        xor     a
        out     (PLANE_OFF),a
mp_clear_cache:
        ld      hl,mp_cache             ; and no cell shows what the cache says
        ld      de,mp_cache + 1
        ld      bc,40 * 25 * 3 - 1
        ld      (hl),$40
        ldir
        ret

; void plat_put_minirow(uint8_t sy) __smallc
; Draws row sy (0..47) of the mini map from mm_row (minimap_640x200_3bpp.asm): each plane's three lines of 48 bytes go to lines
; MM_LINE0 + 3 sy to + 2.
        EXTERN  _mm_row
        defc    MM_LINE0 = 52           ; 144 lines, centred below the status panel
        defc    MM_BYTE = 16            ; (80 - 48) / 2: centred
        PUBLIC  _plat_put_minirow
_plat_put_minirow:
        ld      hl,2
        add     hl,sp
        ld      l,(hl)
        ld      h,0
        ld      d,h
        ld      e,l
        add     hl,hl
        add     hl,hl
        add     hl,hl
        add     hl,hl                   ; 16 sy
        or      a
        sbc     hl,de                   ; 15 sy
        add     hl,hl
        add     hl,hl
        add     hl,hl
        add     hl,hl                   ; 240 sy: three lines of 80 bytes
        ld      de,SCREEN + MM_LINE0 * 80 + MM_BYTE
        add     hl,de
        ld      (mm_dst),hl
        ld      hl,_mm_row
        ld      (mm_src),hl
        xor     a
mm_art_pl:
        ld      (mm_msk),a              ; the plane: 0 blue, 1 red, 2 green
        call    mp_plane
        ld      hl,(mm_src)
        ld      de,(mm_dst)
        ld      bc,48
        ldir
        ld      hl,(mm_dst)
        ld      de,80
        add     hl,de
        ex      de,hl
        ld      hl,(mm_src)
        ld      bc,48
        add     hl,bc
        ld      bc,48
        ldir
        ld      hl,(mm_dst)
        ld      de,160
        add     hl,de
        ex      de,hl
        ld      hl,(mm_src)
        ld      bc,96
        add     hl,bc
        ld      bc,48
        ldir
        xor     a
        out     (PLANE_OFF),a
        ld      hl,(mm_src)
        ld      de,144
        add     hl,de
        ld      (mm_src),hl
        ld      a,(mm_msk)
        inc     a
        cp      3
        jr      nz,mm_art_pl
        jp      mp_poll

; void plat_scroll(uint8_t row, uint8_t rows, int8_t dx, int8_t dy) __smallc
; The view's origin moved by (dx, dy) cells: cell (x, y) is now at (x - dx, y - dy).  The map is one linear block of pixels,
; so this is one block move; what wraps round lands in the exposed cells, which the game draws.  With the ALU the move is
; an ldir through its latches (port $35 bit 4), all three planes at once; else one ldir a plane.  The cache moves the same
; way and the exposed cells are marked.
        PUBLIC  _plat_scroll
_plat_scroll:
        ld      hl,2
        add     hl,sp
        ld      a,(hl)
        ld      (mp_sdy),a
        inc     hl
        inc     hl
        ld      a,(hl)
        ld      (mp_sdx),a
        inc     hl
        inc     hl
        ld      a,(hl)
        ld      (mp_srows),a
        inc     hl
        inc     hl
        ld      a,(hl)
        ld      (mp_srow),a
        ; the pixels: delta = dy * 640 + dx * 2 bytes
        ld      a,(mp_sdy)
        call    mp_sext                 ; hl = dy
        ld      d,h
        ld      e,l
        add     hl,hl
        add     hl,hl
        add     hl,de                   ; 5 dy
        REPT    7
        add     hl,hl
        ENDR                            ; * 128
        push    hl
        ld      a,(mp_sdx)
        call    mp_sext
        add     hl,hl
        pop     de
        add     hl,de
        ld      (mp_sdelta),hl
        ; the cache: delta = (dy * 40 + dx) * 3 bytes
        ld      a,(mp_sdy)
        call    mp_sext
        add     hl,hl
        add     hl,hl
        add     hl,hl                   ; 8 dy
        ld      d,h
        ld      e,l
        add     hl,hl
        add     hl,hl                   ; 32 dy
        add     hl,de                   ; 40 dy
        push    hl
        ld      a,(mp_sdx)
        call    mp_sext
        pop     de
        add     hl,de
        ld      d,h
        ld      e,l
        add     hl,hl
        add     hl,de                   ; * 3
        ld      (mp_sdelta_c),hl
        ; the screen block: SCREEN + row * 640, rows * 640 bytes
        ld      a,(mp_srow)
        ld      b,0
        call    mp_scraddr
        ld      (mp_sstart),hl
        ld      a,(mp_srows)
        ld      c,a
        add     a,a
        add     a,a
        add     a,c                     ; rows * 5 (below 128)
        ld      l,0
        srl     a
        ld      h,a
        jr      nc,mp_sc_len
        ld      l,$80
mp_sc_len:
        ld      (mp_slen),hl
        ld      a,__CLIB_PC8800_V2_ENABLED
        or      a
        jr      z,mp_sc_planes
        ld      a,(mp_mode)
        or      $40
        out     (PORT_MODE),a
        ld      a,$90                   ; screen in, stores write the latches
        out     (PORT_GAM),a
        call    mp_sc_block
        call    mp_alu_off
        jr      mp_sc_cache
mp_sc_planes:
        xor     a
mp_sc_pl:
        ld      (mp_pn),a
        call    mp_plane
        call    mp_sc_block
        ld      a,(mp_pn)
        inc     a
        cp      3
        jr      nz,mp_sc_pl
        xor     a
        out     (PLANE_OFF),a
mp_sc_cache:
        ; the cache: rows * 120 bytes from mp_cache + row * 120
        ld      a,(mp_srow)
        call    mp_x120
        ld      de,mp_cache
        add     hl,de
        ld      (mp_sstart),hl
        ld      a,(mp_srows)
        call    mp_x120
        ld      (mp_slen),hl
        ld      hl,(mp_sdelta_c)
        ld      (mp_sdelta),hl
        call    mp_sc_block
        ; the cells that are exposed: rows at the bottom (dy > 0) or the top, and columns at the right (dx > 0) or the left
        ld      a,(mp_sdy)
        or      a
        jr      z,mp_sc_cols
        ld      b,a
        jp      m,mp_sc_top
        ld      a,(mp_srows)            ; the bottom dy rows
        sub     b
        jr      mp_sc_rows
mp_sc_top:
        ld      a,b                     ; the top -dy rows
        neg
        ld      b,a
        xor     a
mp_sc_rows:
        ; a = the first row (of the map), b = how many
        ld      c,a
        ld      a,(mp_srow)
        add     a,c
        call    mp_x120                 ; (keeps b)
        ld      de,mp_cache
        add     hl,de
        push    hl
        ld      l,b
        ld      h,0
        add     hl,hl
        add     hl,hl
        add     hl,hl                   ; 8 n
        ld      d,h
        ld      e,l
        add     hl,hl
        add     hl,hl                   ; 32 n
        add     hl,de                   ; 40 n cells
        ld      b,h
        ld      c,l
        pop     hl
        call    mp_inv
mp_sc_cols:
        ld      a,(mp_sdx)
        or      a
        ret     z
        jp      m,mp_sc_left
        ld      c,a                     ; the last dx columns
        ld      a,40
        sub     c
        jr      mp_sc_col
mp_sc_left:
        neg
        ld      c,a
        xor     a
mp_sc_col:
        ; a = the first column, c = how many: in each row of the map
        ld      (mp_scol),a
        ld      a,c
        ld      (mp_scnt),a
        ld      a,(mp_srows)
        ld      b,a
        ld      a,(mp_srow)
        ld      (mp_sy),a
mp_sc_row:
        push    bc
        ld      a,(mp_sy)
        call    mp_x120
        ld      de,mp_cache
        add     hl,de
        ld      a,(mp_scol)
        ld      e,a
        ld      d,0
        ld      b,h
        ld      c,l
        ld      h,d
        ld      l,e
        add     hl,hl
        add     hl,de                   ; col * 3
        add     hl,bc
        ld      a,(mp_scnt)
        ld      c,a
        ld      b,0
        call    mp_inv
        ld      hl,mp_sy
        inc     (hl)
        pop     bc
        djnz    mp_sc_row
        ret

; Move the block (mp_sstart, mp_slen) by mp_sdelta: the byte at start + delta goes to start.  Uses everything.
mp_sc_block:
        ld      hl,(mp_sstart)
        ld      bc,(mp_slen)
        ld      de,(mp_sdelta)
        bit     7,d
        jr      nz,mp_mv_back
        push    hl                      ; the destination
        ld      a,c
        sub     e
        ld      c,a
        ld      a,b
        sbc     a,d
        ld      b,a                     ; the length less the delta
        add     hl,de                   ; the source
        pop     de
        ld      a,b
        or      c
        ret     z
        ldir
        ret
mp_mv_back:
        add     hl,bc
        dec     hl                      ; the last byte: the destination
        push    hl
        add     hl,de                   ; the source, the delta below it
        ld      a,c
        add     a,e
        ld      c,a
        ld      a,b
        adc     a,d
        ld      b,a                     ; the length less the delta's size
        pop     de
        ld      a,b
        or      c
        ret     z
        lddr
        ret

; hl = the signed byte in a
mp_sext:
        ld      l,a
        add     a,a
        sbc     a,a
        ld      h,a
        ret

; hl = a * 120 (a below 25)
mp_x120:
        ld      l,a
        ld      h,0
        add     hl,hl
        add     hl,hl
        add     hl,hl                   ; 8 a
        ld      d,h
        ld      e,l
        add     hl,hl
        add     hl,hl
        add     hl,hl
        add     hl,hl                   ; 128 a
        or      a
        sbc     hl,de                   ; 120 a
        ret

; Mark bc cache entries from hl (key $40)
mp_inv:
        inc     hl
        inc     hl
        ld      (hl),$40
        inc     hl
        dec     bc
        ld      a,b
        or      c
        jr      nz,mp_inv
        ret

; void plat_exit(void)
        PUBLIC  _plat_exit
_plat_exit:
        ret

; The doubled four pixels of each nibble
        SECTION rodata_user
mp_nibbles:
        defb    $00,$03,$0C,$0F,$30,$33,$3C,$3F,$C0,$C3,$CC,$CF,$F0,$F3,$FC,$FF

; What each cell shows (40 x 25 of three bytes); under the screen, so used only with the RAM paged in
        SECTION bss_user
mp_cache: defs  40 * 25 * 3

; The placer's variables: in the code section so that they stay in the low RAM
        SECTION code_user
mp_srow: defb   0                       ; plat_scroll's arguments and work
mp_srows: defb  0
mp_sdx:  defb   0
mp_sdy:  defb   0
mp_sdelta: defw 0
mp_sdelta_c: defw 0
mp_sstart: defw 0
mp_slen: defw   0
mp_scol: defb   0
mp_scnt: defb   0
mp_sy:   defb   0
mp_up:   defb   0                       ; plat_init has been called
mp_mode: defb   $98                     ; port $32 with the ALU off (the V2 machines)
mp_attr: defb   0                       ; the cell's attribute
mp_k:    defs   4                       ; how each plane is drawn
mp_pn:   defb   0                       ; the plane being drawn
mp_pix:  defs   16                      ; the picture doubled across: two bytes a row
mp_pix3: defs   48                      ; a baked picture doubled across: the three planes, sixteen bytes each
mp_scr:  defw   0
mp_tick: defb   0                       ; draws since the keyboard was looked at
mp_held: defb   0                       ; the code of the key that is down, or 0
mp_event: defb  0                       ; the key pressed since plat_key last looked, or 0
mm_dst:  defw   0                       ; where the row's first line starts in a plane
mm_msk:  defb   0                       ; the plane being written
mm_src:  defw   0                       ; its 48 bytes
