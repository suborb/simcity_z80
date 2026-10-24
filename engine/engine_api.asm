; ------------------------------------------------------------------------
; Portable entry points of the simulation engine.
;
; These replace the parts of the original program that were wired to the
; Spectrum's cooperative task switcher and its UI loop:
;
;   start_simulation   endless loop in the simulation task
;   ui_periodic_tasks  per-frame dispatcher in the UI task (the engine halves)
;
; The original routines are in the extracted segments and are untouched; this
; file only calls them in the same order.  Build with PORTABLE defined.
;
; All routines preserve nothing; call them with interrupts in any state.
; ------------------------------------------------------------------------

; sim_new_city
;   Create a fresh city: set the date and funds from V_difficulty and generate
;   a random landscape from V_InitialSeed.  Calls the ui_landscape hooks
;   (cls_map, cls_print_topbox, render_status_bar) for the progress display.
sim_new_city:
        jp      create_landscape

; sim_init
;   Reset date, funds and all simulation variables (no landscape change).
sim_init:
        jp      initialise_simulation_variables

; sim_tick
;   Advance the simulation by one tick: one full pass over the 96x96 map.
;   Every month-length (V_sim_speed_block+4) ticks it also runs DoBudget and
;   advances the month.  DoBudget waits (sim_step reports it; see coop.asm) when the player must
;   approve the annual budget (V_auto_budget = 0).
sim_tick:
        call    reset_simulation_vars           ;Zero all per-tick population/fund counters
        call    set_simulation_speed
        call    generate_power_map
        call    process_ric_zones
        call    create_police_fire_minimaps
        call    decay_pollution_minimap
        call    DecTrafficMem
        call    calculate_economic_indices
        call    compute_concern_scores
        call    calculate_city_score
        call    set_unemployment
        call    census_church_hosp
        call    SendMessages
        call    update_stats
        ld      a,(V_sim_loop_counter)
        ld      hl,V_sim_speed_block+4
        and     (hl)
        jr      nz,sim_tick_done
        call    DoBudget
        call    increment_month
sim_tick_done:
        ld      hl,V_sim_loop_counter
        inc     (hl)
        ret

; sim_periodic
;   The engine's share of the original UI task's frame dispatcher
;   (ui_periodic_tasks).  Call once per UI frame with A = frame counter.
;     counter & 15 == 0 : move the aircrash, tornado and transport sprites
;     counter & 15 == 4 : start a pending disaster (V_disaster_option)
;     counter & 15 == 5 : randomly pick a disaster for next time
;   Display work (alert text, money, date, animations) is the platform's job.
sim_periodic:
        and     15
        jr      z,sim_move_sprites
        cp      4
        jp      z,sim_start_disaster
        cp      5
        jp      z,sim_random_disaster
        ret
sim_move_sprites:
        call    move_aircrash_sprite
        call    move_tornado
        jp      move_transport_sprite

; tool_apply
;   Apply the selected tool (V_selected_tool) at the cursor: the same logic as
;   the Spectrum's place_tool_at_cursor, without the keyboard waits and the
;   cursor-in-map test (the platform does those).
;     V_selected_tool   0 bulldoze, 1 road, 2 power line, 3 rail, 4 park,
;                       5 residential, 6 commercial, 7 industrial, 8 police,
;                       9 fire, 10 stadium, 11 power plant, 12 seaport, 13 airport
;     V_pointer_charxy  cursor: C = column within the view, B = row within the view + 8
;     V_view_topleft    map column and row shown at the top left of the view
;   Spends money (V_money) and edits the levelmap; calls draw_map afterwards.
tool_apply:
        call    place_joinables
        ret     c                       ;a road, rail or power line was placed
        call    check_bulldoze_then_place
        jp      c,play_place_sound      ;nothing to do (or auto-bulldozed): just the sound
        ld      a,(V_selected_tool)
        add     a,a
        ld      c,a
        ld      b,0
        ld      hl,zone_action_jump_table
        add     hl,bc
        ld      a,(hl)
        inc     hl
        ld      h,(hl)
        ld      l,a
        jp      (hl)

; Cursor / tool state used by the tool routines (the Spectrum build keeps these
; in its UI code).
        IN_DATA
V_selected_tool:        defb    1
V_pointer_charxy:       defw    0
V_view_topleft:         defw    0

; Variables that stand in for operands the Spectrum program patches in its own code (a
; PORTABLE build has no self-modifying code; the operands are ordinary variables in the engine files).
V_stroke_step_mask:     defb    7               ; AND mask for the landscape stroke step (7 or 3)
V_ellipse_dx:           defw    0               ; running dx of the landscape ellipse
V_ellipse_dy:           defw    0               ; running dy
V_autobulldoze_width:   defb    0               ; width of the zone being auto-bulldozed
V_width_29056:          defb    0               ; width of the area being checked for dirt
V_width_29092:          defb    0               ; width of the area place_zone_direct copies
V_path_tile_offset:     defb    11              ; offset from the neighbour tile to the path tile
V_bulldoze_zone_width:  defb    0               ; width of the zone being bulldozed
V_width_31652:          defb    0               ; width of the area filled (flood/fire spread)
V_width_31705:          defb    0               ; width of the area filled (tornado)
        IN_CODE

; Bit masks for the power minimap (one bit per tile, 8 tiles per byte).  The
; Spectrum build reads the same values from its keyboard buffer at $5B11.
        IN_RODATA
D_bit_masks:
        defb    $80, $40, $20, $10, $08, $04, $02, $01
        IN_CODE
