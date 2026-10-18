; zx_ui5: lines 9517-11021 of disassembly/sim_game.asm (zx)

toggle_minimap_section_flash:                                    ; $9B60 / 39776 - Flash attribute at D_minimap_section_coords[V_minimap_section] by XOR 128
.L9b60  ld      a,(V_minimap_section)
        add     a,a
        ld      c,a
        ld      b,0
        ld      hl,D_minimap_section_coords
        add     hl,bc
        ld      b,(hl)
        inc     hl
        ld      c,(hl)
        call    cxytoattr
        ld      a,(hl)
        xor     128             ;Toggle flash?
        ld      (hl),a
        ret     

; Highlight for the minimap map selector text
highlight_minimap_label:                                    ; $9B76 / 39798 - Highlight current minimap label row (V_minimap_selection_index+9) by XOR-ing 8 attributes
.L9b76  ld      a,(V_minimap_selection_index)
        add     a,9
        ld      b,a
        ld      c,0
        call    cxytoattr
        ld      b,8
.L9b83  ld      a,(hl)
        xor     %01000110       ;Switch between bright while and dull blue ink
        ld      (hl),a
        inc     l
        djnz    L9b83                   ; (-7)
        ret     


handle_minimap_key_input:                                    ; $9B8B / 39819 - Process Q/A/digit keys to change V_minimap_selection_index or V_minimap_section
.L9b8b  ld      a,(V_minimap_frame_counter)
        and     3
        jr      nz,L9ba3                ; (17)
        ld      hl,V_minimap_selection_index
        ld      a,(keystore+2)
        and     1       ;'Q'
        jr      z,L9bb7                 ; (27)
        ld      a,(keystore+1)
        and     1       ;'A'
        jr      z,L9bbd                 ; (26)

.L9ba3  ld      a,(keystore+7)
        and     2       ;'SYM'
        ret     nz
        call    getkeyval           ;Selection between 0 and 9 into 39979
        ret     c
        sub     49
        ret     c
        cp      9
        ret     nc
        ld      (V_minimap_section),a
        ret     


.L9bb7  ld      a,(hl)
        dec     a
        and     7
        ld      (hl),a
        ret     


.L9bbd  ld      a,(hl)
        inc     a
        and     7
        ld      (hl),a
        ret     


render_road_tile_traffic:                                    ; $9BC3 / 39875 - Render road tile at current screen position with traffic overlay
.L9bc3  ld      l,a
        ld      a,(V_current_zone_width_to_print)
        and     a
        jr      nz,L9be8                ; (30)
        call    update_road_tile_for_traffic
        ld      h,0
        add     hl,hl
        add     hl,hl
        add     hl,hl
        ld      de,udgs + 536
        add     hl,de

SMC_39894:          
blit_road_tile_rows:                                    ; $9BD6 / 39894 - Blit 4 pixel rows from UDG data into road tile screen address (SMC_39894); inner road rendering loop
.L9bd6  ld      de,16392            ;SMC, screen address of road tile
        inc     hl
        call    blit_road_pixel_row
        inc     d
        call    blit_road_pixel_row
        inc     d
        call    blit_road_pixel_row
        inc     d
        jr      blit_road_pixel_row                   ; (17)

.L9be8  ld      hl,V_current_zone_width_to_print
        dec     (hl)
        ld      hl,(V_left_tile_index)
        add     hl,hl
        add     hl,hl
        add     hl,hl
        ld      de,udgs + 1288
        add     hl,de
        jr      blit_road_tile_rows                   ; (-34)


        defb    0               ; padding


; This does the traffic effect for roads?
blit_road_pixel_row:                                    ; $9BF9 / 39929 - Pack 4 pixel bits from UDG data into road tile screen byte, merging with existing pixels
.L9bf9  ld      a,(hl)
        and     128
        ld      c,a
        ld      a,(hl)
        and     32
        rlca    
        or      c
        ld      c,a
        ld      a,(hl)
        and     8
        rlca    
        rlca    
        or      c
        ld      c,a
        ld      a,(hl)
        and     2
        rlca    
        rlca    
        rlca    
        or      c
        ld      c,a
        ld      b,15
        ld      a,(V_road_tile_attr)
        and     a
        jr      z,L9c24                 ; (10)
        ld      b,240
        rrc     c
        rrc     c
        rrc     c
        rrc     c
.L9c24  ld      a,(de)
        and     b
        or      c
        ld      (de),a
        inc     hl
        inc     hl
        ret     


;9c2b/39979
V_minimap_section:    defb        0       ; VAR $9C2B / 39979 - selected minimap quadrant
        defb    0, 0            ; padding ($9C2C-$9C2D / 39980-39981, unreferenced)

V_minimap_scan_xy:        defw    0       ; VAR $9C2E / 39982 -

V_road_tile_attr:        defb    0       ; VAR $9C30 / 39984 -
V_minimap_xy:    defw    0       ; VAR $9C31 / 39985 - xypos in minimap being printed


; Address within the levelmap that 0-8 keys correspond to

;39987
D_minimap_offsets:                        ; $9C33 / 39987
                        ; $9C33 / 39987
        defw    levelmap
        defw    levelmap+24
        defw    levelmap+48
        defw    levelmap+2304
        defw    levelmap+2304+24
        defw    levelmap+2304+48
        defw    levelmap+4608
        defw    levelmap+4608+24
        defw    levelmap+4608+48
