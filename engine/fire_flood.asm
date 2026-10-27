; fire_flood: lines 8289-8347 of disassembly/sim_game.asm (engine)

.sim_start_fire
.L90a7  ld      a,22
        call    set_alert_message
        call    play_rising_tone
.L90af  ld      hl,levelmap
        ld      bc,MAP_CELLS
.L90b5  call    get_random_number
        and     127
        call    z,ignite_cell_if_flammable
        inc     hl
        dec     bc
        ld      a,b
        or      c
        jr      nz,L90b5                ; (-14)
        ret     
; Set cell to TILE_FIRE if it is flammable (skips zones, trees, and non-flammable tiles)
; Entry: hl = map address
.ignite_cell_if_flammable
.L90c4  ld      a,(hl)      ;Don't start fire in pd,fd,stadium etc?
        bit     7,a
        ret     nz
        call    tile_to_flags
        bit     7,a         ;Flammable?
        ret     z
        ld      a,(hl)
        cp      6           ;trees
        ret     z
        ld      (hl),TILE_FIRE
        ret     


.sim_start_flood
.L90d5  ld      a,23
        call    set_alert_message
        call    play_falling_tone
.L90dd  ld      hl,levelmap
        ld      bc,MAP_CELLS
.L90e3  ld      a,(hl)
        bit     7,a
        jr      nz,L90fc                ; (20)
        and     a           ;Water
        jr      z,L90fc                 ; (17)
        cp      2           ;Dirt
        jr      z,L90fc                 ; (13)
        cp      6           ;Floodable
        jr      nc,L90fc                ; (9)
        call    get_random_number
        and     31
        jr      nz,L90fc                ; (2)
        ld      (hl),TILE_FLOOD     ;Flood character?
.L90fc  inc     hl
        dec     bc
        ld      a,b
        or      c
        jr      nz,L90e3                ; (-31)
        ld      a,50
        ld      (V_flood_timer),a
        ret     
