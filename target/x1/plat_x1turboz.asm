; X1turboZ 320x200x64 art.  The 471 Amiga 1 Meg tiles, 76 animation
; frames and 112 icon cells live in graphics page 1, disk tracks 16..23.

        SECTION code_user
        PUBLIC  tz_init, _plat_put_tile
        EXTERN  _view_tile_art, _V_view_tick, asm_x1_disk_regs, asm_set_palette
        EXTERN  mp_cached, mp_scraddr, mp_scr
        IFDEF   HAVE_SOUND
        EXTERN  ay_poll
        ENDIF

tz_init:
        ld      bc,$1800               ; explicit CRTC start address zero
        ld      a,12
        out     (c),a
        inc     c
        xor     a
        out     (c),a
        dec     c
        ld      a,13
        out     (c),a
        inc     c
        xor     a
        out     (c),a
        ld      bc,$1fb0
        ld      a,$90                   ; AEN | C64: 64 colours, two pages
        out     (c),a
        ld      bc,$1fc0
        xor     a                       ; display page 0
        out     (c),a
        ld      bc,$1fc5
        ld      a,$80                   ; analog palette writes
        out     (c),a
        call    tz_palette
        ; The Turbo Z graphics palette is separate from the standard 8-colour
        ; palette used by text. Restore the X1 palette with APEN disabled so
        ; the I/O writes update the standard palette registers.
        ld      bc,$1fc5
        xor     a
        out     (c),a
        ld      hl,$CCAA
        ld      e,$F0
        call    asm_set_palette
        ld      bc,$1fc5
        ld      a,$80
        out     (c),a
        ld      a,16
        ld      (tz_track),a
        ld      a,1
        ld      (tz_sector),a
        ld      hl,0
        ld      (tz_left),hl
        ld      (tz_index),hl
        ld      bc,$1fd0
        ld      a,$10                   ; CPU graphics page 1
        out     (c),a
tz_load_next:
        ld      hl,tz_tile
        ld      b,48
tz_load_byte:
        push    bc
        push    hl
        call    tz_next_byte
        pop     hl
        pop     bc
        ld      (hl),a
        inc     hl
        djnz    tz_load_byte
        call    tz_write_tile
        ld      hl,(tz_index)
        inc     hl
        ld      (tz_index),hl
        ld      de,659                  ; 471 + 76 + 14 * 4 * 2
        or      a
        sbc     hl,de
        jr      nz,tz_load_next
        ld      bc,$1fd0
        xor     a                       ; leave CPU on visible page 0
        out     (c),a
        ret

; void plat_put_tile(col,row,art,attr,inverse): art is view_tile_art + 8*n.
_plat_put_tile:
        ld      hl,2
        add     hl,sp
        ld      c,(hl)
        inc     hl
        inc     hl
        inc     hl
        inc     hl                      ; ignore attr
        ld      e,(hl)
        inc     hl
        ld      d,(hl)
        inc     hl
        ld      a,(hl)                  ; row
        inc     hl
        inc     hl
        ld      b,(hl)                  ; column
        call    tz_animate              ; frame's art address is the cache key
        call    mp_cached
        ret     c
        push    af
        ld      a,c
        ld      (tz_inverse),a
        pop     af
        call    mp_scraddr             ; mp_scr = row*40+col
        ld      bc,$1fd0
        ld      a,$10
        out     (c),a
        call    tz_read_tile           ; graphics page 1 -> 48-byte RAM buffer
        ld      a,(tz_inverse)
        and     1
        call    nz,tz_invert
        ld      bc,$1fd0
        xor     a
        out     (c),a
        call    tz_draw_tile           ; RAM buffer -> displayed page 0
        IFDEF   HAVE_SOUND
        jp      ay_poll
        ELSE
        ret
        ENDIF

; Convert the art address to an atlas index and advance animated map tiles.
; The frame's art address is returned in DE so mp_cached sees frame changes.
; A, B and C are preserved.
tz_animate:
        push    af
        push    bc
        push    de
        ex      de,hl
        ld      de,_view_tile_art
        or      a
        sbc     hl,de
        srl     h
        rr      l
        srl     h
        rr      l
        srl     h
        rr      l
        ld      (tz_index),hl
        ld      bc,471
        or      a
        sbc     hl,bc
        jr      nc,tz_anim_none        ; icons and frame art are not animated
        add     hl,bc
        ld      bc,tz_animmap
        add     hl,bc
        ld      a,(hl)
        or      a
        jr      z,tz_anim_none
        dec     a
        ld      c,a
        add     a,a
        add     a,c
        ld      l,a
        ld      h,0
        ld      bc,tz_animtab
        add     hl,bc
        ld      c,(hl)
        inc     hl
        ld      b,(hl)
        inc     hl
        ld      d,(hl)
        ld      a,(_V_view_tick)
        rrca
        rrca
        rrca
        rrca
        and     d
        ld      l,a
        ld      h,0
        add     hl,bc
        ld      (tz_index),hl
        add     hl,hl
        add     hl,hl
        add     hl,hl
        ld      bc,_view_tile_art
        add     hl,bc
        pop     de                      ; discard original art address
        ex      de,hl
        pop     bc
        pop     af
        ret
tz_anim_none:
        pop     de
        pop     bc
        pop     af
        ret

tz_invert:
        ld      hl,tz_tile
        ld      b,48
