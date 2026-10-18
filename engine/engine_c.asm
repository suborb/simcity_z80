; ------------------------------------------------------------------------
; C bridge for the portable engine (z88dk).
;
; Assembles engine.asm (with PORTABLE) into one module and exports what C code
; needs.  Arguments and results go through plain globals so that this works
; with any z88dk calling convention:
;
;     void sim_new_city(void)           new random city from V_InitialSeed
;     void sim_init(void)
;     void sim_tick(void)               one simulation tick (blocks)
;     uint8_t sim_step(void)            run the simulation to its next yield (a map row);
;                                       returns 1 when a tick has just completed
;     void sim_periodic(void)           uses engine_a = frame counter
;     void tool_apply(void)             uses V_selected_tool etc.
;     void view_fetch(void)             view_x, view_y -> view_art, view_attr
;
; The platform supplies the settings and hooks (see engine/PLATFORM_INTERFACE.md);
; platform/common/hooks.asm provides them for C programs.
; ------------------------------------------------------------------------
        MODULE  engine
        SECTION code_user

        PUBLIC  _sim_new_city, _sim_init, _sim_tick, _sim_step, _sim_periodic, _tool_apply
        PUBLIC  _view_fetch
        PUBLIC  _view_tile_art
        defc    _view_tile_art = view_udgs + ART_TILES
        PUBLIC  _engine_a, _view_x, _view_y, _view_art, _view_attr

        ; supplied by the platform (platform/common/hooks.asm)
        EXTERN  V_difficulty, SMC_tax_rate
        EXTERN  SMC_transport_percent, SMC_police_percent, SMC_fire_percent
        EXTERN  V_simulation_speed, V_auto_budget, V_disaster_reset
        EXTERN  V_auto_bulldoze, V_power_type_chosen, textcol
        EXTERN  ui_budget_confirm, ui_choose_power_plant, draw_map
        EXTERN  play_place_sound, wait_if_demolish_pending
        EXTERN  play_crash_sound, play_rising_tone, play_falling_tone, soundfx1
        EXTERN  print_budget_amounts, cls_map, cls_print_topbox, render_status_bar
        EXTERN  text_generating_landscape

        INCLUDE "engine.asm"

; ---- calls ------------------------------------------------------------
_sim_new_city:
        push    ix
        push    iy
        call    sim_task_reset          ;a new city abandons any tick in progress
        call    sim_new_city
        pop     iy
        pop     ix
        ret

_sim_init:
        push    ix
        push    iy
        call    sim_init
        pop     iy
        pop     ix
        ret

_sim_tick:
        push    ix
        push    iy
        call    sim_tick
        pop     iy
        pop     ix
        ret

_sim_step:
        push    ix
        push    iy
        call    sim_step                ;L = 1 when a whole tick has completed
        pop     iy
        pop     ix
        ret

_sim_periodic:
        push    ix
        push    iy
        ld      a,(_engine_a)
        call    sim_periodic
        pop     iy
        pop     ix
        ret

_tool_apply:
        push    ix
        push    iy
        call    tool_apply
        pop     iy
        pop     ix
        ret

_view_fetch:
        push    ix
        push    iy
        ld      a,(_view_x)
        ld      c,a
        ld      a,(_view_y)
        ld      b,a
        call    view_cell
        ld      (_view_art),hl
        ld      (_view_attr),a
        pop     iy
        pop     ix
        ret

_engine_a:      defb    0
_view_x:        defb    0
_view_y:        defb    0
_view_art:      defw    0
_view_attr:     defb    0

; ---- data the C code reads and writes ------------------------------------
        PUBLIC  _levelmap, _minimaps, _D_tile_flags
        PUBLIC  _V_month, _V_year, _V_money, _V_CityPop
        PUBLIC  _V_RValve, _V_CValve, _V_IValve
        PUBLIC  _V_alertmessage, _V_selected_tool, _V_pointer_charxy, _V_view_topleft
        PUBLIC  _V_InitialSeed, _V_view_tick, _V_sim_loop_counter
        PUBLIC  _V_TrafficAverage, _V_PolluteAverage, _V_concern_crime, _V_unemployment
        PUBLIC  _V_transport_active, _V_transport_pos, _V_transport_sprite

        defc    _levelmap           = levelmap
        defc    _minimaps           = minimaps
        defc    _D_tile_flags       = D_tile_flags
        defc    _V_month            = V_month
        defc    _V_year             = V_year
        defc    _V_money            = V_money
        defc    _V_CityPop          = V_CityPop
        defc    _V_RValve           = V_RValve
        defc    _V_CValve           = V_CValve
        defc    _V_IValve           = V_IValve
        defc    _V_alertmessage     = V_alertmessage
        defc    _V_selected_tool    = V_selected_tool
        defc    _V_pointer_charxy   = V_pointer_charxy
        defc    _V_view_topleft     = V_view_topleft
        defc    _V_InitialSeed      = V_InitialSeed
        defc    _V_view_tick        = V_view_tick
        defc    _V_sim_loop_counter = V_sim_loop_counter
        defc    _V_TrafficAverage   = V_TrafficAverage
        defc    _V_PolluteAverage   = V_PolluteAverage
        defc    _V_concern_crime    = V_concern_crime
        defc    _V_unemployment     = V_unemployment
        defc    _V_transport_active = V_transport_active
        defc    _V_transport_pos    = V_transport_pos
        defc    _V_transport_sprite = V_transport_sprite