;9c45/40005
        ;The yx coordinates of those address?
        defb    0,0
        defb    0,24
        defb    0,48
        defb    24,0
        defb    24,24
        defb    24,48
        defb    48,0
        defb    48,24
        defb    48,48


start_minimap_render:                                    ; $9C57 / 40023 - Initialise minimap render state (screen ptr, coords) then scan 48x48 cells
.L9c57  ld      hl,16392
        ld      (SMC_39894+1),hl
        xor     a
        ld      (V_road_tile_attr),a
        ld      a,16
        ld      (V_road_tile_variant),a
        ld      a,(V_minimap_section)
        add     a,a
        ld      c,a
        ld      b,0

.L9c6d  ld      hl,D_minimap_offsets
        add     hl,bc
        ld      e,(hl)
        inc     hl
        ld      d,(hl)
        ld      bc,17       ;Step onto the xy coordinats
        add     hl,bc
        ld      b,(hl)
        inc     hl
        ld      c,(hl)
        ld      (V_minimap_scan_xy),bc
        ld      a,b
        ld      (V_minimap_xy+1),a
        ex      de,hl
        ld      b,48

.L9c86  ld      de,(SMC_39894+1)
        push    de
        ld      a,(V_minimap_scan_xy)
        ld      (V_minimap_xy),a
        ld      c,48

.L9c93  ld      a,(V_current_zone_width_to_print)
        and     a
        jr      nz,L9c9f                ; (6)
        ld      a,(hl)
        cp      128
        call    nc,L655b

.L9c9f  ld      (V_map_render_ptr),hl
        exx     
        call    render_road_tile_traffic                   ;Mark traffic on the map
        ld      c,33                    ;White paper, blue ink
        call    set_tile_attribute                   ;Set attribute
        call    check_if_minimaps_should_be_displayed
        ld      hl,V_road_tile_attr
        ld      a,(hl)
        xor     1
        ld      (hl),a
        jr      nz,L9cbe                ; (7)
        ld      hl,(SMC_39894+1)
        inc     hl
        ld      (SMC_39894+1),hl

.L9cbe  ld      hl,(V_left_tile_index)
        inc     hl
        ld      (V_left_tile_index),hl
        ld      hl,V_minimap_xy
        inc     (hl)
        exx     
        inc     hl
        dec     c
        jr      nz,L9c93                ; (-59)
        pop     de
        ex      de,hl
        call    drow
        call    drow
        call    drow
        call    drow
        ld      (SMC_39894+1),hl
        ex      de,hl
        ld      de,48
        add     hl,de
        xor     a
        ld      (V_current_zone_width_to_print),a
        ld      a,(V_minimap_xy+1)
        inc     a
        ld      (V_minimap_xy+1),a
        push    hl
        push    bc
        call    twiddlekeys
        pop     bc
        pop     hl
        ret     nz
        djnz    L9c86                   ; (-115)
        ret     


; Attributes related to minimap?
D_minimap_attr_intensity:               ; $9CFA / 40186 - attribute intensity scale for minimap overlay (0..127, 8 levels)
        defb    $00, $49, $52, $5b, $64, $6d, $76, $7f

; Print the attribute intensity for a zone
; Eg: Pollution, traffic, Crime, pollution, police, fire
do_minimap_attr_intensity:
.L9d02  and     a
        ret     z
        ld      c,a
        ld      b,0
        ld      hl,D_minimap_attr_intensity
        add     hl,bc
        ld      c,(hl)
set_tile_attribute:                                    ; $9D0C / 40204 - Write attribute byte C to attr address derived from current SMC_39894+1 screen pointer
.L9d0c  ld      hl,(SMC_39894+1)
        ld      a,h
        rrca    
        rrca    
        rrca    
        and     3
        or      88
        ld      h,a
        ld      (hl),c
        ret     


set_road_tile_attributes:                                    ; $9D1A / 40218 - Write road tile attributes (from V_road_tile_attr) to 4 attribute rows at current screen position
.L9d1a  ld      d,15
        ld      b,160
        ld      c,80
        ld      a,(V_road_tile_attr)
        and     a
        jr      z,L9d2c                 ; (6)
        ld      d,240
        ld      b,10
        ld      c,5

.L9d2c  ld      hl,(SMC_39894+1)
        ld      a,(hl)
        and     d
        or      b
        ld      (hl),a
        inc     h
        ld      a,(hl)
        and     d
        or      c
        ld      (hl),a
        inc     h
        ld      a,(hl)
        and     d
        or      b
        ld      (hl),a
        inc     h
        ld      a,(hl)
        and     d
        or      c
        ld      (hl),a
        ret     

V_minimap_selection_index:  defb    $06     ; VAR $9D43 / 40259 - which minimap is selected


