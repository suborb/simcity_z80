; tools_e: lines 3569-3869 of disassembly/sim_game.asm (engine)

; Zone bulldoze costs
D_bulldoze_costs:                        ; $7301 / 29441
                        ; $7301 / 29441
        defb    0
        defb    1
        defb    4
        defb    9
        defb    16
        defb    25
        defb    36


.L7308  call    wait_if_demolish_pending
        ret     nz

        push    hl
        pop     ix
        call    find_left_edge_of_zone
        ld      de,-96
find_zone_top_row:                                    ; $7315 / 29461 - Walk IX upward (-96) until bit 5 set (top row of zone); locates zone header tile
.L7315  bit     5,(ix+0)
        jr      nz,L731f                ; (4)
        add     ix,de
        jr      find_zone_top_row                   ; (-10)

.L731f  ld      a,(ix+0)
        and     7
        ld      c,a
        ld      b,0
        ld      hl,D_bulldoze_costs
        add     hl,de
        ld      e,(hl)
        ld      d,0
        call    spend_money
        ret     c

        ld      a,(ix+0)
        and     7

bulldoze_zone_rows:                                    ; $7337 / 29495 - Fill zone W*H tiles with rubble row by row via IX, then animate bulldoze sequence
.L7337  ld      (SMC_bulldoze_zone_width+1),a
        ld      b,a
; Clear the whole zone and step through the bulldoze sequence
.L733b  push    ix
SMC_bulldoze_zone_width:
        ld      c,0             ;SMC
.L733f  ld      (ix+0),70
        inc     ix
        dec     c
        jr      nz,L733f                ; (-9)
        pop     ix
        ld      de,96
        add     ix,de
        djnz    L733b                   ; (-22)
        call    draw_map
        call    bulldoze_degrade_tile
        call    draw_map
        call    bulldoze_degrade_tile
        call    draw_map
        call    bulldoze_degrade_tile
        call    draw_map
        ret     


.L7367  call    wait_if_demolish_pending
        ret     nz
        ld      de,9            ;3x3 RIC zone = $9 to bulldoze
        call    spend_money
        ret     c
        ld      bc,-97
        add     hl,bc
        push    hl
        pop     ix
        ld      a,3
        jr      bulldoze_zone_rows                   ; (-70)

D29565:
        defb    $46, $47, $48
        defb    $47, $48, $02

; Degrade any bulldozed tiles through the sequence
bulldoze_degrade_tile:
.L7383  call    get_cursor_charxy
        ld      a,b
        sub     6
        ld      b,a
        ld      c,0
        call    levelmap_xypos
        push    hl
        pop     ix
        ld      de,1152
.L7395  ld      a,(ix+0)
        ld      hl,D29565
        ld      bc,3
        cpir    
        jr      nz,L73aa                ; (8)
        ld      bc,2
        add     hl,bc
        ld      a,(hl)
        ld      (ix+0),a
.L73aa  inc     ix
        dec     de
        ld      a,d
        or      e
        jr      nz,L7395                ; (-28)
        ret     

;73b2
action_zone_road:
        ld      hl,10   ;price on land
        ld      de,50   ;price on water
        ld      a,7     ;tile (road)
        jp      place_zone_1x1

;73bd
action_zone_rail:
        ld      hl,20   ;on land
        ld      de,100  ;on water
        ld      a,20    ;rail
        jp      place_zone_1x1

; 73c8
action_zone_power:
        ld      hl,5    ;on land
        ld      de,25   ;on water
        ld      a,33    ;power
        jp      place_zone_1x1

        defb    0               ; padding

;73d4
action_zone_park:
        call    levelmap_xypos_from_cursor
        cp      2           ;BUG? This seems to be the x position?
        jp      z,play_place_sound
        ld      de,10
        call    spend_money
        ret     c

        ld      c,TILE_PARK
        call    get_random_number
        and     7
        jr      nz,L73ed                ; (1)
        inc     c
.L73ed  ld      (hl),c
        jp      draw_map

default_residential_tiles:
        defb    $49, $4a, $4b
        defb    $50, $54, $4c
        defb    $4f, $4e, $4d

