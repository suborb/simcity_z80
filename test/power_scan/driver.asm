; Minimal entry point for test/power_scan/run.py. The harness prepares the map
; and the zero-terminated station list in memory, then checks the power bitmap.
        IN_CODE
power_scan_test_start:
        ld      sp,$fff0
        di
        call    power_bfs_start
        jr      power_scan_test_done
power_scan_generated_test_start:
        ld      sp,$fff0
        di
        call    generate_power_map
        jr      power_scan_test_done
power_scan_placement_test_start:
        ld      sp,$fff0
        di
        call    sim_init
        ld      a,11                      ; power station tool
        ld      (V_selected_tool),a
        ld      bc,$3a3c                  ; cursor column 60, map row 50 (+8 screen rows)
        ld      (V_pointer_charxy),bc
        call    tool_apply
        call    sim_tick                  ; generate_power_map runs at the start of the tick
        jr      power_scan_test_done
power_scan_scenario_tick_start:
        ld      sp,$fff0
        di
        call    sim_init
        call    sim_task_reset
power_scan_scenario_step:
        call    sim_step                  ; ZXN runs the tick on its cooperative stack
        ld      a,l
        and     a
        jr      z,power_scan_scenario_step
power_scan_test_done:
        jr      power_scan_test_done