check_if_minimaps_should_be_displayed:      ; $9D44 / 40260
.L9d44
        ld      a,(V_minimap_selection_index)
        cp      0
        ret     z
        ld      a,1
        ld      (V_simulation_disabled),a
        ld      hl,(V_minimap_start)
        push    hl
        ld      hl,minimap_return
        push    hl
        ld      a,(V_minimap_selection_index)
        cp      1           ;Pollution
        jr      z,do_minimap_pollution                 ; (122)
        cp      2           ;Police
        jp      z,do_minimap_police
        cp      3           ;Fire
        jp      z,do_minimap_fire
        cp      4           ;Traffic
        jr      z,do_minimap_traffic                 ; (103)
        cp      5           ;Power
        jr      z,do_minimap_power                 ; (71)
        cp      6           ;Transport
        jr      z,do_minimap_transport                 ; (80)
                            ;Crime?
        jr      L9d7f                   ; (9)
minimap_return:
        pop     hl
        ld      (V_minimap_start),hl
        xor     a
        ld      (V_simulation_disabled),a
        ret     

; Think this one is crime...
.L9d7f  ld      hl,(V_map_render_ptr)
        ld      a,(hl)
        call    tile_to_flags
        bit     4,a
        ret     z
        ld      bc,(V_minimap_xy)
        call    manhattan_dist_to_centroid
        cp      32
        jr      c,L9d96                 ; (2)
        ld      a,31
.L9d96  ld      b,a
        ld      a,32
        sub     b
        jr      nc,L9d9d                ; (1)
        xor     a
.L9d9d  srl     a
        sub     15
        neg     
        ld      e,a
        ld      bc,(V_minimap_xy)
        call    get_police_minimap_value
        ld      d,a
        ld      a,e
        sub     d
        jr      nc,L9db1                ; (1)
        xor     a
.L9db1  srl     a
        call    do_minimap_attr_intensity
        ret     


.do_minimap_power  
        ld      bc,(V_minimap_xy)
        call    get_power_map_addr
        ld      a,(hl)
        and     e
        ret     z
        jp      set_road_tile_attributes

.do_minimap_transport                       ; $9DC4 / 40388
.L9dc4
        ld      hl,(V_map_render_ptr)
        ld      a,(hl)
        call    tile_to_flags
        and     6
        ret     z
        ld      a,5
        jp      set_road_tile_attributes


.do_minimap_traffic  
        ld      hl,minimaps+3456        ;46800
        jr      L9ddb                   ; (3)

.do_minimap_pollution  
        ld      hl,minimaps+1152
.L9ddb  ld      (V_minimap_start),hl
        ld      bc,(V_minimap_xy)
        call    minimap_xypos_50
        srl     a
        srl     a
        srl     a
        srl     a
        srl     a
        jp      do_minimap_attr_intensity

.do_minimap_fire  
        ld      hl,minimaps
        jr      L9dfa                   ; (3)

.do_minimap_police  
        ld      hl,minimaps+576
.L9dfa  ld      (V_minimap_start),hl
        ld      bc,(V_minimap_xy)
        call    minimap_xypos_25
        srl     a
        jp      do_minimap_attr_intensity

; Save?
;9e09
action_save:
        call    menu_enter_filename
        ld      bc,$100c
        ld      (V_input_xy),bc
        ld      hl,V_tapeheader            
        ld      (V_input_target_ptr),hl  ;destination for string
        call    input_string
        call    save_and_wait_for_keypress
        ld      hl,V_money
        ld      de,V_tape_money
        ld      bc,7
        ldir    
        ld      hl,SMC_cityname
        ld      de,D_43332
        ld      bc,12
        ldir    
        di      
        ld      ix,V_tapeheader
        ld      de,31
        ld      a,255
        scf     
        call    restart_rom
        ld      b,30
        call    pause5000
        ld      ix,levelmap
        ld      de,9216
        ld      a,255
        scf     
        call    restart_rom
        xor     a
        out     (254),a
        ei      
        ret     

action_load:
        call    menu_enter_filename
        ld      bc,$100C
        ld      (V_input_xy),bc
        ld      hl,V_load_filename
        ld      (V_input_target_ptr),hl
        call    input_string
        di      
        call    cls_white        ;why?!?!?
        call    cls_black
        call    prt_ctrl
        defb        T_BOX,0,0,32,24
        defb        T_SETXY,9,11
        defm        "SEARCHING"
        defb        T_END
L9e89:
        ld      ix,V_tapeheader
        ld      de,31   ;12 char filename, 7b money, 12b something else
        ld      a,255
        scf     
        call    load
        jr      nc,L9f0c                ; (116)
        call    print_tape_found_header
        ld      hl,V_load_filename
        ld      b,12

.L9ea0  ld      a,(hl)
        cp      32
        jr      nz,L9eaa                ; (5)
        inc     hl
        djnz    L9ea0                   ; (-8)
        jr      load_city_from_tape                   ; (20)

.L9eaa  ld      hl,V_tapeheader
        ld      ix,V_load_filename
        ld      b,12

.L9eb3  ld      a,(hl)
        cp      (ix+0)
        jr      nz,L9e89                ; (-48)
        inc     ix
        inc     hl
        djnz    L9eb3                   ; (-11)

load_city_from_tape:                                    ; $9EBE / 40638 - Print LOADING, call tape load routine; on success copy money/name into live vars and redraw
.L9ebe  call    prt_ctrl
        defb         T_SETXY,13,12
        defm        "LOADING"
        defb        T_END
        ld      ix,levelmap
        ld      de,9216
        ld      a,255
        scf     
        call    load
        jr      nc,L9efc                ; (33)
        ld      hl,V_tape_money
        ld      de,V_money
        ld      bc,7
        ldir    
        ld      hl,D_43332
        ld      de,SMC_cityname
        ld      bc,12
        ldir    
        ei      
        xor     a
        out     (254),a
        call    cls_white
        call    ingame_scrdraw
        ret     


