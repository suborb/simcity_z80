; tools_b: lines 2781-3116 of disassembly/sim_game.asm (engine)
; 28190
        IN_RODATA
zone_costs:
        defw    1
        defw    10
        defw    5
        defw    20
        defw    10
        defw    100
        defw    100
        defw    100
        defw    500         ;Police
        defw    500         ;Fire
        defw    3000
        defw    4000
        defw    5000
        defw    10000       ;airport
        IN_CODE

; Gets the cost for the selected icon index
; Entry: a = zone index number
; Exit: de = cost
get_cost_for_zone:
.L6e3a  add     a,a
        ld      e,a
        ld      d,0
        ld      hl,zone_costs
        add     hl,de
        ld      e,(hl)
        inc     hl
        ld      d,(hl)
        ret     

; Spend some money
; Entry: de = money to subtract
; Exit: nc = success
;        c = not enough money
.spend_money
.L6e46  push    hl
        push    bc
        ld      b,0
        ld      hl,(V_money)
        ld      a,(V_money+2)
        ld      c,a
        call    l_sub24
        and     a
        jp      p,L6e5c
        pop     bc
        pop     hl
        scf     
        ret     
.L6e5c  ld      (V_money),hl
        ld      a,c
        ld      (V_money+2),a
        pop     bc
        pop     hl
        or      a
        ret     


        IN_DATA
V_cursor_map_coords:    defw    0       ; VAR $6E67 / 28263 - cursor map coordinates saved by levelmap_xypos_from_cursor (appears written but not read back; possibly vestigial)
V_raw_coords_flag:    defb    0       ; VAR $6E69 / 28265 - raw-coordinates flag: when set, view offset is NOT added (use absolute map coords rather than view-relative)
        IN_CODE

; Gets coordinates on the levelmap - based on ccursor?
.levelmap_xypos_from_cursor
.L6e6a  call    get_cursor_charxy
        ld      (V_cursor_map_coords),bc
        jp      levelmap_xypos

; Load cursor character-cell coordinates into bc
.get_cursor_charxy
.L6e74  ld      bc,(V_pointer_charxy)

; Add view scroll offset to convert cursor char coords to map coords
; (skipped if V_raw_coords_flag raw-coordinates flag is set)
.cursor_to_map_coords
.L6e78  ld      a,(V_raw_coords_flag)
        and     a
        ret     nz
        ld      hl,V_view_topleft    ;
        ld      a,c
        add     a,(hl)
        ld      c,a
        inc     hl
        ld      a,b
        sub     8
        add     a,(hl)
        ld      b,a
        ret     


join_neighbour_cells_raw:                                    ; $6E8A / 28298 - join_up_neighbour_cells bypassing cursor-to-map scroll offset (raw coords)
.L6e8a  ld      a,1
        ld      (V_raw_coords_flag),a
        call    L6e9b
        xor     a
        ld      (V_raw_coords_flag),a
        ret     

; Join up neighbour paths for power cables, road, rail
join_up_neighbour_cells:
.L6e97  ld      bc,(V_pointer_charxy)
.L6e9b  push    hl
        push    de
        push    bc
        call    get_tile_join_type_flag
        ld      (V_tile_conn_flags),a
        call    join_neighbour_cell
        dec     b
        call    join_neighbour_cell
        inc     b
        dec     c
        call    join_neighbour_cell
        inc     c
        inc     c
        call    join_neighbour_cell
        inc     b
        dec     c
        call    join_neighbour_cell
        pop     bc
        pop     de
        pop     hl
        ret     


get_tile_join_type_flag:                                    ; $6EBE / 28350 - Return connection flag (2=rail, 4=road, 8=other) for V_neighbour_tile_to_check
.L6ebe  ld      a,(V_neighbour_tile_to_check)
        cp      7
        jr      z,L6ecc                 ; (7)
        cp      20
        jr      z,L6ecf                 ; (6)
        ld      a,8
        ret     


.L6ecc  ld      a,4
        ret     


.L6ecf  ld      a,2
        ret    


; Variable reused in a few places for convenience
        IN_DATA
V_neighbour_tile_to_check:    defb    $00         ; VAR $6ED2 / 28370 - cell to check for neight
        IN_CODE

;6ed3/28371
        IN_RODATA
D_road_join_offsets:                    ; $6ED3 / 28371 - (type, tile) pairs for road/rail tile adjacency joining
        defb    $00, $01, $00, $02 
        defb    $00, $03, $00, $06 
        defb    $01, $01, $04, $09
        defb    $05, $08, $07, $0A
        IN_CODE
    
; ?? Joins up roads and rail together using the offset table above
; Enters: bc = xy coordinates
join_neighbour_cell:                                    ; $6EE3 / 28387 - Check one neighbouring cell and update its tile to join with adjacent road/rail/power
.L6ee3  push    bc
        call    cursor_to_map_coords           ;Adds something to the incoming coordinates
        call    check_neighbour_tile_match
        jr      nc,L6f0e        ;Coordinate out of range
        call    get_neighbours
        ld      e,d
        ld      d,0
        ld      hl,D_road_join_offsets
        add     hl,de
        ld      a,(V_neighbour_tile_to_check)
        add     a,(hl)
        pop     bc
        push    bc
        push    af
        call    cursor_to_map_coords
        call    levelmap_xypos
        pop     af
        ld      b,a
        ld      a,(hl)
        call    tile_to_flags
        bit     0,a                     ;Power?
        jr      nz,L6f0e                ; (1)
        ld      (hl),b
