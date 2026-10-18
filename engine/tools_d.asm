; tools_d: lines 3425-3550 of disassembly/sim_game.asm (engine)
;71ff/29183
D_neighbour_type_index:                 ; $71FF / 29183 - 4-bit neighbour bitmask -> join-type index (0=no join)
        defb    $00, $01, $02, $00, $03, $00, $00, $00
        defb    $04, $00, $00, $00, $00, $00, $00, $00

D_join_tile_triplets:                   ; $720F / 29199 - join-type -> (E, D, fn) triplet for tile placement
        defb    $00, $00, $00, $00, $FF, $0C, $FF, $00 
        defb    $0B, $01, $00, $0B, $00, $01, $0C
        

L721e:
        call    get_cursor_charxy
        ld      a,1
        ld      (V_force_tile_match),a
        call    get_neighbours
        xor     a
        ld      (V_force_tile_match),a
        ld      a,d
        and     a
        ret     z

        ld      e,a
        ld      d,0
        ld      hl,D_neighbour_type_index
        add     hl,de
        ld      a,(hl)
        and     a
        ret     z

        ld      b,a
        add     a,a
        add     a,b
        ld      e,a
        ld      hl,D_join_tile_triplets
        add     hl,de
        ld      e,(hl)
        inc     hl
        ld      d,(hl)
        inc     hl
        ld      a,(hl)
        ld      (SMC_29270+1),a
        ld      a,0
        ld      (V_path_tile_type),a
        call    place_path_tile_with_join
        ret     nc

        ld      a,(V_neighbour_tile_to_check)
SMC_29270:
        add     a,11
        ld      (V_path_tile_type),a
        call    place_path_tile_with_join
        call    join_up_neighbour_cells
        ld      bc,(V_path_tile_coords)
        call    join_neighbour_cells_raw
        jp      draw_map


;726b/29291
D_joinable_tile_list:                   ; $726B / 29291 - tile IDs that accept road/rail/power joins; searched by cpir
        defb    $2c, $2d, $1f, $20
        defb    $12, $13, $57,$58

;7273/29299
unbulldozeable_tiles:
        defb    TILE_WATER, TILE_DIRT, TILE_RADIOACTIVE
        


action_zone_bulldoze:
        call    levelmap_xypos_from_cursor
        ld      a,(hl)
        cp      128                     ;Full zone
        jp      nc,L7308
        cp      81
        jr      c,L7288                 ;1x1 zones
        cp      87
        jp      c,L7367                 ;RIC in the centre

.L7288  ld      hl,D_joinable_tile_list
        ld      bc,8
        cpir    
        jr      z,L72ca                 ; (56)
        ld      hl,unbulldozeable_tiles
        ld      bc,3
        cpir    
        ret     z                       ;No need to bulldoze these
        cp      60                      ;Bulldoze any tile under 60
        jr      c,L72a3                 ; (4)
        cp      81
        jr      c,L72d8                 ; (53)
.L72a3  ld      de,1
        call    spend_money
        ret     c
        call    levelmap_xypos_from_cursor
        ld      (hl),2          ;DIRT
rejoin_bulldozed_neighbours:                                    ; $72AF / 29359 - After bulldozing to DIRT, join_up_neighbour_cells for power/rail/road then redraw
.L72af  ld      a,7
        ld      (V_neighbour_tile_to_check),a
        call    join_up_neighbour_cells
        ld      a,33
        ld      (V_neighbour_tile_to_check),a
        call    join_up_neighbour_cells
        ld      a,20
        ld      (V_neighbour_tile_to_check),a
        call    join_up_neighbour_cells
        jp      draw_map


.L72ca  ld      de,1
        call    spend_money
        ret     c
        call    levelmap_xypos_from_cursor
        ld      (hl),0              ;WATER?
        jr      rejoin_bulldozed_neighbours                   ; (-41)

.L72d8  call    levelmap_xypos_from_cursor
        ld      a,(hl)
        call    tile_to_flags
        bit     4,a
        ret     z
        ld      de,1
        call    spend_money
        ret     c
        ld      (hl),58
        jr      rejoin_bulldozed_neighbours                   ; (-62)

