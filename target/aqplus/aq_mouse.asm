; Aquarius+ pointer: the arrow is hardware sprites 0 and 1, an 8x16 arrow in two 8x8 halves (sprite 1 below sprite 0), so nothing is drawn under it or put back.
; Their patterns are in the video RAM above the bitmap and its colour RAM (patterns 288 and 289, $2400 on): the video RAM is paged over bank 3 ($C000), where the
; program's buffers are, so nothing in them can be touched until it is put back (as aq_blit8 does).  Palette 3 (the bitmap's is 1) has the arrow's pens: 1 black, 2 white.

        SECTION code_user
        PUBLIC  _aq_arrow_define
        PUBLIC  _aq_arrow_at
        defc    PORT_VCTRL = $E0
        defc    PORT_VSPRSEL = $E4
        defc    PORT_VSPRXL = $E5
        defc    PORT_VSPRXH = $E6
        defc    PORT_VSPRY = $E7
        defc    PORT_VSPRIDX = $E8
        defc    PORT_VSPRATTR = $E9
        defc    PORT_VPALSEL = $EA
        defc    PORT_VPALDATA = $EB
        defc    PORT_BANK2 = $F2
        defc    PORT_BANK3 = $F3
        defc    VCTRL_BITMAP_SPRITES = $0C      ; the bitmap, and the sprites on
        defc    ATTR_ARROW = $B1                ; enabled, palette 3, pattern 256 up (288 = 256 + $20)

; void aq_arrow_define(void): the pens, the patterns, and the sprites on (nothing shows until aq_arrow_at)
_aq_arrow_define:
        ld      hl,arrow_pens
        ld      b,4
pen:    ld      a,(hl)                  ; the palette select (palette 3, the entry, GB or R) and then the value
        inc     hl
        out     (PORT_VPALSEL),a
        ld      a,(hl)
        inc     hl
        out     (PORT_VPALDATA),a
        djnz    pen
        ld      a,20                    ; the video RAM
        out     (PORT_BANK3),a
        ld      hl,arrow_pattern
        ld      de,$E400
        ld      bc,64
        ldir
        in      a,(PORT_BANK2)
        inc     a
        out     (PORT_BANK3),a
        ld      a,VCTRL_BITMAP_SPRITES
        out     (PORT_VCTRL),a
        xor     a
        out     (PORT_VSPRSEL),a        ; both off to begin with
        out     (PORT_VSPRATTR),a
        inc     a
        out     (PORT_VSPRSEL),a
        xor     a
        out     (PORT_VSPRATTR),a
        ret

; void aq_arrow_at(int16_t x, int16_t y) __smallc: the arrow's tip at screen pixel (x,y), or the arrow off with x < 0
_aq_arrow_at:
        ld      hl,2
        add     hl,sp
        ld      c,(hl)                  ; y
        inc     hl
        inc     hl
        ld      e,(hl)
        inc     hl
        ld      d,(hl)                  ; x
        xor     a
        out     (PORT_VSPRSEL),a
        bit     7,d
        jr      nz,arrow_off
        ld      b,$20
        call    arrow_half
        ld      a,c
        add     a,8
        ld      c,a
        ld      a,1
        out     (PORT_VSPRSEL),a
        ld      b,$21
arrow_half:                             ; the selected sprite: x in de, y in c, the pattern's low byte in b
        ld      a,e
        out     (PORT_VSPRXL),a
        ld      a,d
        out     (PORT_VSPRXH),a
        ld      a,c
        out     (PORT_VSPRY),a
        ld      a,b
        out     (PORT_VSPRIDX),a
        ld      a,ATTR_ARROW
        out     (PORT_VSPRATTR),a
        ret
arrow_off:
        out     (PORT_VSPRATTR),a       ; (a = 0)
        inc     a
        out     (PORT_VSPRSEL),a
        xor     a
        out     (PORT_VSPRATTR),a
        ret

        SECTION rodata_user
arrow_pens:
        defb    $60+2,$00,$60+3,$00     ; entry 1 black: GB, R
        defb    $60+4,$FF,$60+5,$0F     ; entry 2 white
arrow_pattern:                          ; 16 rows of 4 bytes (two pixels each, the left one the high nibble); 1 is the outline, 2 the fill
        defb    $10,$00,$00,$00
        defb    $11,$00,$00,$00
        defb    $12,$10,$00,$00
        defb    $12,$21,$00,$00
        defb    $12,$22,$10,$00
        defb    $12,$22,$21,$00
        defb    $12,$22,$22,$10
        defb    $12,$22,$22,$21
        defb    $12,$22,$11,$11
        defb    $12,$12,$10,$00
        defb    $11,$01,$21,$00
        defb    $10,$01,$21,$00
        defb    $00,$00,$11,$00
        defb    $00,$00,$00,$00
        defb    $00,$00,$00,$00
        defb    $00,$00,$00,$00
