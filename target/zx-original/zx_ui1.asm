; zx_ui1: lines 374-1357 of disassembly/sim_game.asm (zx)
; Pointer sprites and mask

.D_pointer_sprite       defb        0,120,112,120,92,8,0,0        ; $5CEC / 23788 - 8-byte UDG pixel data for cursor arrow
.D_pointer_mask         defb        7,3,7,3,1,35,247,255          ; $5CF4 / 23796 - 8-byte UDG mask for cursor arrow

.V_pointerxy        defw        $0135        ; VAR $5CFC / 23804 - pointer xypos

; Print the pointer

.prpointer
        ld        bc,(V_pointerxy)
        srl        b
        srl        b
        srl        b
        srl        c
        call    xypos
        ld      (V_pointer_xy_prev),hl
        ld      ix,V_pointer_underlay
        ld      iy,D_pointer_mask
        ld      de,D_pointer_sprite
        ld      b,8
.L5d1d  ld      a,(hl)
        ld      (ix+0),a
        ld      a,(hl)
        and     (iy+0)
        ld      c,a
        ld      a,(de)
        or      c
        ld      (hl),a
        inc     de
        inc     ix
        inc     iy
        call    drow
        djnz    L5d1d                   ; (-22)
        ret     

.V_pointer_underlay        defs        8        ; VAR $5D34 / 23860 - used to hold what was under pointer
.V_pointer_xy_prev        defw        0        ; VAR $5D3C / 23868 - old pointer posn

.blankpointer  
        ld      hl,(V_pointer_xy_prev)
        ld      de,V_pointer_underlay
        ld      b,8
.L5d46  ld      a,(de)
        ld      (hl),a
        inc     de
        call    drow
        djnz    L5d46                   ; (-8)
        ret     

.V_zone_cursor_size        defw        $0101        ; VAR $5D4F / 23887 - zone size related
.V_map_cursor_cell        defw        0        ; VAR $5D51 / 23889 - map character-cell coordinates of cursor (b=row, c=col, derived from pixel pointer)
.V_cursor_validity        defw        0        ; VAR $5D53 / 23891 - byte 0 = raw cursor Y pixel; byte 1 = cursor in-map validity flag (1=valid, 0=outside map)

validate_cursor_position:               ; $5D55 / 23381 - Check pointer is in map, convert pixel coords to map char-cell; sets V_cursor_validity (0=out, 1=valid)
.L5d55  xor     a
        ld      (V_cursor_validity),a
        ld      (V_cursor_validity+1),a
        ld      bc,(V_pointerxy)
        ld      a,b
        cp      64
        ret     c
        ld      (V_cursor_validity),a
        ld      a,b
        sub     64
        srl     a
        srl     a
        srl     a
        ld      b,a
        ld      a,c
        srl     a
        ld      c,a
        ld      (V_map_cursor_cell),bc
        ld      a,b
        add     a,8
        ld      b,a
        ld      hl,(V_zone_cursor_size)
        ld      a,b
        add     a,h
        cp      25
        ret     nc
        ld      a,c
        add     a,l
        cp      33
        ret     nc
        ld      a,1
        ld      (V_cursor_validity+1),a
draw_cursor_xor:                                    ; $5D8F / 23951 - XOR-invert pixels under cursor (zone-size rows at xypos); cursor-already-valid path
.L5d8f  call    xypos
        ld      bc,(V_zone_cursor_size)
        sla     b
        sla     b
        sla     b
        ld      a,c
        ld      (SMC_23970+1),a
.L5da0  push    bc
        push    hl
SMC_23970:
        ld      b,2
.L5da4  ld      a,(hl)
        xor     255
        ld      (hl),a
        inc     l
        djnz    L5da4                   ; (-7)
        pop     hl
        pop     bc
        call    drow
        djnz    L5da0                   ; (-18)
        ret     

; Prints the menu icons
; Calls the prmenu_udg to handle the gubbins