;73fa
action_zone_residential:
        ld      de,100
        call    spend_money
        ret     c
        ld      ix,default_residential_tiles
        call    place_zone
        jp      draw_map


;29707/740b
default_commercial_tiles:
        defb    $49, $4a, $4b
        defb    $50, $55, $4c
        defb    $4f, $4e, $4d

action_zone_commercial:
        ld      de,100
        call    spend_money
        ret     c
        ld      ix,default_commercial_tiles
        call    place_zone
        jp      draw_map

default_industrial_tiles:
        defb    $49, $4a, $4b
        defb    $50, $56, $4c
        defb    $4f, $4e, $4d

;742e
action_zone_industrial:
        ld      de,100
        call    spend_money
        ret     c
        ld      ix,default_industrial_tiles
        call    place_zone
        jp      draw_map

default_police_tiles:
        defb    $a3, $c0, $c0
        defb    $83, $c0, $c3
        defb    $83, $c0, $c6

action_zone_police:
        ld      de,500
        call    spend_money
        ret     c
        ld      ix,default_police_tiles
        call    place_zone
        jp      draw_map

default_fire_tiles:
        defb    $a3, $c1, $c1
        defb    $83, $c1, $c4
        defb    $83, $c1, $c7

action_zone_fire:
        ld      de,500
        call    spend_money
        ret     c
        ld      ix,default_fire_tiles
        call    place_zone
        jp      draw_map

default_stadium_tiles:
        defb    $a4, $c4, $c4, $c0
        defb    $84, $c5, $c0, $c0
        defb    $84, $c5, $c4, $c0
        defb    $84, $c6, $c0, $c0

;7483
action_zone_stadium:
        ld      de,3000
        call    spend_money
        ret     c
        ld      ix,default_stadium_tiles
        call    place_zone
        jp      draw_map

default_coal_power_station_tile:
        defb    $b4, $c6, $c4, $c0
        defb    $84, $c7, $c0, $c0
        defb    $84, $c7, $c4, $c0
        defb    $84, $c8, $c0, $c0

default_nuclear_power_station_tiles:
        defb    $b4, $c8, $c4, $c0
        defb    $84, $c9, $c0, $c0
        defb    $84, $c9, $c4, $c0
        defb    $84, $ca, $c0, $c0


action_zone_power_station:
        ld      de,3000         ;Do we actually have 3000?
        ld      hl,(V_money)
        and     a
        sbc     hl,de
        ret     c
        IFDEF PORTABLE
        call    ui_choose_power_plant   ;sets V_power_type_chosen (0 = cancel, 1 = nuclear, else coal)
        ELSE
        ld      ix,menu_power
        call    open_menu
        ENDIF
        ld      de,5000
        ld      ix,default_nuclear_power_station_tiles
        ld      a,(V_power_type_chosen)
        and     a
        ret     z
        cp      1           ;Nuclear
        jr      z,L74dc                 ; (7)
        ld      de,3000
        ld      ix,default_coal_power_station_tile
.L74dc  call    spend_money
        ret     c
        call    place_zone
        jp      draw_map


default_seaport_tiles:
        defb    $a4, $ca, $c4, $c0
        defb    $84, $cb, $c0, $c0
        defb    $84, $cb, $c4, $c0
        defb    $84, $cc, $c0, $c0


action_zone_seaport:
        ld      de,5000
        call    spend_money
        ret     c
        ld      ix,default_seaport_tiles
        call    place_zone
        jp      draw_map


default_airport_tiles:
        defb    $a6, $cc, $c4, $c0, $c0, $c0
        defb    $86, $cd, $c2, $c0, $c0, $c0
        defb    $86, $ce, $c0, $c0, $c0, $c0
        defb    $86, $ce, $c6, $c0, $c0, $c0
        defb    $86, $cf, $c4, $c0, $c0, $c0
        defb    $86, $d0, $c2, $c0, $c0, $c0
    
action_zone_airport:
        ld      de,10000
        call    spend_money
        ret     c
        ld      ix,default_airport_tiles
        call    place_zone
        jp      draw_map


