; ------------------------------------------------------------------------
; Settings and hooks the engine needs, for platforms written in C.
; (See engine/PLATFORM_INTERFACE.md.)  The C code owns the policy: it writes the
; settings below at start-up and when the player changes options, and reads
; the "dirty" flag to know when the map must be redrawn.
; ------------------------------------------------------------------------
        MODULE  hooks
        SECTION code_user

        PUBLIC  _V_difficulty, _SMC_tax_rate
        PUBLIC  _SMC_transport_percent, _SMC_police_percent, _SMC_fire_percent
        PUBLIC  _V_simulation_speed, _V_auto_budget, _V_disaster_reset
        PUBLIC  _V_auto_bulldoze, _V_power_type_chosen, _map_dirty

        ; names the engine expects (no underscore)
        PUBLIC  V_difficulty, SMC_tax_rate
        PUBLIC  SMC_transport_percent, SMC_police_percent, SMC_fire_percent
        PUBLIC  V_simulation_speed, V_auto_budget, V_disaster_reset
        PUBLIC  V_auto_bulldoze, V_power_type_chosen
        PUBLIC  textcol
        PUBLIC  ui_budget_confirm, ui_choose_power_plant, draw_map
        PUBLIC  play_place_sound, wait_if_demolish_pending
        PUBLIC  play_crash_sound, play_rising_tone, play_falling_tone, soundfx1
        PUBLIC  print_budget_amounts, cls_map, cls_print_topbox, render_status_bar
        PUBLIC  text_generating_landscape

V_difficulty:           defb    0
SMC_tax_rate:           defb    7
SMC_transport_percent:  defb    100
SMC_police_percent:     defb    100
SMC_fire_percent:       defb    100
V_simulation_speed:     defb    1
V_auto_budget:          defb    1
V_disaster_reset:       defb    0
V_auto_bulldoze:        defb    1
V_power_type_chosen:    defb    2               ; 1 nuclear, anything else coal
textcol:                defb    0
_map_dirty:             defb    1

        defc    _V_difficulty          = V_difficulty
        defc    _SMC_tax_rate          = SMC_tax_rate
        defc    _SMC_transport_percent = SMC_transport_percent
        defc    _SMC_police_percent    = SMC_police_percent
        defc    _SMC_fire_percent      = SMC_fire_percent
        defc    _V_simulation_speed    = V_simulation_speed
        defc    _V_auto_budget         = V_auto_budget
        defc    _V_disaster_reset      = V_disaster_reset
        defc    _V_auto_bulldoze       = V_auto_bulldoze
        defc    _V_power_type_chosen   = V_power_type_chosen

; tool routines call this after changing the map
draw_map:
        ld      a,1
        ld      (_map_dirty),a
        ret

; hooks that do nothing yet
ui_budget_confirm:
ui_choose_power_plant:
play_place_sound:
play_crash_sound:
play_rising_tone:
play_falling_tone:
soundfx1:
print_budget_amounts:
cls_map:
cls_print_topbox:
render_status_bar:
        ret

wait_if_demolish_pending:
        xor     a                       ; Z = carry on demolishing
        ret

text_generating_landscape:
        defb    0
