; zx_ui4: lines 8159-8288 of disassembly/sim_game.asm (zx)
V_ui_tick_counter:      defb  0       ; VAR $8F9F / 36767 - UI thread tick counter; incremented each UI loop, selects road animation frame



; Real entry to the game

.gameentry
        ld      a,1
        ld      (V_simulation_disabled),a
        call    initialise_simulation_variables
        call    cls_white
        call    ingame_scrdraw
        call    change_fire_tile
        call    change_flood_tile
        ld      ix,menu_difficulty_text
        call    cls_print_topbox
        call    render_status_bar
        call    run_menu
        call    create_landscape
        call    draw_map
        ld      a,57
        ld      (textcol),a

ui_main_loop_tick:                                    ; $8FCC / 36812 - One tick of the UI main loop: draw pointer, validate cursor, wait 2000 cycles, update display
.L8fcc  call    prpointer
        call    validate_cursor_position           ;Inverse the selected zone size
        ld      bc,2000
.L8fd5  dec     bc
        ld      a,b
        or      c
        jr      nz,L8fd5                ; (-5)
        call    validate_cursor_position           ;Restore the selected zone size
        call    blankpointer
        call    check_cursor_keys
        call    display_sprites
        call    handle_space_action
        ld      a,1
        ld      (V_simulation_disabled),a
        call    draw_scrolling_map_row
        call    scroll_view_arrow_keys
        xor     a
        ld      (V_simulation_disabled),a
        call    ui_periodic_tasks
        call    read_digit_key_select_tool
        call    L9058
        ld      a,(V_wait_for_budget_confirm)
        and     a
        call    nz,show_budget
        ld      hl,V_ui_tick_counter
        inc     (hl)
        ld      a,(V_show_mini_maps)
        and     a
        call    nz,show_mini_maps
        ld      a,(keystore+6)
        and     1       ;'ENTER'
        call    z,show_mini_maps
        jr      ui_main_loop_tick                   ; (-81)

ui_periodic_tasks:                                    ; $901D / 36893 - Every-N-tick dispatcher: alert messages, flood/fire animation, money/date refresh, disasters
.L901d  ld      a,(V_ui_tick_counter)
        and     31
        call    z,display_alert_message
        ld      a,(V_ui_tick_counter)
        and     15
        call    z,L904d
        ld      a,(V_ui_tick_counter)
        and     15
        jp      z,print_money
        cp      1
        jp      z,print_date
        cp      2
        jr      z,change_flood_tile                 ; animation
        cp      3
        jr      z,change_fire_tile                 ; animation
        cp      4
        jp      z,sim_start_disaster
        cp      5
        jp      z,L9144
        ret     


.L904d  call    move_aircrash_sprite
        call    move_tornado
        jp      move_transport_sprite

.V_displayed_money        defw        0        ; VAR $9056 / 36950 - cached money value from last icon redraw; compared each tick to detect change and trigger redraw

.L9058  ld      de,(V_money)
        ld      hl,(V_displayed_money)
        and     a
        sbc     hl,de
        ret     z
        ld      (V_displayed_money),de
        call    doicons
        jp      update_cursor_and_greyout


; Animation by copying the udgs
; Flood
change_flood_tile:
.L906d  ld      de,60560                ;udg 69
        ld      hl,60728
        call    get_random_number
        and     3
        ld      b,a
        ld      a,(V_ui_tick_counter)
        add     a,b
        and     16
        jr      z,L9084                 ; (3)
        ld      hl,60736
.L9084  ld      bc,8
        ldir    
        ret     

; Copying in the UDG area?
; Flames?
change_fire_tile:
.L908a  ld      de,60552                ;udg 68
        ld      hl,60744
        call    get_random_number
        and     3
        ld      b,a
        ld      a,(V_ui_tick_counter)
        add     a,b
        and     16
        jr      z,L90a1                 ; (3)
        ld      hl,60752
.L90a1  ld      bc,8
        ldir    
        ret     
