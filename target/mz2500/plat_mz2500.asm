; MZ-2500 platform, the video side: 320x200 in 16 colours, planar (four planes B, R, G, I of 8000 bytes: a line is 40 bytes, 8 pixels a byte, bit 0 the LEFTMOST pixel; the
; pixel's value is B | R << 1 | G << 2 | I << 3).  The game's 32 x 24 cells of 8x8 are at byte column 4 (XB0) of the 40, from line 0, so a cell is a byte wide and 8 lines high
; in each plane.  There is no room to keep the planes mapped: the Z80's windows 0-1 hold the resident program, 2-3 the UI or engine bank, 4-7 the data.  A routine here
; borrows window 3 ($6000-$7FFF) for one plane at a time (the picture atlas is borrowed into window 2, $4000, a tile at a time) and puts both windows back to the pages
; the bank switch last set (mz_w2, mz_w3).  Interrupts are off for the whole run, and the stack is in window 4: nothing here touches a window it does not put back.
; The routines take their arguments the way the game's C code passes them (smallc: first argument first, each a word, the caller cleans up).
;
;   RAM pages: $20, $22, $24, $26 = the B, R, G, I planes of screen A (see z88dk's mz2500.h); the atlas (tools/st_tiles_3bpp.py --mz2500) is pages 22 up, linked at $4000.

        MODULE  plat_mz2500
        SECTION code_user

        defc    XB0 = 4                 ; the byte column of the map's column 0
        defc    PAGE_ATLAS = 22
        defc    PAGE_PLANE0 = $20

        PUBLIC  mz_w2, mz_w3
        PUBLIC  _mz_pit_init, _mz_pit_read, _mz_arrow, _mz_clearb, _mz_mouse_init, _mz_sio_ready, _mz_sio_data, _mz_sio_trigger, _mz_pal4096, _mz_keyinit, _mz_keycol, _mz_cleartext, _mz_tile, _mz_glyph, _mz_glyphr, _mz_overlay, _mz_xorcell, _mz_fillb, _mz_maskb, _mz_recolour, _mz_wrline, _mz_shift, _mz_icon, _mz_setup, _mz_clear

; ---- helpers ------------------------------------------------------------------------------------------------------------------

; window 3 = the plane whose index is in a (0-3): uses a
plane_in:
        IFDEF   MZ_TEST                 ; (test/mz2500/prims.py: the harness swaps the window's 8 KB for the plane's)
        EXTERN  test_plane
        push    af
        call    test_plane
        pop     af
        ENDIF
        add     a,a
        add     a,PAGE_PLANE0
        push    af
        ld      a,3
        out     ($b4),a
        pop     af
        out     ($b5),a
        ret

; the same for screen B (the pointer's layer: pages $21, $23, $25, $27)
plane_in_b:
        IFDEF   MZ_TEST
        push    af
        call    test_plane
        pop     af
        ENDIF
        add     a,a
        add     a,PAGE_PLANE0 + 1
        push    af
        ld      a,3
        out     ($b4),a
        pop     af
        out     ($b5),a
        ret

; windows 2 and 3 back to the bank's pages
restore:
        ld      a,2
        out     ($b4),a
        ld      a,(mz_w2)
        out     ($b5),a
        ld      a,(mz_w3)
        out     ($b5),a
        ret

; hl = $6000 + row * 320 + col + XB0 for the cell (d = col, e = row); uses a, b
cell_hl:
        ld      a,e
        add     a,a
        add     a,a
        add     a,e                     ; 5 * row (at most 115)
        ld      b,a
        and     3
        rrca
        rrca
        ld      l,a                     ; (5 * row & 3) << 6
        ld      a,b
        rrca
        rrca
        and     $3f
        add     a,$60
        ld      h,a
        ld      a,l
        add     a,d
        add     a,XB0                   ; (at most 192 + 31 + 4: no carry)
        ld      l,a
        ret

; hl = $6000 + y * 40 + xb for the line y (a) and byte column xb (e); uses bc, de
line_hl:
        ld      l,a
        ld      h,0
        add     hl,hl
        add     hl,hl
        add     hl,hl                   ; 8 y
        ld      b,h
        ld      c,l
        add     hl,hl
        add     hl,hl                   ; 32 y
        add     hl,bc                   ; 40 y
        ld      bc,$6000
        add     hl,bc
        ld      d,0
        add     hl,de
        ret

; a = the bits of a reversed (bit 0 of the 1 bit art's pixel row is the rightmost pixel, the planes' the leftmost); uses b, c.  Three delta swaps: the bits at distance d that
; the mask selects are exchanged by x ^= t | t << d with t = (x ^ x >> d) & mask (the rotates are safe: the mask keeps the wrapped bits out of t)
rev8:
        ld      b,a                     ; neighbours (mask $55)
        rrca
        xor     b
        and     $55
        ld      c,a
        add     a,a
        or      c
        xor     b
        ld      b,a                     ; pairs (mask $33)
        rrca
        rrca
        xor     b
        and     $33
        ld      c,a
        add     a,a
        add     a,a
        or      c
        xor     b
        ld      b,a                     ; nibbles (mask $0F)
        rrca
        rrca
        rrca
        rrca
        xor     b
        and     $0f
        ld      c,a
        add     a,a
        add     a,a
        add     a,a
        add     a,a
        or      c
        xor     b
        ret

; ---- void mz_setup(void): the borrowed windows' starting pages ----------------------------------------------------------------------
_mz_setup:
        ld      a,18
        ld      (mz_w2),a
        ld      a,19
        ld      (mz_w3),a
        ret

; ---- void mz_tile(uint8_t col, uint8_t row, uint16_t n): picture n of the atlas into the cell -----------------------------------------------
_mz_tile:
        ld      hl,2
        add     hl,sp
        ld      c,(hl)
        inc     hl
        ld      b,(hl)                  ; n
        inc     hl
        ld      e,(hl)                  ; row
        inc     hl
        inc     hl
        ld      d,(hl)                  ; col
        ; the atlas page in window 2
        ld      a,b
        add     a,PAGE_ATLAS
        ld      l,a
        ld      a,2
        out     ($b4),a
        ld      a,l
        out     ($b5),a
        ld      a,c                     ; src = $4000 + (n & 255) * 32
        rlca
        rlca
        rlca
        rlca
        rlca
        ld      l,a
        and     $1f
        add     a,$40
        ld      h,a
        ld      a,l
        and     $e0
        ld      l,a
        push    hl                      ; src
        call    cell_hl
        ex      de,hl                   ; de = dest
        pop     hl
        ld      bc,40
        xor     a
        ld      (t_a),a
tile_plane:
        ld      a,(t_a)
        push    bc
        call    plane_in                ; (the plane's page in window 3: keeps hl, de)
        pop     bc
        push    de
        REPT    8
        ld      a,(hl)
        ld      (de),a
        inc     hl
        ex      de,hl
        add     hl,bc
        ex      de,hl
        ENDR
        pop     de
        ld      a,(t_a)
        inc     a
        ld      (t_a),a
        cp      4
        jp      nz,tile_plane
        call    restore
        IFDEF   HAVE_SOUND
        EXTERN  ay_active, ay_poll
        ld      a,(ay_active)           ; (the sound's ticks go on while the screen is drawn)
        or      a
        ret     z
        jp      ay_poll
        ELSE
        ret
        ENDIF

; ---- void mz_glyph(uint8_t col, uint8_t row, const uint8_t *art, uint8_t ink, uint8_t paper): 8 bytes of 1 bit art (bit 7 on the left) -----------------------------------
_mz_glyphr:                             ; the art already has its bits reversed (bit 0 the leftmost): the font's
        pop     hl
        pop     de                      ; paper
        ld      a,e
        ld      (g_pap),a
        pop     de                      ; ink
        ld      a,e
        ld      (g_ink),a
        pop     bc                      ; art
        ld      (g_ptr),bc
        pop     de                      ; row
        ld      a,e
        ld      (t_row),a
        pop     de                      ; col
        ld      a,e
        ld      (t_col),a
        push    de
        push    de
        push    de
        push    de
        push    de
        push    hl
        jr      gl_common
_mz_glyph:
        pop     hl
        pop     de                      ; paper
        ld      a,e
        ld      (g_pap),a
        pop     de                      ; ink
        ld      a,e
        ld      (g_ink),a
        pop     bc                      ; art
        pop     de                      ; row
        ld      a,e
        ld      (t_row),a
        pop     de                      ; col
        ld      a,e
        ld      (t_col),a
        push    de
        push    de
        push    de
        push    de
        push    de
        push    hl
        ld      hl,g_buf
        ld      d,8
gl_rev:
        ld      a,(bc)
        inc     bc
        push    bc
        call    rev8
        pop     bc
        ld      (hl),a
        inc     hl
        dec     d
        jr      nz,gl_rev
        ld      hl,g_buf
        ld      (g_ptr),hl
gl_common:
        ld      a,(t_col)
        ld      d,a
        ld      a,(t_row)
        ld      e,a
        call    cell_hl
        ld      (t_dest),hl
        xor     a
        ld      (t_a),a                 ; the plane
gl_plane:
        ld      a,(t_a)
        ld      b,a
        inc     b
        ld      a,(g_ink)
gl_i:
        rrca
        djnz    gl_i
        sbc     a,a                     ; $FF if the ink has this plane's bit
        ld      d,a
        ld      a,(t_a)
        ld      b,a
        inc     b
        ld      a,(g_pap)
gl_p:
        rrca
        djnz    gl_p
        sbc     a,a
        ld      e,a                     ; e = the paper mask
        ld      a,d
        xor     e
        ld      d,a                     ; d = ink mask xor paper mask
        ld      a,(t_a)
        call    plane_in
        ld      hl,(t_dest)
        ld      bc,(g_ptr)
gl_line:
        REPT    8
        ld      a,(bc)
        and     d
        xor     e
        ld      (hl),a
        inc     bc
        ld      a,l
        add     a,40
        ld      l,a
        jr      nc,$+3
        inc     h
        ENDR
        ld      a,(t_a)
        inc     a
        ld      (t_a),a
        cp      4
        jp      nz,gl_plane
        jp      restore

; ---- void mz_overlay(uint8_t col, uint8_t row, const uint8_t *art): the set pixels of the 1 bit art in white (all four planes) over what is there ----------------------------------
_mz_overlay:
        pop     hl
        pop     bc                      ; art
        pop     de                      ; row
        ld      a,e
        ld      (t_row),a
        pop     de                      ; col
        ld      a,e
        ld      (t_col),a
        push    de
        push    de
        push    de
        push    hl
        ld      hl,g_buf
        ld      d,8
ov_rev:
        ld      a,(bc)
        inc     bc
        push    bc
        call    rev8
        pop     bc
        ld      (hl),a
        inc     hl
        dec     d
        jr      nz,ov_rev
        ld      a,(t_col)
        ld      d,a
        ld      a,(t_row)
        ld      e,a
        call    cell_hl
        ld      (t_dest),hl
        xor     a
        ld      (t_a),a
ov_plane:
        call    plane_in
        ld      hl,(t_dest)
        ld      de,g_buf
        ld      b,8
ov_line:
        ld      a,(de)
        or      (hl)
        ld      (hl),a
        inc     de
        ld      a,l
        add     a,40
        ld      l,a
        jr      nc,$+3
        inc     h
        djnz    ov_line
        ld      a,(t_a)
        inc     a
        ld      (t_a),a
        cp      4
        jr      nz,ov_plane
        jp      restore

; ---- void mz_xorcell(uint8_t col, uint8_t row): every pixel of the cell inverted (the cursor) ----------------------------------------------------------------
_mz_xorcell:
        pop     hl
        pop     de                      ; row
        ld      a,e
        ld      (t_row),a
        pop     de                      ; col
        ld      a,e
        ld      (t_col),a
        push    de
        push    de
        push    hl
        ld      a,(t_col)
        ld      d,a
        ld      a,(t_row)
        ld      e,a
        call    cell_hl
        ld      (t_dest),hl
        xor     a
        ld      (t_a),a
xc_plane:
        call    plane_in
        ld      hl,(t_dest)
        ld      b,8
xc_line:
        ld      a,(hl)
        cpl
        ld      (hl),a
        ld      a,l
        add     a,40
        ld      l,a
        jr      nc,$+3
        inc     h
        djnz    xc_line
        ld      a,(t_a)
        inc     a
        ld      (t_a),a
        cp      4
        jr      nz,xc_plane
        jp      restore

; ---- void mz_fillb(uint8_t y, uint8_t xb, uint8_t nb, uint8_t ny, uint8_t colour): whole bytes of one colour: nb bytes from byte column xb (of the 40), ny lines from line y -------------------
_mz_fillb:
        pop     hl
        pop     de
        ld      a,e
        ld      (f_col),a
        pop     de
        ld      a,e
        ld      (f_ny),a
        pop     de
        ld      a,e
        ld      (f_nb),a
        pop     de
        ld      a,e
        ld      (f_xb),a
        pop     de
        ld      a,e
        ld      (f_y),a
        push    de
        push    de
        push    de
        push    de
        push    de
        push    hl
        ld      a,(f_nb)
        or      a
        ret     z
        ld      a,(f_ny)
        or      a
        ret     z
        xor     a
        ld      (t_a),a
fb_plane:
        ld      a,(t_a)
        call    plane_in
        ld      a,(f_xb)
        ld      e,a
        ld      a,(f_y)
        call    line_hl
        ld      a,(f_col)
        ld      b,a
        ld      a,(t_a)
        inc     a
        ld      c,a
fb_c:
        ld      a,b
        rrca
        ld      b,a
        dec     c
        jr      nz,fb_c
        sbc     a,a                     ; $FF if the colour has this plane's bit
        ld      (t_m),a
        ld      a,(f_ny)
        ld      b,a
fb_line:
        push    hl
        ld      a,(f_nb)
        ld      c,a
        ld      a,(t_m)
fb_b:
        ld      (hl),a
        inc     hl
        dec     c
        jr      nz,fb_b
        pop     hl
        ld      de,40
        add     hl,de
        djnz    fb_line
        ld      a,(t_a)
        inc     a
        ld      (t_a),a
        cp      4
        jr      nz,fb_plane
        jp      restore

; ---- void mz_maskb(uint8_t y, uint8_t xb, uint8_t ny, uint8_t mask, uint8_t colour): the pixels in mask (bit 0 the leftmost) of one byte column, ny lines, to the colour -----------------------
_mz_maskb:
        pop     hl
        pop     de
        ld      a,e
        ld      (f_col),a
        pop     de
        ld      a,e
        ld      (f_mask),a
        pop     de
        ld      a,e
        ld      (f_ny),a
        pop     de
        ld      a,e
        ld      (f_xb),a
        pop     de
        ld      a,e
        ld      (f_y),a
        push    de
        push    de
        push    de
        push    de
        push    de
        push    hl
        ld      a,(f_ny)
        or      a
        ret     z
        xor     a
        ld      (t_a),a
mb_plane:
        ld      a,(t_a)
        call    plane_in
        ld      a,(f_xb)
        ld      e,a
        ld      a,(f_y)
        call    line_hl
        ld      a,(f_col)
        ld      b,a
        ld      a,(t_a)
        inc     a
        ld      c,a
mb_c:
        ld      a,b
        rrca
        ld      b,a
        dec     c
        jr      nz,mb_c
        sbc     a,a
        ld      d,a                     ; the colour's byte for this plane
        ld      a,(f_mask)
        and     d
        ld      d,a                     ; the bits to set
        ld      a,(f_mask)
        cpl
        ld      e,a                     ; the bits to keep
        ld      a,(f_ny)
        ld      b,a
mb_line:
        ld      a,(hl)
        and     e
        or      d
        ld      (hl),a
        push    de
        ld      de,40
        add     hl,de
        pop     de
        djnz    mb_line
        ld      a,(t_a)
        inc     a
        ld      (t_a),a
        cp      4
        jr      nz,mb_plane
        jp      restore

; ---- void mz_recolour(uint8_t col, uint8_t row, uint8_t n, uint8_t ink, uint8_t paper): n cells of white text on black (every plane the same) to ink on paper ----------------------------
_mz_recolour:
        pop     hl
        pop     de
        ld      a,e
        ld      (g_pap),a
        pop     de
        ld      a,e
        ld      (g_ink),a
        pop     de
        ld      a,e
        ld      (f_nb),a
        pop     de
        ld      a,e
        ld      (t_row),a
        pop     de
        ld      a,e
        ld      (t_col),a
        push    de
        push    de
        push    de
        push    de
        push    de
        push    hl
        ld      a,(f_nb)
        or      a
        ret     z
        ld      a,(t_col)
        ld      d,a
        ld      a,(t_row)
        ld      e,a
        call    cell_hl
        ld      (t_dest),hl
        ; the text's bits (plane 0 of the n cells' 8 lines) into rc_buf: line by line, n bytes each
        xor     a
        call    plane_in
        ld      hl,(t_dest)
        ld      de,rc_buf
        ld      b,8
rc_rd:
        push    bc
        push    hl
        ld      a,(f_nb)
        ld      c,a
        ld      b,0
        ldir
        pop     hl
        ld      bc,40
        add     hl,bc
        pop     bc
        djnz    rc_rd
        xor     a
        ld      (t_a),a
rc_plane:
        ld      a,(g_ink)
        ld      hl,t_a
        ld      b,(hl)
        inc     b
rc_i:
        rrca
        djnz    rc_i
        sbc     a,a
        ld      d,a
        ld      a,(g_pap)
        ld      b,(hl)
        inc     b
rc_p:
        rrca
        djnz    rc_p
        sbc     a,a
        ld      e,a
        ld      a,d
        xor     e
        ld      d,a                     ; d = ink xor paper mask, e = paper mask
        ld      a,(t_a)
        call    plane_in
        ld      hl,(t_dest)
        ld      bc,rc_buf
        ld      a,8
        ld      (t_n),a
rc_line:
        push    hl
        ld      a,(f_nb)
        ld      (t_m),a
rc_b:
        ld      a,(bc)
        and     d
        xor     e
        ld      (hl),a
        inc     bc
        inc     hl
        ld      a,(t_m)
        dec     a
        ld      (t_m),a
        jr      nz,rc_b
        pop     hl
        push    bc
        ld      bc,40
        add     hl,bc
        pop     bc
        ld      a,(t_n)
        dec     a
        ld      (t_n),a
        jr      nz,rc_line
        ld      a,(t_a)
        inc     a
        ld      (t_a),a
        cp      4
        jr      nz,rc_plane
        jp      restore

; ---- void mz_wrline(uint8_t y, const uint8_t *pixels, uint8_t nlines): 192 pixels (a colour 0-15 each) from byte column XB0 on, written to nlines lines from line y -----------------------
_mz_wrline:
        pop     hl
        pop     de
        ld      a,e
        ld      (f_ny),a
        pop     bc                      ; pixels
        pop     de
        ld      a,e
        ld      (f_y),a
        push    de
        push    de
        push    de
        push    hl
        ld      (t_src),bc
        xor     a
        ld      (t_a),a
wl_plane:
        ; this plane's 24 bytes into rc_buf: the plane's bit of each pixel, the first pixel ending in bit 0
        ld      a,(t_a)
        ld      b,a
        ld      a,1
        inc     b
wl_m:
        dec     b
        jr      z,wl_mm
        add     a,a
        jr      wl_m
wl_mm:
        ld      (t_m),a                 ; the plane's bit
        ld      hl,(t_src)
        ld      de,rc_buf
        ld      a,24
        ld      (t_n),a
wl_grp:
        ld      b,8
wl_px:
        ld      a,(t_m)
        and     (hl)
        inc     hl
        add     a,$ff                   ; carry if this plane's bit is set
        rr      c
        djnz    wl_px
        ld      a,c
        ld      (de),a
        inc     de
        ld      a,(t_n)
        dec     a
        ld      (t_n),a
        jr      nz,wl_grp
        ld      a,(t_a)
        call    plane_in
        ld      a,(f_y)
        ld      e,XB0
        call    line_hl
        ld      a,(f_ny)
        ld      b,a
wl_line:
        push    bc
        push    hl
        ld      de,rc_buf
        ex      de,hl
        ld      bc,24
        ldir
        pop     hl
        ld      bc,40
        add     hl,bc
        pop     bc
        djnz    wl_line
        ld      a,(t_a)
        inc     a
        ld      (t_a),a
        cp      4
        jr      nz,wl_plane
        jp      restore

; ---- void mz_shift(uint8_t row, uint8_t rows, int8_t dx, int8_t dy): scroll the cell rows row to row + rows - 1 (32 cells wide): what was in cell (x, y) is now in (x - dx, y - dy) ------------------
_mz_shift:
        pop     hl
        pop     de
        ld      a,e
        ld      (s_dy),a
        pop     de
        ld      a,e
        ld      (s_dx),a
        pop     de
        ld      a,e
        ld      (s_rows),a
        pop     de
        ld      a,e
        ld      (s_row),a
        push    de
        push    de
        push    de
        push    de
        push    hl
        ; the width left: 32 - |dx| bytes; the lines: rows * 8 - |dy| * 8
        ld      a,(s_dx)
        ld      b,a
        bit     7,a
        jr      z,sh_dxp
        neg
sh_dxp:
        ld      c,a
        ld      a,32
        sub     c
        ld      (s_w),a
        ld      a,(s_dy)
        bit     7,a
        jr      z,sh_dyp
        neg
sh_dyp:
        add     a,a
        add     a,a
        add     a,a                     ; |dy| * 8
        ld      c,a
        ld      a,(s_rows)
        add     a,a
        add     a,a
        add     a,a                     ; rows * 8
        ld      (s_h),a
        sub     c
        ld      (s_n),a                 ; the lines that are kept: rows * 8 - |dy| * 8
        ret     z
        ret     c
        xor     a
        ld      (t_a),a
sh_plane:
        ld      a,(t_a)
        call    plane_in
        ; first source line, first destination line, and the direction: the content moves to lower addresses when dy > 0, or dy = 0 and dx > 0
        ld      a,(s_row)
        add     a,a
        add     a,a
        add     a,a                     ; the first line of the area
        ld      (s_l0),a
        ld      a,(s_dy)
        bit     7,a
        jr      nz,sh_dyneg
        ; dy >= 0: destination = the first line, source = that + dy * 8; copy forward
        add     a,a
        add     a,a
        add     a,a
        ld      c,a
        ld      a,(s_l0)
        add     a,c
        ld      (s_src),a               ; the first source line
        ld      a,(s_l0)
        ld      (s_dst),a               ; the first destination line
        ld      a,1
        ld      (s_dir),a
        jr      sh_go
sh_dyneg:
        neg
        add     a,a
        add     a,a
        add     a,a
        ld      c,a                     ; |dy| * 8
        ld      a,(s_l0)
        add     a,c
        ld      (s_dst),a               ; the destination is |dy| lines lower, the source the first line; copy from the last line back
        ld      a,(s_l0)
        ld      (s_src),a
        xor     a
        ld      (s_dir),a
sh_go:
        ld      a,(s_n)
        ld      (t_n),a                 ; the lines to copy
        ; the byte columns: destination x = 4 + (dx < 0 ? -dx : 0), source x = 4 + (dx > 0 ? dx : 0)
        ld      a,(s_dx)
        ld      b,XB0
        ld      c,XB0
        bit     7,a
        jr      nz,sh_dxn
        add     a,XB0
        ld      c,a                     ; source column
        jr      sh_cols
sh_dxn:
        neg
        add     a,XB0
        ld      b,a                     ; destination column
sh_cols:
        ld      a,b
        ld      (s_dcol),a
        ld      a,c
        ld      (s_scol),a
        ld      a,(s_dir)
        or      a
        jr      z,sh_back
sh_fwd:                                 ; lines ascending (ldir: the ranges may overlap within a line when dx != 0)
        ld      a,(s_src)
        ld      hl,s_scol
        ld      e,(hl)
        call    line_hl
        push    hl
        ld      a,(s_dst)
        ld      hl,s_dcol
        ld      e,(hl)
        call    line_hl
        ex      de,hl
        pop     hl
        ld      a,(s_w)
        ld      c,a
        ld      b,0
        ld      a,(s_dx)
        bit     7,a
        jr      nz,sh_fl                ; dx < 0: the content moves up in the line: copy backwards
        ldir
        jr      sh_fnext
sh_fl:
        ld      a,(s_w)
        dec     a
        ld      c,a
        ld      b,0
        add     hl,bc
        ex      de,hl
        add     hl,bc
        ex      de,hl
        inc     c
        lddr
sh_fnext:
        ld      hl,s_src
        inc     (hl)
        ld      hl,s_dst
        inc     (hl)
        ld      hl,t_n
        dec     (hl)
        jr      nz,sh_fwd
        jr      sh_pnext
sh_back:                                ; lines from the last to the first
        ld      a,(s_n)
        dec     a
        ld      hl,s_src
        add     a,(hl)
        ld      (s_src),a
        ld      a,(s_n)
        dec     a
        ld      hl,s_dst
        add     a,(hl)
        ld      (s_dst),a
sh_bl:
        ld      a,(s_src)
        ld      hl,s_scol
        ld      e,(hl)
        call    line_hl
        push    hl
        ld      a,(s_dst)
        ld      hl,s_dcol
        ld      e,(hl)
        call    line_hl
        ex      de,hl
        pop     hl
        ld      a,(s_w)
        ld      c,a
        ld      b,0
        ld      a,(s_dx)
        bit     7,a
        jr      nz,sh_bl2
        or      a
        jr      z,sh_bl3
        ldir
        jr      sh_bnext
sh_bl3:
        ldir
        jr      sh_bnext
sh_bl2:
        ld      a,(s_w)
        dec     a
        ld      c,a
        ld      b,0
        add     hl,bc
        ex      de,hl
        add     hl,bc
        ex      de,hl
        inc     c
        lddr
sh_bnext:
        ld      hl,s_src
        dec     (hl)
        ld      hl,s_dst
        dec     (hl)
        ld      hl,t_n
        dec     (hl)
        jr      nz,sh_bl
sh_pnext:
        ld      a,(t_a)
        inc     a
        ld      (t_a),a
        cp      4
        jp      nz,sh_plane
        jp      restore

; ---- void mz_icon(uint8_t col, uint8_t y, uint16_t offset): the 24x14 icon at that offset of the atlas to byte column col (of the 40), line y; the page and offset are the atlas's ---------------------
_mz_icon:
        pop     hl
        pop     bc                      ; offset in the atlas
        pop     de                      ; y
        ld      a,e
        ld      (f_y),a
        pop     de                      ; col
        ld      a,e
        ld      (f_xb),a
        push    de
        push    de
        push    de
        push    hl
        ; the icon is 168 bytes and can run over a page (8 KB) boundary: map the page of its first byte and the next one into windows 2 and 3? Window 3 is the plane: so
        ; the atlas page is mapped in window 2 only, and the icons are kept within one page by their position (the atlas puts them after the pictures, which end below 17504
        ; of the first 24576 bytes: pages 22 to 24); a boundary is at 8192, 16384: 168 bytes never straddles it if the icon block is placed to avoid them (mz_atlas.asm checks)
        ld      a,b
        rlca
        rlca
        rlca
        and     7                       ; (offset >> 13): the page index within the atlas
        add     a,PAGE_ATLAS
        ld      d,a
        ld      a,b
        and     $1f
        add     a,$40
        ld      b,a                     ; bc = $4000 + offset & $1fff
        ld      a,2
        out     ($b4),a
        ld      a,d
        out     ($b5),a
        ld      (t_src),bc
        xor     a
        ld      (t_a),a
ic_plane:
        ld      a,(t_a)
        call    plane_in
        ld      a,(f_y)
        ld      hl,f_xb
        ld      e,(hl)
        call    line_hl
        ex      de,hl
        ld      hl,(t_src)
        ld      b,14
ic_line:
        push    bc
        push    de
        ld      bc,3
        ldir
        pop     de
        ex      de,hl
        ld      bc,40
        add     hl,bc
        ex      de,hl
        pop     bc
        djnz    ic_line
        ld      (t_src),hl
        ld      a,(t_a)
        inc     a
        ld      (t_a),a
        cp      4
        jr      nz,ic_plane
        jp      restore

; ---- the timer (the 8253 at $E4-$E7: channel 0 counts a 31250 Hz clock; run free as a 16 bit down counter, mode 2 with the count 0 = 65536, it is a clock the game can ask the time of) ---------------
_mz_pit_init:
        ld      a,$34                   ; channel 0, low then high byte, mode 2
        out     ($e7),a
        xor     a
        out     ($e4),a
        out     ($e4),a
        ret

; uint16_t mz_pit_read(void): the count now
_mz_pit_read:
        xor     a                       ; latch channel 0
        out     ($e7),a
        in      a,($e4)
        ld      l,a
        in      a,($e4)
        ld      h,a
        ret

; ---- void mz_arrow(uint8_t y, uint8_t xb, const uint8_t *buf): the pointer's 16 lines x 3 bytes in screen B (over the map in mode $14: pixel value 0 is transparent): for each line
; buf has six bytes, the 3 of the pixels that are in all the planes' colour white (planes 0-2) and the 3 of white or outline (plane 3: the outline is colour 8); a buf of 0 clears
; the 16 x 3 bytes.  The lines stop at the bottom of the screen (line 199). -------------------------------------------------------------------------------------------------
_mz_arrow:
        ld      hl,2
        add     hl,sp
        ld      c,(hl)
        inc     hl
        ld      b,(hl)                  ; buf
        inc     hl
        ld      e,(hl)                  ; xb
        inc     hl
        inc     hl
        ld      a,(hl)                  ; y
        ld      (f_y),a
        ld      a,e
        ld      (f_xb),a
        ld      (t_src),bc
        ld      a,200
        ld      hl,f_y
        sub     (hl)
        ret     z
        ret     c
        cp      16
        jr      c,ar_n
        ld      a,16
ar_n:
        ld      (f_ny),a
        xor     a
        ld      (t_a),a
ar_plane:
        ld      a,(t_a)
        call    plane_in_b
        ld      a,(f_y)
        ld      hl,f_xb
        ld      e,(hl)
        call    line_hl
        ex      de,hl                   ; de = the destination
        ld      hl,(t_src)
        ld      a,h
        or      l
        jr      z,ar_clear
        ld      a,(t_a)
        cp      3
        jr      nz,ar_src
        ld      bc,3                    ; plane 3 takes the second half of a line's six bytes
        add     hl,bc
ar_src:
        ld      a,(f_ny)
        ld      b,a
ar_line:
        push    bc
        ld      bc,3
        ldir
        ld      bc,3
        add     hl,bc                   ; (the other half of the line's six bytes)
        ex      de,hl
        ld      bc,37
        add     hl,bc
        ex      de,hl
        pop     bc
        djnz    ar_line
        jr      ar_next
ar_clear:
        ld      a,(f_ny)
        ld      b,a
ar_cl:
        xor     a
        ld      (de),a
        inc     de
        ld      (de),a
        inc     de
        ld      (de),a
        ld      hl,38
        add     hl,de
        ex      de,hl
        djnz    ar_cl
ar_next:
        ld      a,(t_a)
        inc     a
        ld      (t_a),a
        cp      4
        jr      nz,ar_plane
        jp      restore

; ---- void mz_clearb(void): the four planes of screen B cleared (the pointer's layer) ------------------------------------------------------------------------------------
_mz_clearb:
        xor     a
        ld      (t_a),a
cb_plane:
        ld      a,(t_a)
        call    plane_in_b
        ld      hl,$6000
        ld      de,$6001
        ld      bc,8000-1
        ld      (hl),0
        ldir
        ld      a,(t_a)
        inc     a
        ld      (t_a),a
        cp      4
        jr      nz,cb_plane
        jp      restore

; ---- the mouse (Takeda: the SIO channel B at $A2 data, $A3 control, whose DTR going low sends three bytes: the buttons and the overflow bits, the x movement and the y movement; the
; YM2203's port A bit 3 selects the mouse) ---------------------------------------------------------------------------------------------------------------------------------
_mz_mouse_init:
        ld      a,$0e                   ; the mouse select
        out     ($c8),a
        in      a,($c9)
        or      8
        out     ($c9),a
        ld      a,$18                   ; channel B reset
        out     ($a3),a
        ld      a,4                     ; WR4: x16 clock, 1 stop bit, no parity
        out     ($a3),a
        ld      a,$44
        out     ($a3),a
        ld      a,3                     ; WR3: 8 bits, receiver on
        out     ($a3),a
        ld      a,$c1
        out     ($a3),a
        ld      a,5                     ; WR5: 8 bits, DTR off
        out     ($a3),a
        ld      a,$60
        out     ($a3),a
        ret

; uint8_t mz_sio_ready(void): a byte has been received
_mz_sio_ready:
        in      a,($a3)
        and     1
        ld      l,a
        ld      h,0
        ret

; uint8_t mz_sio_data(void)
_mz_sio_data:
        in      a,($a2)
        ld      l,a
        ld      h,0
        ret

; void mz_sio_trigger(void): DTR off and on again: the mouse sends its next movement
_mz_sio_trigger:
        ld      a,5
        out     ($a3),a
        ld      a,$60
        out     ($a3),a
        ld      a,5
        out     ($a3),a
        ld      a,$e0
        out     ($a3),a
        ret

; ---- void mz_pal4096(void): the YM2203's port A bit 2 (register $0E) low, which is what makes the CRTC use the 4096 colour palette ($AE) rather than the fixed digital 16 colours (the IPL
; sets it); a read-modify-write as the IPL's own code does it, so the floppy and mouse bits stay ------------------------------------------------------------------------------------
_mz_pal4096:
        ld      a,$0e
        out     ($c8),a
        in      a,($c9)
        and     $fb
        out     ($c9),a
        ret

; ---- the keyboard: the Z80 PIO (port A data $E8 takes the column in bits 0-3 with bit 4 set, port B data $EA gives that column's keys, a down key a 0 bit; the bits 5-7 of port A are the
; text screen's column size and the memory's, which are kept; control ports $E9 and $EB) ------------------------------------------------------------------------------------------
; void mz_keyinit(void): port A output, port B input
_mz_keyinit:
        ld      a,$0f
        out     ($e9),a
        ld      a,$4f
        out     ($eb),a
        ret

; uint8_t mz_keycol(uint8_t column) __smallc
_mz_keycol:
        ld      hl,2
        add     hl,sp
        ld      c,(hl)
        in      a,($e8)
        and     $e0
        or      $10
        or      c
        out     ($e8),a
        in      a,($ea)
        ld      l,a
        ld      h,0
        ret

; ---- void mz_cleartext(void): the text screen's video RAM (page $38, 6 KB) cleared, so the IPL's messages are gone (window 3, put back) ----------------------------------------
_mz_cleartext:
        ld      a,3
        out     ($b4),a
        ld      a,$38
        out     ($b5),a
        ld      hl,$6000
        ld      de,$6001
        ld      bc,$17ff
        ld      (hl),0
        ldir
        jp      restore

; ---- void mz_clear(void): all four planes black (the whole 40 x 200) ---------------------------------------------------------------------
_mz_clear:
        xor     a
        ld      (t_a),a
cl_plane:
        ld      a,(t_a)
        call    plane_in
        ld      hl,$6000
        ld      de,$6001
        ld      bc,8000-1
        ld      (hl),0
        ldir
        ld      a,(t_a)
        inc     a
        ld      (t_a),a
        cp      4
        jr      nz,cl_plane
        jp      restore

        SECTION bss_user
mz_w2:  defb    0
mz_w3:  defb    0
t_a:    defw    0
t_n:    defb    0
t_m:    defb    0
t_row:  defb    0
t_col:  defb    0
t_dest: defw    0
t_src:  defw    0
g_ink:  defb    0
g_pap:  defb    0
g_buf:  defs    8
g_ptr:  defw    0
f_col:  defb    0
f_ny:   defb    0
f_nb:   defb    0
f_xb:   defb    0
f_y:    defb    0
f_mask: defb    0
s_dx:   defb    0
s_dy:   defb    0
s_row:  defb    0
s_rows: defb    0
s_w:    defb    0
s_h:    defb    0
s_n:    defb    0
s_l0:   defb    0
s_src:  defb    0
s_dst:  defb    0
s_dir:  defb    0
s_scol: defb    0
s_dcol: defb    0
rc_buf: defs    256