.L6f0e  pop     bc
        ret     

        IN_DATA
V_tile_conn_flags:    defb        0   ; VAR $6F10 / 28432 - current tile connection flags bitmask (from tile_to_flags, used in path-joining neighbour check)
V_force_tile_match:    defb        0   ; VAR $6F11 / 28433 - force tile-type match flag: when set, get_neighbours bypasses connection flags and compares tile type directly
        IN_CODE

check_neighbour_tile_match:                                    ; $6F12 / 28434 - Check tile at BC against V_neighbour_tile_to_check range [e, e+11]; set C if match
.L6f12  push    bc
        call    levelmap_xypos_with_check
        pop     bc
        ret     nc
        ld      a,(V_neighbour_tile_to_check)
        ld      e,a
        ld      a,(hl)
        cp      e
        jr      c,L6f2a                 ; (10)
        ld      a,e
        add     a,11
        ld      e,a
        ld      a,(hl)
        cp      e
        jr      nc,L6f2a                ; (2)
.L6f28  scf     
        ret     


.L6f2a  ld      a,(V_force_tile_match)
        and     a
        jr      nz,L6f3a                ; (10)
        ld      a,(hl)
        call    tile_to_flags
        ld      hl,V_tile_conn_flags
        and     (hl)
        jr      nz,L6f28                ; (-18)
.L6f3a  or      a
        ret     

; Checks that coordinates up down left right are ??;
; 
; Exit: d = state of surrounding cells
; Cell to bit mapping:
;  0
; 1 2
;  3
get_neighbours:
.L6f3c  push    bc
        ld      d,0
        dec     b
        call    check_neighbour_tile_match
        rl      d
        inc     b
        dec     c
        call    check_neighbour_tile_match
        rl      d
        inc     c
        inc     c
        call    check_neighbour_tile_match
        rl      d
        inc     b
        dec     c
        call    check_neighbour_tile_match
        rl      d
        pop     bc
        ret     

        IN_DATA
V_path_tile_coords:    defw    0       ; VAR $6F5C / 28508 - map coords of last-placed path tile (saved for subsequent join_up_neighbour_cells call)
V_path_tile_type:    defb    0       ; VAR $6F5E / 28510 - tile type to place in path routine (0=plain tile, neighbour_tile+11=crossing variant)
        IN_CODE

place_path_tile_with_join:                                    ; $6F5F / 28511 - Call get_join_type then fall into place_path_tile; alternate entry with join detection
.L6f5f  call    get_cursor_charxy

place_path_tile:                                    ; $6F62 / 28514 - Place path tile at BC if valid map cell and is empty/joinable; charge for bridge if on water
.L6f62  push    de
        push    bc
        call    levelmap_xypos_with_check
        pop     bc
        pop     de
        ret     nc

        ld      a,(hl)
        exx     
        ld      hl,D_joinable_tile_list
        ld      bc,8
        cpir    
        exx     
        jr      z,L6f9a                 ; (35)
        cp      0
        jr      z,L6f7d                 ; (2)
        scf     
        ret     


.L6f7d  ld      a,(V_path_tile_type)
        ld      (hl),a
        and     a
        jr      z,L6f8e                 ; (10)
        exx     
        ld      de,(V_t_1zone_cost_on_water)
        call    spend_money
        exx     
        ret     c


.L6f8e  ld      (V_path_tile_coords),bc
        ld      a,b
        add     a,d
        ld      b,a
        ld      a,c
        add     a,e
        ld      c,a
        jr      place_path_tile                   ; (-56)

.L6f9a  or      a
        ret     

;6f9c/28572
; Suspect this holds a mapping between tile and some feature

; Tile 69 = fire
; Bit 7 = can set on fire?
; bit 3 = needs power?      val 8
; bit 2 = transport - road? val 4
; bit 1 = transport - rail? val 2
        IN_RODATA
D_tile_flags:                        ; $6F9C / 28572
                        ; $6F9C / 28572
        defb    $00, $00, $00, $00, $00, $00, $80, $84
        defb    $84, $84, $84, $84, $84, $84, $84, $84
        defb    $84, $84, $85, $85, $82, $82, $82, $82
        defb    $82, $82, $82, $82, $82, $82, $82, $83
        ;32
        defb    $83, $88, $88, $88, $88, $88, $88, $88
        defb    $88, $88, $88, $88, $89, $89, $87, $87
        defb    $8D, $8D, $8B, $8B, $00, $00, $00, $00
        defb    $80, $80, $00, $18, $D9, $D9, $D9, $D9
        ;64
        defb    $D9, $D9, $D9, $D9, $00, $00, $00, $00 
        defb    $00, $99, $99, $99, $99, $99, $99, $99 
        defb    $99, $B9, $B9, $B9, $B9, $B9, $B9, $05
        defb    $05, $00
        
;addresses for the icon handling
;28662
zone_action_jump_table:
        defw    action_zone_bulldoze
        defw    action_zone_road
        defw    action_zone_power
        defw    action_zone_rail
        defw    action_zone_park        ;$D4, $73
        defw    action_zone_residential ;$FA, $73
        defw    action_zone_commercial  ;$14, $74
        defw    action_zone_industrial  ;$2E, $74
        defw    action_zone_police      ;$48, $74
        defw    action_zone_fire        ;$62, $74, 
        defw    action_zone_stadium     ;$83, $74 
        defw    action_zone_power_station   ;$B4, $74
        defw    action_zone_seaport     ;$F6, $74, 
        defw    action_zone_airport     ;$2B, $75
        IN_CODE