.L9efc  ei      
        xor     a
        out     (254),a
        call    cls_white
        call    ingame_scrdraw
        call    menu_tape_loading_error
        jp      start_city

.L9f0c  ei      
        xor     a
        out     (254),a
        call    cls_white
        call    ingame_scrdraw
        call    menu_tape_loading_error
        ret     


print_tape_found_header:                                    ; $9F1A / 40730 - Print 'FOUND :- ' then the 12-char tape header name at textpos
.L9f1a  call    prt_ctrl
        defb        T_SETXY,11,9
        defm        "FOUND :- "
        defb        T_END

        ld      hl,V_tapeheader
        ld      b,12
.L9f2f  push    hl
        push    bc
        ld      a,(hl)
        cp      32
        call    nc,prchar
        call    incprpos
        pop     bc
        pop     hl
        inc     hl
        djnz    L9f2f                   ; (-16)
        ret     

.V_power_type_chosen        defb        0        ; VAR $9F40 / 40768 - which power station has been chosen

menu_power:                                 ; $9F41 / 40769
.L40769
        defb        8,0
        defm        "          SELECT TYP"
        defb        'E'+128
        defb        3
        defb        0,160,0,160,0,160,0,160
        defb        2
        defw        action_power_nuclear
        defm        "  NUCLEAR POWER STATION $500"
        defb        '0'+128
        defb        0,160
        defb        2
        defw        action_power_coal       ;202,159
        defm        "    COAL POWER STATION $300"
        defb        '0'+128
        defb        0,160,0,160,0,160
        defb        3
        defb        2
        defw        action_power_none
        defm        "             NON"
        defb        'E'+128
        defb        4

action_power_none:
        ld      a,0
        ld      (V_power_type_chosen),a
        ret 

action_power_nuclear:                       ; $9FC3 / 40899
.L9fc3
        ld      a,1
        ld      (V_power_type_chosen),a
        ret     
action_power_coal:                          ; $9FCA / 40906
.L9fca
        ld      a,2
        ld      (V_power_type_chosen),a
        ret


;9fd0
.menu_are_you_sure  
    call    print_routine
        defb        8,0
        defm        "         ARE YOU SURE "
        defb        '?'+128
        defb        3
        defb        0,160,0,160,0,160,0,160
        defb        2
        defw        clear_carry
        defm        "           NO THANK"
        defb        'S'+128
        defb        0,160
        defb        2
        defw        set_carry
        defm        "          YES  PLEAS"
        defb        'E'+128
        defb        4

clear_carry:
        or        a
        ret
set_carry:
        scf
        ret

.La02b
menu_system:                                ; $A02B / 41003
        defb        8,0
        defm        "            SYSTE"
        defb        'M'+128
        defb        3
        defb        2
        defw        menu_about
        defm        "ABOUT SIM CIT"
        defb        'Y'+128
        defb        2
        defw        action_start_new_city      ;a0b7
        defm        "START NEW CIT"
        defb        'Y'+128
        defb        2
        defw        use_old_landscape       ;220,165
        defm        "USE OLD LANDSCAP"
        defb        'E'+128
        defb        3
        defb        2
        defw        menu_load_city               ;243,161
        defm        "LOAD CIT"
        defb        'Y'+128
        defb        2
        defw        menu_save_city
        defm        "SAVE CIT"
        defb        'Y'+128
        defb        3
        defb        2
        defw        action_exit_simcity     ;177,160           ;a0b1
        defm        "EXIT SIMCIT"
        defb        'Y'+128
        defb        0,160,0,160
        defb        3
        defb        2
        defw        just_a_ret
        defm        "EXIT MEN"
        defb        'U'+128
        defb        4

action_exit_simcity:
        call    menu_are_you_sure
        ret     nc
        jr      action_start_new_city                   ; (0)

action_start_new_city:
.La0b7  call    menu_are_you_sure

.La0ba  ret     nc

        ld      hl,(V_random_seed)
        ld      (V_InitialSeed),hl

start_city:
.La0c1  call    menu_difficulty
        jp      create_landscape


menu_about:
La0c7:
        call    print_routine
        defb    8,0
        defm    "  SIMCITY THE CITY SIMULATO"
        defb    'R' + 128,0
        defm    "   (C) 1989  MAXIS SOFTWAR"
        defb    'E' + 128, 0
        defm    "  CONCEPT & DESIGN  W.Wrigh"
        defb    't' + 128, 3, 0
        defm    "  FOR  PROBE SOFTARE LIMITE"
        defb    'D'+128, 0
La140:
        defm    "SPECTRUM PROGRAMMING  A.R.Lil"
        defb    'l'+128, 0
La15f:
        defm    "SPECTRUM GRAPHICS A.Lill & J."
        defb    'L'+128, 3, 0
La17f:
        defm    "FOR MORE INFO :- INFOGRAME"
        defb    'S' + 128, 0
        defm    "   84 Rue du 1er Mars 1943"
        defb    ','+128, 0
