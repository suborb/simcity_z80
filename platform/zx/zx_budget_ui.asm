; zx_budget_ui: lines 8438-8521 of disassembly/sim_game.asm (zx)

; Show budget
show_budget:
.L9194  ld      a,1
        ld      (V_simulation_disabled),a
        call    calculate_tax
        call    run_budget
        ld      hl,37702        ;TODO - in budget screen

.L91a2  ld      (V_menu_draw_hook),hl
        ld      ix,text_budget
        call    print_routine_ix
        ld      hl,0
        ld      (V_menu_draw_hook),hl
        xor     a
        ld      (V_simulation_disabled),a
        ld      (V_wait_for_budget_confirm),a
        jp      draw_map

;91bc/37308
.text_budget
        defb     $00, $00
        defm    "         FISCAL BUDGE"
        defb    'T' + 128
        defb    $03, $08
        defm    "TAX RATE!   "
        defb    $07, $01

        ;@91e4
SMC_tax_rate:
        defb    $07, $14
        defb    '%' + $80
        defb    $03, $00
        defm    "TAX COLLECTED       "
        defb    '$' + 128
        defb    $03, $00
        defb    $a0, $00
        defm    "       AMOUNT  AMOUNT    FUN"
        defb    'D' + 128
        defb    $00
        defm    "       REQSTD  ALLCTD    LEVE"
        defb    'L' + 128
        defb    $00, $a0
        defb    $08
        defm    "TRANS  $       $!  "
        defb    $07, $01

;9256
SMC_transport_percent:
        defb    $64, $64
        defb    '%'+128
        defb    $8
        defm    "POLICE $       $!  "
        defb    $7, $1
;926f
SMC_police_percent:
        defb    $64,$64
        defb    '%'+128
        defb    $8
        defm    "FIRE   $       $!  "
        defb    $07, $01
;9288
SMC_fire_percent:
        defb    $64, $64
        defb    '%'+128, $00
        defb    $a0
        defb    $03, $00, $a0, $00
        defm    "CASH FLOW           "
        defb    '$' + 128
        defb    0
L92a7:
        defm    "PREVIOUS FUND       "
        defb    '$' + 128
        defb    0
        defm    "                    --------"
        defb    '-' + 128
        defb    0
L92db:
        defm    "CURRENT FUNDS       "
        defb    '$'+128
        defb    $03, $02, $03, $67
        defm    "    GO WITH THESE FIGURE"
        defb    'S'+128
        defb    4