tz_inv_loop:
        ld      a,(hl)
        cpl
        ld      (hl),a
        inc     hl
        djnz    tz_inv_loop
        ret

; The port bases are the two bits of blue, then red, then green.  A row
; advances the port's high byte by eight, as on the ordinary X1 renderer.
tz_read_tile:
        ld      hl,tz_tile
        ld      de,tz_ports
        ld      a,6
        ld      (tz_planes),a
tz_rd_plane:
        ld      a,(de)
        inc     de
        ld      b,a
        ld      a,(tz_index+1)
        add     a,b
        ld      b,a
        ld      a,(tz_index)
        ld      c,a
        REPT    8
        in      a,(c)
        ld      (hl),a
        inc     hl
        ld      a,b
        add     a,8
        ld      b,a
        ENDR
        ld      a,(tz_planes)
        dec     a
        ld      (tz_planes),a
        jr      nz,tz_rd_plane
        ret

tz_write_tile:
        ld      hl,tz_tile
        ld      de,tz_ports
        ld      a,6
        ld      (tz_planes),a
tz_wr_plane:
        ld      a,(de)
        inc     de
        ld      b,a
        ld      a,(tz_index+1)
        add     a,b
        ld      b,a
        ld      a,(tz_index)
        ld      c,a
        REPT    8
        ld      a,(hl)
        out     (c),a
        inc     hl
        ld      a,b
        add     a,8
        ld      b,a
        ENDR
        ld      a,(tz_planes)
        dec     a
        ld      (tz_planes),a
        jr      nz,tz_wr_plane
        ret

tz_draw_tile:
        ld      hl,tz_tile
        ld      de,tz_ports
        ld      a,6
        ld      (tz_planes),a
tz_dr_plane:
        ld      a,(de)
        inc     de
        ld      b,a
        ld      a,(mp_scr+1)
        add     a,b
        ld      b,a
        ld      a,(mp_scr)
        ld      c,a
        REPT    8
        ld      a,(hl)
        out     (c),a
        inc     hl
        ld      a,b
        add     a,8
        ld      b,a
        ENDR
        ld      a,(tz_planes)
        dec     a
        ld      (tz_planes),a
        jr      nz,tz_dr_plane
        ret

tz_next_byte:
        push    bc
        push    de
        push    hl
        ld      hl,(tz_left)
        ld      a,h
        or      l
        jr      nz,tz_have_byte
        call    tz_read_sector
        ld      hl,tz_sector_buf
        ld      (tz_ptr),hl
        ld      hl,256
        ld      (tz_left),hl
tz_have_byte:
        ld      hl,(tz_ptr)
        ld      a,(hl)
        inc     hl
        ld      (tz_ptr),hl
        ld      hl,(tz_left)
        dec     hl
        ld      (tz_left),hl
        pop     hl
        pop     de
        pop     bc
        ret

tz_read_sector:
        ld      e,0                     ; drive 0
        ld      a,(tz_track)
        ld      d,a
        ld      a,(tz_sector)
        ld      c,a
        ld      b,1
        ld      hl,tz_sector_buf
        xor     a
        call    asm_x1_disk_regs
        call    tz_status_dot
        ld      a,(tz_sector)
        inc     a
        cp      17
        jr      c,tz_sector_next
        ld      a,(tz_track)
        inc     a
        ld      (tz_track),a
        ld      a,1
tz_sector_next:
        ld      (tz_sector),a
        ret

; Leave a little activity on the text layer while the atlas streams from disk.
tz_status_dot:
        ld      a,(tz_status_count)
        inc     a
        ld      (tz_status_count),a
        and     3
        ret     nz
        ld      a,(tz_status_col)
        cp      40
        ret     nc
        add     a,80                   ; row 2, below the IPL loading message
        ld      c,a
        ld      a,7
        ld      b,$20
        out     (c),a
        ld      a,'.'
        ld      b,$30
        out     (c),a
        ld      a,(tz_status_col)
        inc     a
        ld      (tz_status_col),a
        ret

tz_palette:
        push    ix
        ld      e,0
        ld      ix,tz_palette_rgb
tz_pal_next:
        ld      a,e
        and     $30
        rlca
        rlca
        ld      c,a
        ld      a,e
        and     $0c
        or      c
        ld      c,a
        ld      a,e
        and     3
        rrca
        rrca
        ld      h,a
        ld      a,(ix+2)                ; B
        or      h
        ld      b,$10
        out     (c),a
        ld      a,(ix+0)                ; R
        or      h
        ld      b,$11
        out     (c),a
        ld      a,(ix+1)                ; G
        or      h
        ld      b,$12
        out     (c),a
        inc     ix
        inc     ix
        inc     ix
        inc     e
        ld      a,e
        cp      64
        jr      nz,tz_pal_next
        pop     ix
        ret

        SECTION rodata_user
tz_ports:
        defb    $40,$44,$80,$84,$c0,$c4
tz_palette_rgb:
        BINARY  "build/x1turboz/palette.bin"
tz_animmap:
        BINARY  "build/x1turboz/animmap.bin"
tz_animtab:
        BINARY  "build/x1turboz/animtab.bin"

        SECTION bss_user
tz_tile:       defs    48
tz_sector_buf: defs    256
tz_index:      defw    0
tz_ptr:        defw    0
tz_left:       defw    0
tz_planes:     defb    0
tz_inverse:    defb    0
tz_track:      defb    0
tz_sector:     defb    0
tz_status_count: defb  0
tz_status_col: defb    0
