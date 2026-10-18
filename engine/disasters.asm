; disasters: lines 4606-4799 of disassembly/sim_game.asm (engine)
; Randomly trigger a fire or flood event at the current simulation position
.sim_maybe_start_fire_or_flood
.L78ca  ld      a,(V_aircrash_active)
        and     a
        ret     nz

        call    get_random_number
        and     1
        ret     nz

        call    get_random_number
        and     1
        jr      z,L78f0                 ; (20)
        ld      bc,(V_map_iter_xy)
        ld      a,c
        ld      (V_aircrash_col),a
        ld      c,96
        ld      (V_CrashXY),bc

activate_aircrash:                                    ; $78EA / 30954 - Set V_aircrash_active=1; entry after CrashXY and aircrash column set up
.L78ea  ld      a,1
        ld      (V_aircrash_active),a
        ret     


.L78f0  ld      bc,(V_map_iter_xy)
        xor     a
        ld      (V_aircrash_col),a
        ld      (V_CrashXY),bc
        jr      activate_aircrash                   ; (-20)

.sim_start_aircrash
.L78fe  ld      a,(V_safe_AirportPop)
        and     a
        ret     z
        ld      a,25
        call    set_alert_message
        call    get_random_number
        and     15
        add     a,7
        ld      (V_aircrash_countdown),a
        ret     

.sim_start_meltdown
.L7913  ld      a,(V_safe_NuclearPop)       ;number of nuclear plants?
        and     a
        ret     z
        ld      a,18
        call    set_alert_message
        ld      a,1
        ld      (V_meltdown_triggered),a
        IFDEF PORTABLE
        jp      play_crash_sound
        ELSE
        jr      play_crash_sound                   ; (-103)
        ENDIF

V_meltdown_triggered:    defb        0       ; VAR $7924 / 31012 - meltdown triggered

; Nuclear meltdown - spread radiation everywhere?
place_fallout:
.L7925  ld      a,(V_meltdown_triggered)
        and     a
        ret     z
        xor     a
        ld      (V_meltdown_triggered),a
        ld      a,69
        ld      (V_fill_tile),a
        ld      hl,(V_map_iter_addr)
        call    fill_zone_with_tile
        ld      hl,(V_map_iter_xy)
        ld      a,h
        sub     20
        ld      d,a
        ld      a,l
        sub     20
        ld      e,a
        ld      b,45
.L7946  ld      c,45
        push    de
.L7949  push    bc
        ld      b,d
        ld      c,e
        call    get_random_number
        and     15
        call    z,L795e
        pop     bc
        inc     e
        dec     c
        jr      nz,L7949                ; (-16)
        pop     de
        inc     d
        djnz    L7946                   ; (-23)
        ret     


.L795e  call    levelmap_xypos_with_check
        ret     nc
        ld      a,(hl)
        bit     7,a
        ret     nz
        cp      TILE_WATER
        ret     z
        ld      (hl),TILE_RADIOACTIVE
        ret     



.sim_start_tornado
.L796c  ld      a,26
        call    set_alert_message
        ld      a,1
        ld      (V_tornado_active),a

.L7976  call    get_random_number       ;Get a starting coordinate in 64x64 grid
        and     63
        add     a,16
        ld      b,a
        call    get_random_number
        and     63
        add     a,16
        ld      c,a
        push    bc
        call    levelmap_xypos
        pop     bc
        ld      a,(hl)
        cp      TILE_DIRT               ;DIRT
        jr      nz,L7976                ; (-26)
        ld      (V_tornado_pos),bc
        ret     

V_tornado_pos:    defw    0       ; VAR $7995 / 31125 - tornado current map position (b=y, c=x); random dirt start
V_tornado_active:    defb    0       ; VAR $7997 / 31127 - tornado active (1=in progress, 0=none); cleared with 1/256 chance each tick

; Something to do with parks?
move_tornado:                                    ; $7998 / 31128 - If tornado active: 1/256 chance despawn; every 8 ticks steer toward CCxy centroid, else random walk
.L7998  ld      a,(V_tornado_active)
        and     a
        ret     z
        call    get_random_number
        and     a
        jr      nz,L79a7                ; (4)
        xor     a
        ld      (V_tornado_active),a
.L79a7  ld      bc,(V_tornado_pos)
        call    get_random_number
        and     7
        jr      nz,L79ea                ; (56)
        ld      hl,(V_CCxy)
        ld      a,h
        sub     b
        jr      z,L79be                 ; (5)
        sbc     a,a
        or      1
        add     a,b
        ld      b,a
.L79be  ld      a,l
        sub     c
        jr      z,L79c7                 ; (5)
        sbc     a,a
        or      1
        add     a,c
        ld      c,a
.L79c7  push    bc
        call    levelmap_xypos
        pop     bc
        ld      a,(hl)
        cp      0
        ret     z
        ld      (V_tornado_pos),bc
tornado_destroy_cell:                                    ; $79D4 / 31188 - At BC+1,+1: if in map and tile is flammable (bit 7 set), convert to rubble (tile 58)
.L79d4  inc     c
        inc     b
        call    levelmap_xypos_with_check
        ret     nc
        ld      a,(hl)
        call    tile_to_flags
        bit     7,a
        ret     z
        ld      a,(hl)
        bit     7,a
        jp      nz,L7bbb
        ld      (hl),58
        ret     


.L79ea  call    get_random_number
        and     3
        call    coords_add_direction_offset               ;Move coords in direction
        push    bc
        call    levelmap_xypos
        pop     bc
        ld      a,(hl)
        cp      0
        ret     z
        ld      (V_tornado_pos),bc
        jr      tornado_destroy_cell                   ; (-45)