La1b7:
        defm    "   69625 Villeurbanne Cedex"
        defb    ',' + 128, 0
        defm    "   France"
        defb    '.' + 128
        defb    3,2
        defw    just_a_ret
        defm    "              O"
        defb    'K' + 128
        defb    4


menu_load_city:         ;La1f3:
La1f3:
        call    print_routine
        defb    8,0
        defm    "         LOADING MEN"
        defb    'U'+128
        defb    3
        defb    $00, $a0, $00, $a0, $00, $a0, $00, $a0
        defb    2
        defw    action_load
        defm    "        LOAD FROM TAP"
        defb    'E' + 128
        defb    $00, $a0, $00, $a0, $00, $a0, $00, $a0, $00, $a0
        defb    3
        defb    2
        defw    just_a_ret
        defm    "EXIT MEN"
        defb    'U' + 128
        defb    4


; Save menu...
menu_save_city:
La247:
        call    print_routine
        defb    8,0
        defm    "          SAVING MEN"
        defb    'U' + 128
        defb    3
        defb    $00, $a0, $00, $a0, $00, $a0, $00, $a0
        defb    2
        defw    action_save ;9e09
        defm    "         SAVE TO TAP"
        defb    'E' + 128
        defb    $00, $a0, $00, $a0, $00, $a0, $00, $a0, $00, $a0
        defb    3
        defb    2
        defw    just_a_ret
        defm    "EXIT MEN"
        defb    'U' + 128
        defb    4

    

menu_enter_filename:                        ; $A29A / 41626
.La29a  call    print_routine
        defb    $0c, 00
        defm    "        TYPE FILE NAM"
        defb    'E' + 128
        defb    0
.La2b6
        defm    "       THEN PRESS ENTE"
        defb    'R' + 128
        defb    $00, $a0
        defb    $00
        defm    "FILENAME :"
        defb    ' ' + 128
        defb    4

.menu_tape_loading_error
;a2dc
        call    print_routine
        defb    $0e, $00
        defm    "      TAPE LOADING ERRO"
        defb    'R'+ 128
        defb    2
        defw    just_a_ret
        defb    $a0
        defb    4


save_and_wait_for_keypress:
.La2fe  call    print_start_tape_prompt
.La301  ld      a,127
.La303  in      a,($fe)
.La305  rra     
        ret     nc
.La307  jr      La301                  ; (-8)



print_start_tape_prompt:                                    ; $A309 / 41737 - Print 'START TAPE AND PRESS SPACE' prompt at current textpos
.La309  call    print_routine
        defb    $0e
        defb    0
        defm    "  START TAPE AND PRESS SPAC"
        defb    'E' + 128
        defb    4

;a32b
V_auto_bulldoze:    defb    1   ; VAR $A32B / 41771 - auto bulldoze
V_auto_budget:      defb    0   ; VAR $A32C / 41772 - auto budget
V_sound_enabled:    defb    1   ; VAR $A32D / 41773 - sound enabled
V_demolish_wait:    defb    1   ; VAR $A32E / 41774 - auto demolish wait


;a32f
menu_options:
        defb    $08
        defb    0
        defm    "            OPTION"
        defb    'S' + 128
        defb    $03, $01
        defw    V_auto_bulldoze    ;a32b
        defm    "AUTO-BULLDOZ"
        defb    'E' + 128
        defb    $00, $a0
        defb    $1
        defw    V_auto_budget    ;a32c
        defm    "AUTO-BUDGE"
        defb    'T'+128
        defb    $00, $a0
        defb    $01
        defw    V_sound_enabled    ;a32d
        defm    "SOUN"
        defb    'D' + 128
        defb    $00, $a0
        defb    $01
        defw    V_demolish_wait    ;a32e
        defm    "ZONE DEMOLISH WAI"
        defb    'T' + 128
        defb    $00, $a0
        defb    $02
        defw    menu_simulation_speed    ;a3ac
        defm    "SIMULATION SPEE"
        defb    'D' + 128
        defb    $00, $a0
        defb    $3
        defb    $2
        defw    just_a_ret
        defm    "EXIT MEN"
        defb    'U' + 128
        defb    4

V_simulation_speed: defb    1   ; VAR $A3AB / 41899 - (41899/a3ab) - simulation speed

;a3ac
menu_simulation_speed:
        call    print_routine
        defb    $08, $00
        defm    "     SET SIMULATION SPEE"
        defb    'D' + 128
        defb    $03
        defb    $00, $a0
        defb    $02
        defw    action_speed_fast    ;a421
menu_t_fast:
La3d0:
        defm    "  FAS"
        defb    'T' + 128
        defb    $00, $a0
        defb    $02
        defw    action_speed_normal    ;a428
menu_t_normal:
La3db:
        defm    "  NORMA"
        defb    'L' + 128
        defb    $00, $a0
        defb    $02
        defw    action_speed_slow    ;a420
menu_t_slow:
La3e8:
        defm    "  SLO"
        defb    'W' + 128
        defb    $00, $a0
        defb    $02
        defw    action_speed_paused    ;a436
