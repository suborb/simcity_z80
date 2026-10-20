; zx_sprites: lines 4334-4447 of disassembly/sim_game.asm (zx)
; Sprite printing?
; Entry: a = sprite number
display_transport_sprite:
.L7735  ld      hl,(V_view_topleft)
        ld      e,a
        ld      a,b
        cp      h
        ret     c

        ld      a,h
        add     a,14
        cp      b
        ret     c

        ld      a,b
        sub     h
        add     a,8
        ld      b,a
        ld      a,c
        cp      l
        ret     c

        ld      a,l
        add     a,30
        cp      c
        ret     c

        ld      a,c
        sub     l
        ld      c,a
        ld      a,(V_ui_tick_counter)
        and     15
        add     a,8
        cp      b
        ret     c

        ld      l,e
        ld      h,0
        add     hl,hl       ;16x16 blob printer?
        add     hl,hl
        add     hl,hl
        add     hl,hl
        add     hl,hl
        ld      de,transport_sprites
        add     hl,de
        ex      de,hl
        call    xypos
        ld      b,16

.L776c  push    hl
        ld      a,(hl)
        ld      c,a
        sla     a
        or      c
        ld      c,a
        ld      a,(hl)
        and     c
        ld      c,a
        ld      a,(de)
        or      c
        ld      (hl),a
        inc     de

.L777a  inc     l
        ld      a,(hl)
        ld      c,a
        sra     a
        or      c
        ld      c,a
        ld      a,(hl)
        and     c
        ld      c,a
        ld      a,(de)
        or      c
        ld      (hl),a
        inc     de
        pop     hl
        call    drow
        djnz    L776c                   ; (-34)
        ret     

; Does something with the transport sprite
display_sprites:                                    ; $778F / 30607 - Draw train/aircrash/tornado sprites if active; clear sprite if tile no longer valid
.L778f  ld      a,(V_transport_active)
        and     a
        jr      z,L77b3                 ; (30)
        ld      bc,(V_transport_pos)
        call    levelmap_xypos_with_check
        ld      a,(hl)
        cp      31
        jr      z,L77b3                 ; (18)
        cp      32
        jr      z,L77b3                 ; (14)
        ld      a,(V_transport_active)
        and     a
        ld      bc,(V_transport_pos)
        ld      a,(V_transport_sprite)
        call    nz,display_transport_sprite

.L77b3  ld      a,(V_aircrash_active)
        and     a
        ld      bc,(V_CrashXY)
        ld      a,0
        call    nz,display_transport_sprite
        ld      a,r
        and     1
        inc     a
        ld      d,a
        ld      a,(V_tornado_active)
        and     a
        ld      bc,(V_tornado_pos)
        ld      a,d
        call    nz,display_transport_sprite
        ret     
