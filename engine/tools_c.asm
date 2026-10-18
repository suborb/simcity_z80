; tools_c: lines 3163-3409 of disassembly/sim_game.asm (engine)
;7062
D_power_tile_conversions:                        ; $7062 / 28770
                        ; $7062 / 28770
        ;If we place power on one of these
        defb   $07, $08, $14, $15, $38, $39
        ;It converts to...
        defb   $31, $30, $32, $33, $21, $22
;706e 

D_road_tile_conversions:                        ; $706E / 28782
                        ; $706E / 28782
        ;If we place road on one of these
        defb    $14, $15, $21, $22, $38, $39 
        defb    $2E, $2F, $30, $31, $07, $08

D_rail_tile_conversions:                        ; $707A / 28794
                        ; $707A / 28794
        ;If we place rail on one of these
        defb    $07, $08, $21, $22, $38, $39
        defb    $2F, $2E, $33, $32, $14, $15
        

; Place a joinable (road,rail,power) 
place_joinables:
.L7086  ld      a,(V_selected_tool)
        and     a
        jp      z,L709c
        cp      1
        jp      z,place_road
        cp      2
        jp      z,place_power
        cp      3
        jp      z,place_rail

.L709c  or      a
        ret     

place_road:
.L709e  call    levelmap_xypos_from_cursor
.L70a1  ld      a,(hl)
        ld      hl,D_road_tile_conversions
        ld      bc,6
        cpir    
        jp      nz,L709c        ;no match
        ld      de,10
        ld      a,TILE_H_ROAD
place_tile:
.L70b2  ld      (V_neighbour_tile_to_check),a
        call    spend_money
        ret     c
        ld      bc,5
        add     hl,bc       ;hl = 28782 + 6 + 5
        ld      a,(hl)      ;
        push    af
        call    levelmap_xypos_from_cursor
        pop     af
        ld      (hl),a
        call    join_up_neighbour_cells
        call    draw_map
        scf     
        ret     

place_rail:
.L70cc  call    levelmap_xypos_from_cursor
        ld      a,(hl)
        ld      hl,D_rail_tile_conversions
        ld      bc,6
        cpir    
        jp      nz,L709c
        ld      de,20               ;Cost
        ld      a,TILE_H_RAIL
        jp      place_tile

place_power:
.L70e3  call    levelmap_xypos_from_cursor
        ld      a,(hl)
        ld      hl,D_power_tile_conversions
        ld      bc,6
        cpir    
        jp      nz,L709c
        ld      de,5                ;Power
        ld      a,TILE_H_POWER
        jp      place_tile

; Types used for auto-bulldoze
;70fa/28922
D_autobulldoze_free_tiles:              ; $70FA / 28922 - tiles that do not need explicit bulldoze (free to build on)
        defb    TILE_DIRT, TILE_WATER            ;DIRT, WATER
;70fc/28944
D_autobulldoze_tile_types:              ; $70FC / 28924 - tile types auto-bulldozeable; searched by cpir in bulldoze check
        defb    $02, $03, $01, $05, $04, $06
 
V_auto_bulldoze_flag:    defb        0       ; VAR $7102 / 28930 - auto-bulldoze mode flag (2=large zone needs bulldoze check, 0=small tool; written but not subsequently read - possibly vestigial)

check_bulldoze_then_place:                                    ; $7103 / 28931 - From cursor position: if tile empty place zone, else if auto-bulldoze enabled bulldoze first
.L7103  call    levelmap_xypos_from_cursor
        ld      a,(hl)      ;Is it empty?
        cp      0
        jp      z,L7113
        ld      a,(V_auto_bulldoze)
        and     a
        jp      z,check_can_place_zone

.L7113  ld      a,2
        ld      (V_auto_bulldoze_flag),a
        ld      a,(V_selected_tool)
        and     a
        jp      z,L7171
        cp      4
        jp      nc,L7129
        ld      a,0
        ld      (V_auto_bulldoze_flag),a