menu_t_paused:
        defm    "  PAUSE"
        defb    'D' + 128
        defb    $00, $a0, $00, $a0
        defb    $03
        defb    $02
        defw    just_a_ret
        defm    "EXIT MEN"
        defb    'U' + 128
        defb    4

    ;a40d

set_speed:
.La40d  ld      (V_simulation_speed),a       ;Simulation speed
        ; Clear out any '*' marking previous setting
        ; and set the '*' next to the selected one
        ld      a,32
        ld      (menu_t_fast),a
.La415  ld      (menu_t_normal),a
        ld      (menu_t_slow),a
        ld      (menu_t_paused),a
        ld      (hl),'*'
        ret     

action_speed_fast:
La421:
        ld      a,0
        ld      hl,menu_t_fast        ;Points to fast
        jr      set_speed                   ; (-27)

action_speed_normal:
La428:
        ld      a,1
        ld      hl,menu_t_normal        ;Points to normal
        jr      set_speed                   ; (-34)

action_speed_slow:
La42f:
        ld      a,2
        ld      hl,menu_t_slow        ;Points to slow
        jr      set_speed                   ; (-41)

action_speed_paused:
La436:
        ld      a,3
        ld      hl,menu_t_paused        ;Points to paused
        jr      set_speed                   ; (-48)

;a43d

V_disaster_reset:   defb    0       ; VAR $A43D / 42045 - a43d/42045 - used when resetting disasters

;a43e
menu_disaster:
        defb    $08, $00
        defm    "           DISASTER"
        defb    'S' + 128
        defb    $03
        defb    $02
        defw    action_set_disaster    ;a4ba
La458:
        defm    "FIR"
        defb    'E' + 128
        defb    $02
        defw    action_set_disaster    ;a4ba
        defm    "FLOO"
        defb    'D' + 128
        defb    $02
        defw    action_set_disaster    ;a4ba
La467:
        defm    "EARTHQUAK"
        defb    'E' + 128
        defb    $03
        defb    $02
        defw     action_set_disaster   ;a4ba
La475:
        defm    "AIR CRAS"
        defb    'H' + 128
        defb    $02
        defw    action_set_disaster    ;a4ba
La481:
        defm    "TORNAD"
        defb    'O' + 128
        defb    $02
        defw    action_set_disaster    ;a4ba
        defm    "NUCLEAR MELTDOW"
        defb    'N' + 128
        defb    $03
        defb    $01
        defw    V_disaster_reset    ;a43d
        defm    "DISABLE AL"
        defb    'L' + 128
        defb    $00, $a0
        defb    $03
        defb    $02
        defw    just_a_ret
        defm    "EXIT MEN"
        defb    'U' + 128
        defb    $04


action_set_disaster:
;a4ba
        ld      a,(V_menu_selection)
.La4bd  inc     a
        ld      (V_disaster_option),a
        ret     

;a4c2
menu_windows:
        defb    $08, $00
        defm    "            WINDOW"
        defb    'S' + 128
        defb    $03
        defb    $02
        defw    action_set_show_maps    ;a512
        defm    "MAP"
        defb    'S' + 128
        defb    $00, $a0
        defb    $02
        defw    show_budget    ;9194
        defm    "BUDGE"
        defb    'T' + 128
        defb    $00, $a0
        defb    $02
        defw    show_evaluation    ;95b8
La4ef:
        defm    "EVALUATIO"
        defb    'N' + 128
        defb    $00, $a0, $00, $a0, $00, $a0, $00, $a0, $00, $a0
        defb    $03
        defb    $02
        defw    just_a_ret
        defm    "EXIT MEN"
        defb    'U' + 128
        defb    $04

;a511
V_show_mini_maps:   defb    0       ; VAR $A511 / 42257 - set to show mini maps

action_set_show_maps:                       ; $A512 / 42258
.La512
        ld      a,1
        ld      (V_show_mini_maps),a
        ret     

; A518
V_difficulty:   defb    0       ; VAR $A518 / 42264 - (42264) - difficulty level

menu_difficulty:
.La519  call    print_routine
menu_difficulty_text:                       ; $A51C / 42268
.L42268
        defb        8,0
        defm        "    SELECT DIFFICULTY LEVE"
        defb        'L'+128
        defb        3,0,160
        defb        2
        defw        action_difficulty
La53f:
        defm        "         1 - EAS"
        defb        'Y'+128
        defb        0,160
        defb        2
        defw        action_difficulty
La555:
        defm        "         2 - MEDIU"
        defb        'M'+128
        defb        0,160
        defb        2
        defw        action_difficulty
La56d:
        defm        "         3 - DIFFICUL"
        defb        'T'+128
        defb        0,160,0,160,0,160,0,160
        defb        3,2
        defw        action_input_city_name
; 42383
        defm        "      INPUT NEW CITY NAM"
        defb        'E'+128
        defb        4

.La5a9
action_difficulty:                          ; $A5A9 / 42409
        ld      a,(V_menu_selection)
        ld      (V_difficulty),a
        ret     


action_input_city_name:
.La5b0  ld      hl,$0501
.La5b3  ld      (V_input_xy),hl
        ld      hl,SMC_cityname
        ld      (V_input_target_ptr),hl
        ld      a,57
        ld      (SMC_42936+1),a
        ld      a,185
        ld      (SMC_42944+1),a
        call    input_string
        ld      a,71
        ld      (SMC_42936+1),a
        ld      a,199
        ld      (SMC_42944+1),a
        call    toggle_menu_row_highlight
        call    ingame_txt
        jp      run_menu