.pricon  
        push    bc
        push    af
        call    prmenu_udg
        pop     af
        pop     bc
        inc     a
        inc     c
        push    bc
        push    af
        call    prmenu_udg
        pop     af
        pop     bc
        dec     c
        inc     b
        inc     a
        push    bc
        push    af
        call    prmenu_udg
        pop     af
        pop     bc
        inc     a
        inc     c
        jp      prmenu_udg

; Does the menu udgs

.doicons  
        ld      bc,$0102
        ld      d,14
        ld      e,0
.L5dd9  push    bc
        push    de
        ld      a,e
        call    pricon
        pop     de
        pop     bc
        ld      a,e
        add     a,4
        ld      e,a
        inc     c
        inc     c
        dec     d
        jr      nz,L5dd9                ; (-17)
        ret     


; Part of the printroutine
; We enter with the text stored at the return address

        defc        T_SETCOL        = 251
        defc        T_NUM           = 252        ;print number following (8 bit)
        defc        T_BOX           = 253        ;draw line/box?
        defc        T_END           = 254
        defc        T_SETXY         = 255

replace_with_direct_prchar_call:
        call    prchar
        ret

        
.prt_ctrl  
        pop     hl
.L5df0  ld      a,(hl)
        cp      T_END
        jp      z,endctrl
        cp      T_SETCOL                        ;251
        jr      z,set_txtcol                 ; set textcol
        cp      T_SETXY
        jr      z,ctrl_setxy                 ; (124)
        cp      T_BOX
        jp      z,ctrl_line
        cp      252
        jr      z,ctrl_prnum                 ; (30)
        push    hl
        call    replace_with_direct_prchar_call       ; TODO: Optimise this away
        call    incprpos                        ;inc print posn
        pop     hl

.nxtctrl  inc     hl
        jr      L5df0                   ; (-34)

.incprpos  
        ld      hl,(textpos)
        inc     hl
        ld      (textpos),hl
        ld      hl,textxy
        inc     (hl)
        ret     


.set_txtcol
        inc     hl
        ld      a,(hl)
        ld      (textcol),a
        jr      nxtctrl                   ; (-22)

.ctrl_prnum  
        inc     hl
        ld      a,(hl)
        push    hl
        ld      l,a
        ld      h,0
        call    prhund
        pop     hl
        jr      nxtctrl                   ; (-34)
        ld      (textxy),bc

set_textpos_from_textxy:                                    ; $5E35 / 24117 - Move textpos to screen address for current textxy; preamble before number printing
.L5e35  push    hl
        ld      bc,(textxy)
        call    xypos
        ld      (textpos),hl
        pop     hl

; Print a number

.prtthou  
        ld      de,-10000
        call    prdigit
.prthou  
        ld      de,-1000
        call    prdigit
.prhund 
        ld      de,-100
        call    prdigit
        ld      de,-10
        call    prdigit
        ld      a,l
        call    print_digit_char        ;
        ret     

.prdigit 
        xor     a
.L5e5f  inc     a
        add     hl,de
        jr      c,L5e5f                 ; (-4)
        sbc     hl,de
        dec     a
print_digit_char:                                    ; $5E66 / 24166 - Convert digit in A to ASCII, store in V_digit_char_buf and print at current textpos
.L5e66  add     a,48
        ld      (V_digit_char_buf),a
        push    hl
        call    replace_with_direct_prchar_call
        ld      hl,(textpos)
        inc     hl
        ld      (textpos),hl
        pop     hl
        ret     


endctrl:                                    ; $5E78 / 24184
.L5e78
        inc     hl
        jp      (hl)

.ctrl_setxy  
        inc     hl
        ld      b,(hl)
        inc     hl
        ld      c,(hl)
        push    hl
        call    xypos
        ld      (textpos),hl
        pop     hl
        jr      nxtctrl                   ; (-121)

; Draw a udg line..

.ctrl_line  
        inc     hl
        push    hl
        call    L5e97
        pop     hl
        ld      de,3
        add     hl,de
        jp      nxtctrl

.V_text_col_width        defw        $1020                ; VAR $5E95 / 24213 - holds textxy


