; zx_budget_ui2: lines 8726-8758 of disassembly/sim_game.asm (zx)

print_budget_amounts:
.L94a4  ld      bc,$0516        ;Tax collectd
        ld      hl,V_tax_collected
        call    prt24bit
        ld      bc,$1216        ;previous fund
        ld      hl,V_previous_money
        call    prt24bit
        ld      hl,(V_Transport_Funding_Allocated)      ;transport allocated
        ld      bc,$0b11
        call    prt16bit
        ld      hl,(V_Transport_Funding_Requested)      ;transport requested
        ld      bc,$0b09
        call    prt16bit
        ld      hl,(V_Police_Funding_Allocated)      ;police allocated
        ld      bc,$0c11
        call    prt16bit
        ld      hl,(V_Budget_Police_Funding_Requested)
        ld      bc,$0c09
        call    prt16bit
        ld      hl,(V_Fire_Funding_Allocated)      ;fire allocated
        ld      bc,$0d11
        call    prt16bit
        ld      hl,(V_Budget_Fire_Funding_Requested)
        ld      bc,$0d09
        call    prt16bit
        ld      bc,$1116        ;cashflow
        ld      hl,V_cashflow       
        call    prt24bit
        ld      bc,$1416        ;current funds
        ld      hl,V_money_after_budget       
        call    prt24bit
        ret     