use_old_landscape:
La5dc:
        ld      hl,(V_InitialSeed)
        ld      (SMC_42523),hl
        call    print_routine
        defb        8,0
        defm        "       USE OLD LANDSCAP"
        defb        'E'+128
        defb        3,0
        defm        " CURRENT LANDSCAPE GENE "
;42521
        defb        6,0
SMC_42523:
        defb        0,0,0
        defb        0,160,3,0,160,0,160
        defb        2
        defw        input_new_gene      ;114,166        ;variable pickup?
        defm        "        INPUT NEW GEN"
        defb        'E'+128
        defb        0,160
        defb        2           ;a0c1
        defw        start_city
        defm        "  START CITY WITH THIS GEN"
        defb        'E'+128
        defb        0,160,0,160,0,160
        defb        3
        defb        2
        defw        just_a_ret
        defm        "EXIT MEN"
        defb        'U'+128
        defb        4

input_new_gene:
La672:
        ld      hl,$0b19
        ld      (V_input_xy),hl
        ld      hl,V_InitialSeed
        ld      (V_input_target_ptr),hl
        ld      hl,$0501
        ld      (V_input_isnumber),hl
        call    input_entry
        ld      d,1
        jr      nc,La68c                ; (1)
        dec     d

.La68c  push    de
        ld      hl,$0b19
        ld      (textxy),hl
        ld      hl,(V_InitialSeed)
        call    set_textpos_from_textxy
        call    toggle_menu_row_highlight
        pop     de
        ld      a,d
        ld      (V_menu_selection),a
        jp      L6950

text_generating_landscape:
        defb     $0d, $00
        defm    "       CREATING LANDSCAP"
        defb    'E' + 128
        defb    $00, $a0
        defb    $00
        defm    "          PLEASE WAI"
        defb    'T' + 128
        defb    4

V_input_xy:    defw    0       ; VAR $A6D8 / 42712 - coordinates for input
V_input_target_ptr:    defw    0       ; VAR $A6DA / 42714 - destination for input?

V_input_cursor_pos:    defb    0       ; VAR $A6DC / 42716 - current length of input?

;a6dd/42717
V_input_isnumber:   defb    0       ; VAR $A6DD / 42717 - we want a number
V_input_maxlen:     defb    0       ; VAR $A6DE / 42718 - maximum length of the string

V_input_buffer:            defs    18      ; VAR $A6DF / 42719 - input buffer


; Enter a percentage
.La6f1  ld      hl,$0301
        ld      (V_input_isnumber),hl
        jr      input_entry                   ; (6)

; Input string
input_string:
.La6f9  ld      hl,$0b00
        ld      (V_input_isnumber),hl      ;Set some flags for input

  
input_entry:
.La6ff  xor     a
        ld      (V_input_cursor_pos),a
.La703  ld      a,(V_input_isnumber)
        and     a
        call    nz,La7d4        ;If numeric clear the buffer
.La70a  call    rdkeys
        call    getkeyval
        jr      c,La757                 ; (69)
        cp      8
        jp      z,La836
        ld      b,a
        ld      hl,(42735)
        ld      a,h
        or      l
        jr      z,La725                 ; (6)
        dec     hl
        ld      (42735),hl
        jr      input_set_zero_and_redraw                   ; (56)

.La725  ld      hl,La762
        push    hl
        ld      a,(keystore)
        and     1       ;'SHIFT'
        jr      nz,La742                ; (18)
        ld      hl,V_input_cursor_pos
        ld      a,b
        cp      56
        jr      z,La799                 ; (97)
        ld      a,b
        cp      53
        jr      z,input_cursor_left                 ; (86)
        ld      a,b
        cp      48
        jr      z,La77d                 ; (59)

.La742  ld      a,(V_input_isnumber)
        and     a
        jr      z,La751                 ; (9)
        ld      a,b
        cp      48
        jr      c,La756                 ; (9)
        cp      58
        jr      nc,La756                ; (5)

.La751  ld      a,b
        cp      32
        jr      nc,La76d                ; (23)

.La756  pop     hl

.La757  ld      hl,0
        ld      (42735),hl

input_set_zero_and_redraw:                                    ; $A75D / 42845 - Set input value to 0, store in buffer, redraw input field; used for budget input reset
.La75d  call    redraw_input_field
        jr      La70a                   ; (-88)
.La762  ld      hl,1000
        ld      (42735),hl
        call    redraw_input_field
        jr      La70a                   ; (-99)

.La76d  ld      a,(V_input_cursor_pos)
        ld      e,a
        ld      d,0
        ld      hl,(V_input_target_ptr)
        add     hl,de
        ld      (hl),b
        ld      hl,V_input_cursor_pos
        jr      La799                   ; (28)

.La77d  call    input_clear_cursor_char
        ld      hl,V_input_cursor_pos
        call    input_cursor_left

input_clear_cursor_char:                                    ; $A786 / 42886 - Write space to V_input_buffer[V_input_cursor_pos] (erase char at cursor position)
.La786  ld      a,(V_input_cursor_pos)
        ld      e,a
        ld      d,0
        ld      hl,(V_input_target_ptr)
        add     hl,de
        ld      (hl),32
        ret     