.L5e97  ld      b,(hl)
        inc     hl
        ld      c,(hl)
        inc     hl
        ld      e,(hl)
        inc     hl
        ld      d,(hl)
        ld      (textxy),bc
        ld      (V_text_col_width),de
        ld      a,(textxy)
        ld      (SMC_24334+1),a
        ld      a,56
        ld      b,57
        ld      c,58
        call    print_zone_tile_row
        ld      a,(V_text_col_width+1)
        sub     2
        ld      b,a

.L5ebb  push    bc
        ld      a,63
        ld      b,32
        ld      c,59
        call    print_zone_tile_row
        pop     bc
        djnz    L5ebb                   ; (-13)
        ld      a,62
        ld      b,61
        ld      c,60
        call    print_zone_tile_row
        ret     

.L24274
        defb        $01

; Print one horizontal row of zone UDGs
; Entry: a = left-edge UDG, b = middle UDG, c = right-edge UDG
.print_zone_tile_row                        ; $5ED3 / 24275
.L5ed3
        ld      (SMC_24296+1),a
        ld      a,b
        ld      (SMC_24312+1),a
        ld      a,c
        ld      (SMC_24326+1),a
        ld      bc,(textxy)
        call    xypos
        ld      (textpos),hl
SMC_24296:
        ld      a,64
        call    prudg
        ld      a,(V_text_col_width)
        sub     2
        ld      b,a

.L5ef3  push    bc
        ld      hl,textpos
        inc     (hl)
SMC_24312:
        ld      a,65
        cp      32
        call    nz,prudg
        pop     bc
        djnz    L5ef3                   ; (-15)
        ld      hl,textpos
        inc     (hl)
SMC_24326:
        ld      a,66
        call    prudg
        ld      hl,textxy
.SMC_24334                                ;FIXME
        ld      (hl),0
        inc     hl
        inc     (hl)
        ret     

; Print the main game text and box

.ingame_scrdraw  
        call    prt_ctrl
        defb        T_SETCOL,7
        defb        T_SETXY,0,0
        defm        "SYSTEM OPTIONS DISASTERS WINDOWS"
        defb        T_SETXY,2,0
        defb        '+'
        defb        T_END
        call        prt_ctrl
        defb        T_SETCOL,56
        defb        T_BOX,3,0,32,5
        defb        T_SETCOL,57
        defb        T_END
        call        ingame_txt
        call    doicons
        call    update_cursor_and_greyout
        call    L6305
        call    print_date
        call    print_money
        ret     

.ingame_txt  
        call    prt_ctrl
        defb        T_SETCOL,57
        defb        T_SETXY,5,1
SMC_cityname:
.D_24424                                                                                                    ; $5F68 / 24424 - VAR        (12) - townname
        defm        "HERESVILLE  "
        defb        T_SETXY,5,17
        defm        "FUNDS $"
        defb        T_END
        ret

; 5f80
.print_money  
        ld      bc,$0518
        ld      hl,V_money
        call    prt24bit
        ret     

; 5f8a
text_months:
        defm    "JA"
        defb    'N'+128
        defm    "FE"
        defb    'B'+128
        defm    "MA"
        defb    'R'+128
        defm    "AP"
        defb    'R'+128
        defm    "MA"
        defb    'Y'+128
        defm    "JU"
        defb    'N'+128
        defm    "JU"
        defb    'L'+128
        defm    "AU"
        defb    'G'+128
        defm    "SE"
        defb    'P'+128
        defm    "OC"
        defb    'T'+128
        defm    "NO"
        defb    'V'+128
        defm    "DE"
        defb    'C'+128

; Print the date on screen
; Routine $5fae
print_date:                                 ; $5FAE / 24494
.L5fae
        ld      a,(V_month)
        ld      hl,text_months
        call    get_word_from_table
        ld      bc,$0417
        ld      a,3
        call    print_string
        ld      hl,(V_year)
        call    prthou
        ret     

