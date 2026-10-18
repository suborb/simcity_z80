; zx_ui3: lines 2546-2697 of disassembly/sim_game.asm (zx)

do_view_change:
.L6cbf  ld      bc,(V_pointer_charxy)
        ld      a,c
        and     a               ;Menu row
        ret     nz
        ld      a,b             ;We want x == 2
        cp      2              
        ret     nz
        call    wait_for_space_key_release
.L6ccd  ld      a,(keystore+5)
        and     1       ;'P'
        call    z,L6d0f
        ld      a,(keystore+5)
        and     2       ;'O'
        call    z,L6d05
        ld      a,(keystore+2)
        and     1       ;'Q'
        call    z,L6d19
        ld      a,(keystore+1)
        and     1       ;'A'
        call    z,L6d23
        halt    
        call    draw_map
        call    display_sprites
        ld      hl,V_ui_tick_counter
        ld      a,(hl)
        add     a,4
        ld      (hl),a
        ld      a,(keystore+7)
        and     1       ;'SPACE'
        jr      nz,L6ccd                ; (-53)
        jp      wait_for_space_key_release

.L6d05  ld      hl,V_view_topleft
        ld      a,(hl)
        dec     a
        cp      255
        ret     z
        ld      (hl),a
        ret     


.L6d0f  ld      hl,V_view_topleft
        ld      a,(hl)
        inc     a
        cp      64
        ret     z
        ld      (hl),a
        ret     


.L6d19  ld      hl,V_view_topleft+1
        ld      a,(hl)
        dec     a
        cp      255
        ret     z
        ld      (hl),a
        ret     


.L6d23  ld      hl,V_view_topleft+1
        ld      a,(hl)
        inc     a
        cp      80
        ret     z
        ld      (hl),a
        ret     


read_digit_key_select_tool:                                    ; $6D2D / 27949 - Read digit keys 0-9 (SHIFT held, no SYM) and select matching build tool by index
.L6d2d  ld      a,(keystore)
        and     1           ;'SHIFT'
        ret     z

        ld      a,(keystore+7)
        and     2           ;'SYM'
        ret     nz

        call    getkeyval
        ret     c

        cp      48
        jr      nz,L6d45                ; (4)
        ld      b,9
        jr      try_select_zone_tool                   ; (40)

.L6d45  cp      49
        ret     c
        cp      58
        ret     nc
        sub     49
        ld      b,a
        jr      try_select_zone_tool                   ; (29)

;6d50
V_selected_tool:    defb        1       ; VAR $6D50 / 27984 - currently selected build tool/zone type index (0=bulldoze,1=road,2=power,3=rail,4=park,5=residential,6=commercial,7=industrial,8=police,9=fire,10=stadium,11=power plant,12=seaport,13=airport)

.try_select_build_tool                      ; $6D51 / 27985
.L6d51
        ld      bc,(V_pointer_charxy)
        ld      a,b
        and     a
        ret     z
        cp      3
        ret     nc
        ld      a,c
        cp      2
        ret     c
        cp      30
        ret     nc
        call    wait_for_space_key_release
        ld      a,(V_pointer_charxy)
        sub     2
        srl     a
        ld      b,a
try_select_zone_tool:                                    ; $6D6D / 28013 - Check player can afford zone B; if yes and different from current, select it and refresh cursor/icons
.L6d6d  push    bc
        call    get_cost_for_zone
        ld      b,0
        ld      hl,(V_money)
        ld      a,(V_money+2)
        ld      c,a
        call    l_sub24
        ld      a,c
        pop     bc
        and     a
        ret     m

        ld      a,(V_selected_tool)
        cp      b
        ret     z

        ld      a,b
        ld      (V_selected_tool),a
        call    doicons
        call    L6305

update_cursor_and_greyout:                                    ; $6D90 / 28048 - Set cursor to selected tool size, draw it; grey out unaffordable zone icons
.L6d90  ld      a,(V_selected_tool)
        sla     a
        add     a,2
        ld      c,a
        ld      b,1
        ld      de,$0202
        ld      (V_zone_cursor_size),de
        call    draw_cursor_xor
        call    greyout_unaffordable_zones
        call    get_zone_size
        ld      (V_zone_cursor_size),de
        ret     

