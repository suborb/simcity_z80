; transport: lines 4448-4592 of disassembly/sim_game.asm (engine)

V_transport_pos:    defw    0       ; VAR $77D3 / 30675 - transport sprite current map position (b=y, c=x)

V_transport_sprite:    defb    0       ; VAR $77D5 / 30677 - transport sprite type index (passed to display_transport_sprite)

V_transport_active:    defb        0       ; VAR $77D6 / 30678 - transport sprite active (1=train/tram moving, 0=idle)
V_transport_prev_dir:    defb        0       ; VAR $77D7 / 30679 - previous direction taken (prevents U-turns)
V_transport_dir:    defb        0       ; VAR $77D8 / 30680 - current direction being evaluated (0-3)
V_transport_new_dir:    defb        0       ; VAR $77D9 / 30681 - confirmed next direction after rail check
V_transport_steps:    defb        0       ; VAR $77DA / 30682 - steps remaining before direction re-roll
V_transport_wander:    defb        0       ; VAR $77DB / 30683 - wander counter (decrements; sprite despawns at 0)


move_transport_sprite:                                    ; $77DC / 30684 - If transport active and on rail tile, step sprite in current direction; else despawn
.L77dc  ld      a,(V_transport_active)
        and     a
        ret     z
        ld      bc,(V_transport_pos)
        call    levelmap_xypos
        ld      a,(hl)
        call    tile_to_flags
        and     2                       ;rail?
        jr      nz,L77f5                ; (5)
        xor     a
        ld      (V_transport_active),a
        ret     


.L77f5  ld      bc,(V_transport_pos)
        call    get_random_number
        and     3
        ld      (V_transport_dir),a
        ld      a,4
        ld      (V_transport_steps),a

.L7806  ld      a,(V_transport_dir)
        and     3
        ld      (V_transport_new_dir),a
        ld      hl,V_transport_prev_dir
        cp      (hl)
        jr      z,L7822                 ; (14)
        ld      a,(V_transport_new_dir)               ;Direction to look in
        call    levelmap_addr_in_direction                   ;Move in direction
        ld      a,(hl)
        call    tile_to_flags
        and     2
        jr      nz,L783d                ; (27)

.L7822  ld      hl,V_transport_dir
        inc     (hl)
        ld      hl,V_transport_steps
        dec     (hl)
        jr      nz,L7806                ; (-38)
        ld      hl,V_transport_wander
        ld      a,(hl)
        inc     a
        ld      (hl),a
        cp      5
        ret     nz

        ld      (hl),0
        ld      a,5
        ld      (V_transport_prev_dir),a
        ret     


.L783d  ld      a,(V_transport_new_dir)
        call    coords_add_direction_offset               ;Move coords in direction
        ld      a,(V_transport_new_dir)
        add     a,2
        and     3
        ld      (V_transport_prev_dir),a
        ld      (V_transport_pos),bc
        ld      c,3
        and     1
        jr      nz,L7858                ; (1)
        inc     c

.L7858  ld      a,c
        ld      (V_transport_sprite),a
        ret     


maybe_spawn_transport:                                    ; $785D / 30813 - If no transport active and 1:64 chance, spawn transport sprite at current simulation position
.L785d  ld      a,(V_Transport_Funding_Requested+1)
        cp      8
        ld      a,(V_transport_active)
        and     a
        ret     nz

        call    get_random_number
        and     63
        ret     nz

        ld      hl,(V_map_iter_xy)
        ld      (V_transport_pos),hl
        ld      a,1
        ld      (V_transport_active),a
        ret     

V_aircrash_active:    defb        0       ; VAR $7879 / 30841 - aircrash in progress (1=active, 0=none)
V_CrashXY:    defw        0       ; VAR $787A / 30842 - aircrash current map position (b=y, c=x)
V_aircrash_col:    defb        0       ; VAR $787C / 30844 - aircrash target display column
V_aircrash_countdown:    defb        0       ; VAR $787D / 30845 - aircrash movement timer (decrements each tick)


move_aircrash_sprite:                                    ; $787E / 30846 - If aircrash active and not at target column, decrement countdown; at zero ignite 2x2 cells
.L787e  ld      a,(V_aircrash_active)
        and     a
        ret     z
        ld      a,(V_CrashXY)
        ld      hl,V_aircrash_col
        cp      (hl)
        jr      z,L78af                 ; (35)
        ld      hl,V_CrashXY
        dec     (hl)
        ld      hl,V_aircrash_countdown
        ld      a,(hl)
        and     a
        ret     z
        dec     (hl)
        ret     nz
        ld      bc,(V_CrashXY)          ;And here we start an aircrash?
        call    set_cell_on_fire
        inc     c
        call    set_cell_on_fire
        dec     c
        inc     b
        call    set_cell_on_fire
        inc     c
        call    set_cell_on_fire
        call    play_crash_sound
.L78af  xor     a
        ld      (V_aircrash_active),a
        ret     


; Get map address for bc coords and ignite cell if flammable
.set_cell_on_fire
.L78b4  push    bc
        call    levelmap_xypos
        call    ignite_cell_if_flammable
        pop     bc
        ret     