.L7129  call    get_zone_size
        push    de
        call    levelmap_xypos_from_cursor
        pop     bc
        ld      a,c
        ld      (auto_bulldoze_nun_columns+1),a

; Think this is doing the auto bulldoze
.L7135  push    hl
auto_bulldoze_nun_columns:
        ld      c,0         ;SMC

.L7138  ld      a,(hl)
        push    hl      ;Address of top left of zone
        push    bc      ;Size of zone
        ld      hl,D_autobulldoze_tile_types
        ld      bc,7
        cpir    
        pop     bc
        pop     hl
        jp      z,L714b ;If we haven't one of those types then we must bulldoze
        pop     hl
        scf     
        ret     
.L714b  push    hl
        push    bc
        ld      hl,D_autobulldoze_free_tiles
        ld      bc,2
        cpir    
        pop     bc
        pop     hl
        jp      z,L7165     ;If we have sea/water, no need to autobulldoze
        ld      de,1
        call    spend_money
        jp      c,L7165
        ld      (hl),TILE_DIRT     ;DIRT
.L7165  inc     hl
        dec     c
        jp      nz,L7138
        pop     hl
        ld      de,96
        add     hl,de
        djnz    L7135                   ; (-60)
.L7171  or      a
        ret     

; Check whether we can place a zone
; Exit: nc = can place
;        c = can't place
check_can_place_zone:
.L7173  call    get_zone_size
        push    de
        call    levelmap_xypos_from_cursor
        pop     bc
        ld      a,c
        ld      (SMC_29056+1),a
.L717f  push    hl
SMC_29056:
        ld      c,0
.L7182  ld      a,(hl)
        cp      2                   ;DIRT
        jr      z,L718a                 ; (3)
        pop     hl
        scf     
        ret     
.L718a  inc     hl
        dec     c
        jr      nz,L7182                ; (-12)
        pop     hl
        ld      de,96
        add     hl,de
        djnz    L717f                   ; (-22)
        or      a
        ret     

; Place a zone:
; Entry:    ix = tiles to place
place_zone:                                 ; $7197 / 29079
.L7197  
        call    get_zone_size
        push    de
        call    levelmap_xypos_from_cursor
        pop     bc      ;c = size x, b = sizey

; Entry: hl = map position
;        bc = yx size to place
place_zone_direct:
.L719f  ld      a,c
        ld      (SMC_29092+1),a
.L71a3  push    hl
SMC_29092:
        ld      c,0
.L71a6  ld      a,(ix+0)
        ld      (hl),a
        inc     hl
        inc     ix
        dec     c
        jr      nz,L71a6                ; (-10)
        pop     hl
        ld      de,96
        add     hl,de
        djnz    L71a3                   ; (-20)
        ret   


V_t_1zone_cost_on_land:    defw    0   ; VAR $71B8 / 29112 - : Cost of a placing a single zone
V_t_1zone_cost_on_water:      defw    0   ; VAR $71BA / 29114 - : Cost on land
;71b8/29112


; Place a 1x1 zone
; Entry: hl = price on land
;        de = price on water
;         a = tile to place
;71bc
place_zone_1x1:
L71bc:
        ld      (V_t_1zone_cost_on_land),hl
        ld      (V_t_1zone_cost_on_water),de
        ld      (V_neighbour_tile_to_check),a
        call    levelmap_xypos_from_cursor
        ld      a,(hl)
        cp      TILE_WATER
        jr      z,L721e                 ; It's water..
        cp      TILE_DIRT
        IFDEF PORTABLE
        jp      nz,play_place_sound     ; It's not dirt (platform hook: out of jr range)
        ELSE
        jr      nz,play_place_sound                ; It's not dirt
        ENDIF
        ld      de,(V_t_1zone_cost_on_land)    ; Can we spend it?
        call    spend_money
        ret     c
        ld      a,(V_neighbour_tile_to_check)               ; Yes we cam, place it
        ld      (hl),a
        call    join_up_neighbour_cells
        jp      draw_map

