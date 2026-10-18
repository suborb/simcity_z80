; ------------------------------------------------------------------------
; Headless test platform for the portable engine.
;
; It supplies everything the engine expects from a platform (see
; engine/PLATFORM_INTERFACE.md) as fixed settings and do-nothing hooks, and a
; tiny driver that runs the simulation for a number of ticks.  It is used by
; test/golden to compare the portable engine with the original Spectrum
; program under z88dk-ticks, and is a template for the real platforms.
;
; Build:  z80asm -DPORTABLE -b -m platform/test/test_platform.asm
; ------------------------------------------------------------------------
        org     $0100

; ---- driver ------------------------------------------------------------
test_start:
        ld      sp,$fff0
        di
        call    sim_init
        ld      hl,test_pokes           ; (address, value) pairs, address 0 ends
test_poke:
        ld      e,(hl)
        inc     hl
        ld      d,(hl)
        inc     hl
        ld      a,d
        or      e
        jr      z,test_poke_done
        ld      a,(hl)
        inc     hl
        ld      (de),a
        jr      test_poke
test_poke_done:
        ld      hl,0
        ld      (V_view_topleft),hl
        ld      hl,test_actions
test_next_action:
        ld      a,(hl)                  ; tool, x, y ... terminated by $FF
        cp      $ff
        jr      z,test_actions_done
        ld      (V_selected_tool),a
        inc     hl
        ld      c,(hl)                  ; x
        inc     hl
        ld      b,(hl)                  ; y
        inc     hl
        ld      a,b
        add     a,8                     ; the cursor row is the view row + 8
        ld      b,a
        ld      (V_pointer_charxy),bc
        push    hl
        call    tool_apply
        pop     hl
        jr      test_next_action
test_actions_done:
        ld      a,(test_coop)
        and     a
        jr      z,test_actions_go
        call    sim_task_reset
test_actions_go:
        ld      bc,(test_ticks)
test_loop:
        ld      a,b
        or      c
        jr      z,test_view_step
        push    bc
        ld      a,(test_coop)
        and     a
        jr      z,test_direct
test_slices:                            ; cooperative: slice the tick into map rows
        ld      hl,(test_steps)
        inc     hl
        ld      (test_steps),hl
        call    sim_step
        ld      a,l
        and     a
        jr      z,test_slices
        jr      test_ticked
test_direct:
        call    sim_tick
test_ticked:
        pop     bc
        dec     bc
        jr      test_loop
test_view_step:
        ld      a,(test_view_on)        ; optionally render the view with view_cell
        and     a
        jr      z,test_done
        ld      a,(test_view_tick)
        ld      (V_view_tick),a
        ld      hl,test_view_out
        ld      de,(test_view_xy)       ; e = column, d = row of the top left cell
        ld      b,16                    ; rows
test_view_row:
        push    bc
        push    de
        ld      b,32                    ; columns
test_view_col:
        push    bc
        push    de
        push    hl
        ld      c,e                     ; c = column, b = row
        ld      b,d
        call    view_cell               ; hl = art, a = attribute
        ex      de,hl                   ; de = art
        pop     hl                      ; hl = output pointer
        ld      bc,8
        ex      de,hl
        ldir                            ; copy the art (hl = art, de = output)
        ld      (de),a                  ; then the attribute
        inc     de
        ex      de,hl                   ; hl = next output position
        pop     de
        inc     e
        pop     bc
        djnz    test_view_col
        pop     de
        inc     d
        pop     bc
        djnz    test_view_row
test_done:
        jr      test_done               ; z88dk-ticks stops here (-end)

test_ticks:     defw    1               ; patched by the harness
test_actions:   defs    768,$ff         ; patched by the harness
test_pokes:     defs    768,0           ; patched by the harness
test_coop:      defb    0               ; patched by the harness: 1 = tick with sim_step slices
test_steps:     defw    0               ; number of sim_step calls
test_view_on:   defb    0
test_view_tick: defb    0
test_view_xy:   defw    0               ; e = left column, d = top row
test_view_out:  defs    16*32*9         ; per cell: 8 bytes of art + attribute

; ---- the engine --------------------------------------------------------
        INCLUDE "../../engine/engine.asm"

; ---- settings the engine reads (normally owned by the UI) -----------------
V_difficulty:           defb    0       ; 0 = easy ($20000 start funds)
SMC_tax_rate:           defb    7
SMC_transport_percent:  defb    100
SMC_police_percent:     defb    100
SMC_fire_percent:       defb    100
V_simulation_speed:     defb    1
V_auto_budget:          defb    1       ; never ask the UI to approve the budget
V_disaster_reset:       defb    1       ; non-zero = no random disasters
textcol:                defb    0
V_auto_bulldoze:        defb    1       ; tools may demolish what is in the way
V_power_type_chosen:    defb    2       ; answer given by ui_choose_power_plant: coal

; ---- hooks: this platform has no display or sound -------------------------
ui_budget_confirm:      ret
ui_choose_power_plant:  ret
draw_map:               ret
play_place_sound:       ret
wait_if_demolish_pending:       xor     a       ; Z = carry on
                        ret
play_crash_sound:       ret
play_rising_tone:       ret
play_falling_tone:      ret
soundfx1:               ret
print_budget_amounts:   ret
cls_map:                ret
cls_print_topbox:       ret
render_status_bar:      ret
text_generating_landscape:      defb    0