input_cursor_left:                                    ; $A793 / 42899 - Decrement input cursor position (HL points to counter); stops at 0
.La793  ld      a,(hl)
        sub     1
        ret     c
        ld      (hl),a
        ret     


.La799  ld      a,(V_input_maxlen)
        ld      c,a
        ld      a,(hl)
        inc     a
        cp      c
        ret     z
        ld      (hl),a
        ret     


redraw_input_field:                                    ; $A7A3 / 42915 - Redraw the numeric input field at V_input_xy, highlighting cursor with inverse colour
.La7a3  ld      bc,(V_input_xy)
        call    xypos
        ld      (textpos),hl
        ld      hl,(V_input_target_ptr)
        ld      a,(V_input_maxlen)
        ld      b,a
        ld      c,0

.La7b6  push    bc
        push    hl
SMC_42936:
        ld      e,71                ;SMC - 42937
        ld      a,(V_input_cursor_pos)
        cp      c
        jr      nz,La7c2                ; (2)
SMC_42944:
        ld      e,199               ;SMC - 42945

.La7c2  ld      a,e
        ld      (textcol),a
        ld      a,(hl)
        call    prchar
        call    incprpos
        pop     hl
        pop     bc
        inc     hl
        inc     c
        djnz    La7b6                   ; (-29)
        ret     


.La7d4  ld      hl,V_input_buffer
        ld      de,V_input_buffer+1
        ld      bc,11
        ld      (hl),32
        ldir    
        call    input_value_to_digits
        ld      hl,V_input_buffer
        ld      (V_input_target_ptr),hl
        ret     

V_input_target_saved:    defw    0       ; VAR $A7EB / 42987 -

input_value_to_digits:                                    ; $A7ED / 42989 - Convert 16-bit value at V_input_target_ptr pointer to 5 decimal ASCII digits in V_input_buffer
.La7ed  ld      hl,(V_input_target_ptr)
        ld      (V_input_target_saved),hl
        ld      iy,V_input_buffer
        ld      a,(hl)
        inc     hl
        ld      h,(hl)
        ld      l,a
        ld      a,(V_input_maxlen)
        ld      c,a
        ld      b,5
        ld      de,-10000
        call    extract_decimal_digit
        ld      de,-1000
        call    extract_decimal_digit
        ld      de,-100
        call    extract_decimal_digit
        ld      de,-10
        call    extract_decimal_digit
        ld      a,l
        call    store_digit_and_advance
        ret     


extract_decimal_digit:                                    ; $A81E / 43038 - Extract one decimal digit from HL using DE (power of 10); store as ASCII in (IY+)
.La81e  ld      a,c
        cp      b
        jr      c,La834                 ; (18)
        xor     a
.La823  inc     a
        add     hl,de
        jr      c,La823                 ; (-4)
        sbc     hl,de
        dec     a
store_digit_and_advance:                                    ; $A82A / 43050 - Convert A to ASCII digit, store in V_digit_char_buf and (IY+), advance IY; tail of extract_decimal_digit
.La82a  add     a,48
        ld      (V_digit_char_buf),a
        ld      (iy+0),a
        inc     iy
.La834  dec     b
        ret     


.La836  ld      a,(V_input_isnumber)
        and     a
        scf     
        ret     z
        call    input_buffer_to_hl
        ret     c
        ex      de,hl
        ld      hl,(V_input_target_saved)
        ld      (hl),e
        inc     hl
        ld      (hl),d
        or      a
        ret     


; Checks if the value in e is a number
; Entry: e = character
; Exit:  nc = number
;         c = not number
isnumber:
.La849  ld      a,e
        cp      58
        ccf     
        ret     c
        cp      48
        ret     c
        sub     48
        ret     


input_buffer_to_hl:                                    ; $A854 / 43092 - Convert V_input_buffer ASCII digit string to binary number in HL; return NC on success
.La854  ld      iy,V_input_buffer
        ld      hl,0
.La85b  xor     a
        add     hl,hl
        rla     
        ld      d,h
        ld      e,l
        add     hl,hl
        rla     
        add     hl,hl
        rla     
        add     hl,de
        rla     
        and     a
        jr      nz,La882                ; (25)
        ld      e,(iy+0)
        call    isnumber
        ccf     
        ret     nc
        ld      e,a
        ld      d,0
        add     hl,de
        ret     c
        inc     iy
        ld      e,(iy+0)
        call    isnumber
        ccf     
        ret     nc
        jr      La85b                   ; (-39)

.La882  scf     
        ret     



; Some 2x2 graphics here, stored by line - masked - transport characters?
;43140
transport_sprites:
        BINARY      "assets/transport.spr"
  

V_load_filename:    defs    12,32          ; VAR $A924 / 43300 - filename we want to load

; Tape header buffer for loading/saving
; 
; 12 bytes filename
;
;
; 12 bytes city name at D_43332
V_tapeheader:                                        ; VAR $A930 / 43312
        defs    12             ;VAR 43312/a930
V_tape_money:    defs    8               ; VAR $A93C / 43324
   

D_43332:    defm        "HERESVILLE  "          ; $A944 / 43332 - default city name


; End of tape header