;5fc6 24518
; Text table
text_table:
        defm    "BULLDOZE $"
        defb    '1' + 128
        defm    "ROAD $1"
        defb    '0' + 128
        defm    "POWER LINES $"
        defb    '5' + 128
        defm    "RAILROAD $2"
        defb    '0' + 128
        defm    "PARK $1"
        defb    '0' + 128
        defm    "RESIDENTIAL $10"
        defb    '0' + 128
        defm    "COMMERCIAL $10"
        defb    '0' + 128
        defm    "INDUSTRIAL $10"
        defb    '0' + 128
        defm    "POLICE STATION $50"
        defb    '0' + 128
        defm    "FIRE STATION $50"
        defb    '0' + 128
        defm    "STADIUM $300"
        defb    '0' + 128
        defm    "POWER STATION $500"
        defb    '0' + 128
        defm    "SEAPORT $500"
        defb    '0' + 128
        defm    "AIRPORT $1000"
        defb    '0' + 128


L6088:
; Code 14 = levels
        defm    "EAS"
        defb    'Y' + 128
        defm    "MEDIU"
        defb    'M' + 128
        defm    "HAR"
        defb    'D' + 128

; Code 17 = city size

        defm    "VILLAG"
        defb    'E' + 128
        defm    "TOW"
        defb    'N' + 128
        defm    "CIT"
        defb    'Y' + 128
        defm    "CAPITA"
        defb    'L' + 128
        defm    "METROPOLI"
        defb    'S' + 128
        defm    "MEGALOPOLI"
        defb    'S' + 128

; Code 23 - 60c1
        defb    ' ' + 128

; Code 24
.alert_msg_demand_zones                     ; $60C2 / 24770
.L60c2
        defm    "MORE RESIDENTIAL ZONES NEEDE"      ;24
        defb    'D' + 128
        defm    "MORE COMMERCIAL ZONES NEEDE"
        defb    'D' + 128
        defm    "MORE INDUSTRIAL ZONES NEEDE"       ;26
        defb    'D' + 128
.alert_msg_demand_infra                     ; $6117 / 24855
.L6117
        defm    "NEED BIGGER ROAD NETWOR"           ;28
        defb    'K' + 128
        defm    "NEED LARGER RAIL SYSTE"            ;30
        defb    'M' + 128
        defm    "NEED A POWER PLAN"                 ;32
        defb    'T' + 128
.alert_msg_demand_special                   ; $6158 / 24920
.L6158
        defm    "THE PEOPLE WANT A STADIU"          ;34
        defb    'M'+128
        defm    "INDUSTRY NEEDS A SEA POR"           ;36
        defb    'T' + 128
        defm    "COMMERCE NEEDS AN AIRPOR"
        defb    'T' + 128
        defm    "PEOPLE DEMAND FIRE DEP"
        defb    'T' + 128
.alert_msg_demand_services                  ; $61BA / 25018
.L61ba
        defm    "PEOPLE DEMAND POLICE DEP"
        defb    'T' + 128
        defm    "CITIZENS UPSET,TAXES TOO HIG"
        defb    'H' + 128
        defm    "TRANSPORT SYSTEM FALLING APAR"
        defb    'T' + 128
        defm    "FIRE DEPT NEEDS FUND"
        defb    'S' + 128
        defm    "THE POLICE NEED FUND"
        defb    'S' + 128
        defm    "ZONES NEED POWE"
        defb    'R' + 128
.alert_msg_disasters                        ; $6248 / 25160
.L6248
        defm    "BROWNOUTS DETECTE"
        defb    'D' + 128
        defm    "NUCLEAR MELTDOW"
        defb    'N' + 128
        defm    "TOO MUCH POLLUTIO"
        defb    'N' + 128
        defm    "CRIME TOO HIG"
        defb    'H' + 128
        defm    "TRAFFIC JAMS ARE BA"
        defb    'D' + 128
        defm    "FIRES HAVE BEEN DETECTE"
        defb    'D' + 128
        defm    "COASTAL FLOODING DETECTE"
        defb    'D' + 128
        defm    "MAJOR EARTHQUAKE DETECTE"
        defb    'D' + 128
        defm    "AIR CRASH !!"
        defb    '!' + 128
        defm    "TORNADO DETECTE"
        defb    'D' + 128

