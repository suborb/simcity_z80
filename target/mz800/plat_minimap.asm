; MZ-800 mini map: a row of tiles (2x2 pixels each) into the planes ($CC selects the plane).
; void plat_put_minirow(uint8_t ty, const uint8_t *colours, const uint8_t *base, uint8_t view) __smallc
; Tile row ty (0..95) from 96 colours (0..7, from ui/minimap.c): pixel lines 2 ty and 2 ty + 1, 24 bytes of each plane.  With four pens a colour is a pair of pens drawn as a
; checker, from tables: one for the city, power and transport views, one for the density ramps (pens 0 green, 1 yellow, 2 blue, 3 red).
; A density view has base, the city's colours of the row: where the density is 0 and the city has something, the ninth entry (a green/blue speck) lets the city show through.
; (plat_minimap.c has the same pairs for the key.)
        SECTION code_driver
        PUBLIC  _plat_put_minirow
        defc    P_G = 0
        defc    P_Y = 1
        defc    P_B = 2
        defc    P_R = 3
        MACRO   TILE pa, pb
        defb    (((pa & 1) | ((pb & 1) << 1)) << 6), (((pb & 1) | ((pa & 1) << 1)) << 6), ((((pa >> 1) & 1) | (((pb >> 1) & 1) << 1)) << 6), ((((pb >> 1) & 1) | (((pa >> 1) & 1) << 1)) << 6)
        ENDM

; per colour: plane 0 of the even line, of the odd line, plane 1 of the even, of the odd (a pair of pixels each at the high end, the left one the lower bit: the leftmost pixel of a byte is its bit 0)
mm_tab_a:                               ; land green, water blue, civic red, industry yellow, trees green/blue, houses green/yellow, shops blue/yellow, road yellow/red
        TILE    P_G, P_G
        TILE    P_B, P_B
        TILE    P_R, P_R
        TILE    P_Y, P_Y
        TILE    P_G, P_B
        TILE    P_G, P_Y
        TILE    P_B, P_Y
        TILE    P_Y, P_R
mm_tab_b:                               ; the levels of a density, low to high (blue, green/yellow, blue/yellow, yellow, yellow/red, red/blue, red), and the speck of the city showing through
        TILE    P_G, P_G
        TILE    P_B, P_B
        TILE    P_G, P_Y
        TILE    P_B, P_Y
        TILE    P_Y, P_Y
        TILE    P_Y, P_R
        TILE    P_R, P_B
        TILE    P_R, P_R
        TILE    P_G, P_B

_plat_put_minirow:
        ld      hl,2
        add     hl,sp
        ld      a,(hl)                  ; the view
        ld      de,mm_tab_a
        cp      1
        jr      z,mm_sel
        cp      6
        jr      z,mm_sel
        cp      7
        jr      z,mm_sel
        ld      de,mm_tab_b
mm_sel: ld      (mm_tabp),de
        ld      hl,4
        add     hl,sp
        ld      c,(hl)
        inc     hl
        ld      b,(hl)                  ; base
        inc     hl
        ld      e,(hl)
        inc     hl
        ld      d,(hl)                  ; the colours
        inc     hl
        ld      l,(hl)                  ; ty
        ld      h,0
        push    bc
        push    de
        ld      d,h
        ld      e,l
        add     hl,hl
        add     hl,hl
        add     hl,de                   ; ty * 5
        add     hl,hl
        add     hl,hl
        add     hl,hl
        add     hl,hl                   ; * 16: ty * 80, two lines of 40 bytes
        ld      de,$8000
        add     hl,de
        ld      (mm_dst),hl
        pop     de
        pop     bc
        ld      a,b
        or      c
        jr      nz,mm_hb
        ld      b,d                     ; no base: the colours stand for it (the speck is only where they are 0 and the base is not)
        ld      c,e
mm_hb:  push    ix
        push    iy
        push    de
        pop     ix                      ; ix = the colours
        push    bc
        pop     iy                      ; iy = base
        ld      a,24
        ld      (mm_cnt),a
mm_g:   ld      a,4                     ; four tiles a group: a byte of each of the four (plane, line) pairs, in b c d e
        ld      (mm_tc),a
mm_t:   ld      a,(ix+0)
        and     7
        jr      nz,mm_c
        ld      a,(iy+0)                ; (the density is 0: the city shows through if there is something there)
        and     7
        jr      z,mm_c
        ld      a,8
mm_c:   inc     ix
        inc     iy
        add     a,a
        add     a,a
        ld      hl,(mm_tabp)
        add     a,l
        ld      l,a
        jr      nc,mm_n
        inc     h
mm_n:   ld      a,b                     ; each byte takes a pair of pixels at its high end, the others moving down
        srl     a
        srl     a
        or      (hl)
        ld      b,a
        inc     hl
        ld      a,c
        srl     a
        srl     a
        or      (hl)
        ld      c,a
        inc     hl
        ld      a,d
        srl     a
        srl     a
        or      (hl)
        ld      d,a
        inc     hl
        ld      a,e
        srl     a
        srl     a
        or      (hl)
        ld      e,a
        ld      hl,mm_tc
        dec     (hl)
        jr      nz,mm_t
        in      a,($e0)                 ; the video RAM in for the four writes
        ld      a,1
        out     ($cc),a                 ; plane I: line 0 (b), line 1 (c) 40 on
        ld      hl,(mm_dst)
        ld      (hl),b
        ld      a,l
        add     a,40
        ld      l,a
        jr      nc,mm_w1
        inc     h
mm_w1:  ld      (hl),c
        ld      a,2
        out     ($cc),a                 ; plane II: line 1 (e), line 0 (d)
        ld      (hl),e
        ld      a,l
        sub     40
        ld      l,a
        jr      nc,mm_w2
        dec     h
mm_w2:  ld      (hl),d
        in      a,($e1)
        ld      hl,(mm_dst)
        inc     hl
        ld      (mm_dst),hl
        ld      hl,mm_cnt
        dec     (hl)
        jr      nz,mm_g
        pop     iy
        pop     ix
        ret

        SECTION bss_user
mm_tabp: defw   0
mm_dst: defw    0
mm_cnt: defb    0
mm_tc:  defb    0