; $6305 - look up current tool name from text_table and print it
.print_selected_tool_name
L6305:
        ld      hl,text_table  ;table above
        ld      a,(V_selected_tool)
        call    get_word_from_table
        ld      bc,$0401
        ld      a,19
        call    print_string
        ret     

; Get the word from the table
; Entry: hl = table
;         a = word number to get
.get_word_from_table  
        and     a
        ret     z
        ld      e,0
.L631b  ld      d,a
.L631c  bit     7,(hl)
        jr      z,L6327                 ; (7)
        inc     e
        ld      a,d
        cp      e
        jr      nz,L6327                ; (2)
.L6325  inc     hl
        ret     
.L6327  inc     hl
        jr      L631c                   ; (-14)



; 632a
; Print a string
; Entry: hl = string to print
;        bc = xy coordinates
;         a = maximum width
print_string:
.L632a  push    af
        push    hl
        call    xypos
        ld      (textpos),hl
        pop     hl
        pop     af
        ld      c,a
.L6335  ld      a,(hl)
        and     127
        push    hl
        push    bc
        call    prchar
        call    incprpos
        pop     bc
        pop     hl
.L6342  bit     7,(hl)
        jr      nz,L634a                ; (4)
        inc     hl
        dec     c
        jr      L6335                   ; (-21)
.L634a  ld      a,c
        and     a
        ret     z
        ret     m
        ld      b,a
.L634f  push    bc
        ld      a,32
        call    prchar
        call    incprpos
        pop     bc
        djnz    L634f                   ; (-12)
        ret     

check_cursor_keys:
.L635c  ld      a,(keystore+5)
        and     2           ;'O'
        call    z,pointer_left
        ld      a,(keystore+5)
        and     1           ;'P'
        call    z,pointer_right
        ld      a,(keystore+2)
        and     1           ;'Q'
        call    z,pointer_up
        ld      a,(keystore+1)
        and     1           ;'A'
        call    z,pointer_down
        ret     

pointer_right:
.L637d  ld      hl,V_pointerxy
        ld      a,(hl)
        add     a,1
        cp      63
        jp      nc,draw_map
        ld      (hl),a
        ret     

pointer_left:
.L638a  ld      hl,V_pointerxy
        ld      a,(hl)
        sub     1
        cp      255
        jp      z,draw_map
        ld      (hl),a
        ret     

pointer_up:
.L6397  ld      hl,V_pointerxy+1
        ld      a,(hl)
        cp      64
        jr      c,L63a6                 ; (7)
        ld      a,(keystore+4)
        and     16              ;'6'
        jr      z,L63ae                 ; (8)
.L63a6  ld      a,(hl)
        sub     2
        cp      250
        ret     nc
        ld      (hl),a
        ret     
.L63ae  ld      a,(hl)
        sub     2
        cp      64
        jp      c,draw_map
        ld      (hl),a
        ret     

pointer_down:
.L63b8  ld      hl,V_pointerxy+1
        ld      a,(hl)
        add     a,2
        cp      185
        jr      nc,L63c4                ; (2)
        ld      (hl),a
        ret     
.L63c4  ld      (hl),184
        jp      draw_map

V_pointer_charxy:   defw        0   ; VAR $63C9 / 25545 - pointer coords reduced to chars
        defb    0, 0            ; padding

handle_space_action:                                    ; $63CD / 25549 - SPACE action: convert pointer to char-cell, disable sim, dispatch menu/tool/place, re-enable sim
.L63cd  ld      a,(keystore+7)
        and     1       ;'SPACE'
        ret     nz

        ld      bc,(V_pointerxy)
        srl     b
        srl     b
        srl     b
        srl     c
        ld      (V_pointer_charxy),bc
        call    try_select_build_tool                   ;See if an icon is selected?
        ld      a,1
        ld      (V_simulation_disabled),a
        call    do_view_change
        call    handle_menus
        call    place_tool_at_cursor
        xor     a
        ld      (V_simulation_disabled),a
        ret     

wait_for_space_key_release:
.L63f9  ld      a,(keystore+7)
        and     1           ;'SPACE'
        jr      z,wait_for_space_key_release                 ; (-7)
        ret     


; Handle menu selection
;
handle_menus:
.L6401  ld      a,(V_pointer_charxy+1)
        and     a                   ;Only valid on first road
        ret     nz
        call    wait_for_space_key_release
        call    select_menu_from_pointer
        jr      wait_for_space_key_release                   ; (-21)

select_menu_from_pointer:                                    ; $640E / 25614 - Determine which top-bar menu to open from pointer X; load IX = menu struct
.L640e  ld      a,(V_pointerxy)
        ld      ix,menu_system
        cp      14
        jp      c,open_menu
        ld      ix,menu_options
        cp      30
        jp      c,open_menu
        ld      ix,menu_disaster
        cp      48
        jp      c,open_menu
        ld      ix,menu_windows     ;42178
        jp      open_menu

V_road_tile_variant:    defb    0       ; VAR $6433 / 25651 - road tile variant selector (bit 4 of current tile's flags; picks between two medium-traffic graphics)

draw_scrolling_map_row:                                    ; $6434 / 25652 - Set up and draw one row of the scrolling map view; uses tick counter for road animation frame
.L6434  ld      a,(V_ui_tick_counter)
        and     16
        ld      (V_road_tile_variant),a
        ld      a,(V_ui_tick_counter)
        and     15
        add     a,8
        ld      b,a
        ld      c,0
        call    xypos
        ld      (SMC_print_tile_hl+1),hl
        ld      bc,(V_view_topleft)
        ld      a,(V_ui_tick_counter)      
        and     15
        add     a,b
        ld      b,a
        call    levelmap_xypos
        ld      de,64
        ld      b,1
        jp      L651d

V_current_tile:        defb        $37,$00                ; VAR $6462 / 25698 - current tile being printed

L6464:
        ld      l,$3b
        jr      L6475

; Print a tile
; Entry: a = tile number
.print_tile
.L6468  ld      l,a
        ld      a,(V_current_zone_width_to_print)
        and     a
        jr      nz,L64d6                ; (103)
        call    replace_zone_with_power_if_needed
        call    update_road_tile_for_traffic
.L6475
        ld      h,0
        ld      (V_current_tile),hl
        add     hl,hl
        add     hl,hl
        add     hl,hl
        ld      de,udgs + 536
        add     hl,de

; Print the tile from hl
.SMC_print_tile_hl
.L6481  ld      de,18432        ;SCREEN address, SMC
        ld      b,8
.L6486  ld      a,(hl)
        ld      (de),a
        inc     hl
        inc     d
        djnz    L6486                   ; (-6)
        ld      bc,(V_current_tile)             ; udg being printed
        ld      hl,(V_tile_colour_offset)
        add     hl,bc
        ld      a,(hl)                  ;get colour
        ex      de,hl
        jp      dotextcol_1

; Replace R/I/C with the "need power" tile
replace_zone_with_power_if_needed:
.L6499  ld      a,l
        cp      84
        ret     c
        cp      87
        ret     nc
        ld      a,(V_ui_tick_counter)
        bit     5,a
        ret     z
        ld      l,TILE_NEED_POWER            ;Need power icon
        ret     

; Process road - changes graphics to indicate business
;
; Entry: l = tile at the coordinates
; Exit:  l = tile to actually print
update_road_tile_for_traffic:
.L64a9  ld      a,l
        ld      b,52            ;tile what?
        cp      TILE_H_ROAD               ;
        jr      z,L64b5                 ; (5)
        ld      b,54            ;tile what?
        cp      TILE_V_ROAD
        ret     nz
.L64b5  push    hl
        push    de
        push    bc
        ld      hl,(V_map_render_ptr)
        call    map_addr_to_xy           ;Get coords of address
        call    get_traffic_density_value
        ld      a,(hl)
        pop     bc
        pop     de
        pop     hl
        cp      220
        jr      nc,L64d3                ; (10)
        cp      150
        ret     c
        ld      a,(V_road_tile_variant)
        and     a
        jr      z,L64d3                 ; (1)
        inc     b
.L64d3  ld      l,b
        ret

        defb    0               ; padding

.L64d6  ld      hl,V_current_zone_width_to_print
        dec     (hl)
        ld      a,(ix+0)
        ld      ix,25813
        ld      hl,V_ui_tick_counter
        bit     5,(hl)
        jr      z,L64ef                 ; (7)
        and     240
        cp      160
        jp      z,L6464

.L64ef  ld      hl,udgs + 3390
        ld      (V_tile_colour_offset),hl
        ld      hl,(V_left_tile_index)
        ld      (V_current_tile),hl
        add     hl,hl
        add     hl,hl
        add     hl,hl
        ld      de,udgs + 1288
        add     hl,de
        jp      SMC_print_tile_hl

V_tile_colour_offset:   defw    0       ; VAR $6505 / 25861 - 6505/25861 offset to colour for tiles

;6507
.V_view_topleft        defb    $1e, $25        ; VAR $6507 / 25863 - oordinates of top left of view

;6509
V_map_render_ptr:    defw    0       ; VAR $6509 / 25865 - current map render address (pointer into level map, kept in sync with screen tile printer)
        
; draw level on screen?
.draw_map
.L650b  ld      hl,18432
        ld      (SMC_print_tile_hl+1),hl          ;SMC code nobbling
        ld      bc,(V_view_topleft)          ;Coordinates for mapview top left corner
        call    levelmap_xypos
        ld      de,64
        ld      b,16                ;16 rows to show
.L651d  ld      c,32                ;each with 32 columns
.L651f  ld      a,(V_current_zone_width_to_print)
        and     a
        jr      nz,L652b                ; (6)
        ld      a,(hl)
        cp      128
        call    nc,L655b                ;
.L652b  ld      (V_map_render_ptr),hl              ;Holds the map pointer?
        exx     
        ld      hl,udgs + 3296
        ld      (V_tile_colour_offset),hl
        call    print_tile
        ld      hl,(SMC_print_tile_hl+1)
        inc     l
        jr      nz,L6541                ; (3)
draw_map_screen_addr:
        ld      hl,20480
.L6541  ld      (SMC_print_tile_hl+1),hl              ;SMC code nobbling
        ld      hl,(V_left_tile_index)
        inc     hl
        ld      (V_left_tile_index),hl
        exx     
        inc     hl
        dec     c
        jr      nz,L651f                ; (-49)
        xor     a
        ld      (V_current_zone_width_to_print),a
        add     hl,de
        djnz    L651d                   ; (-58)
        ret     

V_current_zone_width_to_print:  defb    0   ; VAR $6558 / 25944 - how much of the current zone width to print
V_left_tile_index:    defw    0   ; VAR $6559 / 25945 - index for furthest left tile of the zone


; Called when printing tiles >= 128
; Entry hl = map position
.L655b  push    hl
        pop     ix          ;ix = position on map
        xor     a
        ld      (V_zone_x_offset),a
        exx     
        ld      a,(ix+0)
        cp      192
        call    nc,find_left_edge_of_zone
            ;ix = map coordinate of furthest left column of zone
        ld      a,(V_zone_x_offset)
        ld      c,a
        ld      b,0
        ld      a,(ix+0)
        and     7
        sub     c
        ld      (V_current_zone_width_to_print),a       ;width of zone that we need to print
        ld      a,(ix+1)
        and     63
        ld      l,a
        ld      h,0
        add     hl,hl
        add     hl,hl
        add     hl,hl
        ld      a,(ix+2)
        and     7
        or      l
        ld      l,a
        add     hl,bc
        ld      (V_left_tile_index),hl      ;tile index toprint
        exx     
        ret     
