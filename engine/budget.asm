; budget: lines 8522-8725 of disassembly/sim_game.asm (engine)

V_tax_collected:    defb    0,0,0       ; VAR $930E / 37646 - , 930e


V_Transport_Funding_Requested:                    defw        0   ; VAR $9311 / 37649 - budget, transport funding
V_Budget_Police_Funding_Requested:    defw        0   ; VAR $9313 / 37651 - budget how much police funding
V_Budget_Fire_Funding_Requested:      defw        0   ; VAR $9315 / 37653 - budget how much fire funding
   
V_Transport_Funding_Allocated:  defw    0       ; VAR $9317 / 37655
V_Police_Funding_Allocated:  defw    0       ; VAR $9319 / 37657
V_Fire_Funding_Allocated:  defw    0       ; VAR $931B / 37659


V_expenditure:  defb    0,0,0           ; VAR $931D / 37661 - how much we spent this budget

V_cashflow:        defb    0,0,0       ; VAR $9320 / 37664 - cashflow


V_previous_money:        defb    0,0,0           ; VAR $9323 / 37667 - previous money before budget
V_money_after_budget:            defb    0,0,0           ; VAR $9326 / 37670 - money after budget


calculate_tax:                                    ; $9329 / 37673 - Compute tax = population / 100 * tax_rate; result in V_tax_collected
.L9329  ld      hl,(V_population)
        ld      a,(V_population+2)
        ld      c,a
        ld      a,100
        call    div24_chl_by_a
        ld      a,(SMC_tax_rate)           ;Tax rate
        ld      e,a
        ld      d,0
        call    L_mult_24_16x16
        ld      (V_tax_collected),hl
        ld      a,c
        ld      (V_tax_collected+2),a
        ret     

        ld      a,71
        ld      (textcol),a
        call    run_budget
        call    print_budget_amounts
        ld      a,69

.L9353  ld      (textcol),a
        ret

        defb    0               ; padding

run_budget:                                    ; $9358 / 37720 - Save previous money, calculate tax, compute all department allocations and cashflow
.L9358  ld      hl,(V_money)
        ld      a,(V_money+2)
        ld      c,a
        ld      (V_previous_money),hl
        ld      a,c
        ld      (V_previous_money+2),a
        call    alloc_transport_funding
        call    alloc_police_funding
        call    alloc_fire_funding
        call    cap_transport_funding_to_balance
        call    cap_police_funding_to_balance
        call    cap_fire_funding_to_balance
        call    calc_expenditure_and_cashflow
        ret     


alloc_transport_funding:                                    ; $937C / 37756 - Allocate transport funding: requested * percent / 100 -> V_Transport_Funding_Allocated
.L937c  ld      a,(SMC_transport_percent)
        ld      hl,(V_Transport_Funding_Requested)
        call    apply_funding_percent
        ld      (V_Transport_Funding_Allocated),hl
        ret     


alloc_police_funding:                                    ; $9389 / 37769 - Allocate police funding: requested * percent / 100 -> V_Police_Funding_Allocated
.L9389  ld      a,(SMC_police_percent)
        ld      hl,(V_Budget_Police_Funding_Requested)
        call    apply_funding_percent
        ld      (V_Police_Funding_Allocated),hl
        ret     


alloc_fire_funding:                                    ; $9396 / 37782 - Allocate fire funding: requested * percent / 100 -> V_Fire_Funding_Allocated
.L9396  ld      a,(SMC_fire_percent)
        ld      hl,(V_Budget_Fire_Funding_Requested)
        call    apply_funding_percent
        ld      (V_Fire_Funding_Allocated),hl
        ret     


calc_expenditure_and_cashflow:                                    ; $93A3 / 37795 - Sum all dept allocations -> expenditure; tax - expenditure -> cashflow
.L93a3  ld      hl,(V_Transport_Funding_Allocated)
        ld      de,(V_Police_Funding_Allocated)
        ld      bc,0
        call    l_add24
        ld      de,(V_Fire_Funding_Allocated)
        call    l_add24
        ld      (V_expenditure),hl
        ld      a,c
        ld      (V_expenditure+2),a
        ld      b,c
        ex      de,hl
        ld      hl,(V_tax_collected)
        ld      a,(V_tax_collected+2)
        ld      c,a
        call    l_sub24
        ld      (V_cashflow),hl
        ld      a,c
        ld      (V_cashflow+2),a
        ld      hl,(V_money)
        ld      a,(V_money+2)
        ld      c,a
        ld      de,(V_expenditure)
        ld      a,(V_expenditure+2)
        ld      b,a
        call    l_sub24
        ld      de,(V_tax_collected)
        ld      a,(V_tax_collected+2)
        ld      b,a
        call    l_add24
        ld      (V_money_after_budget),hl
        ld      a,c
        ld      (V_money_after_budget+2),a
        ret     

V_budget_working_reg:    defb   0,0,0       ; VAR $93F6 / 37878 -


cap_transport_funding_to_balance:                                    ; $93F9 / 37881 - If transport allocation would overdraft (money+tax < transport), cap to available balance
.L93f9  ld      hl,(V_previous_money)
        ld      a,(V_previous_money+2)
        ld      c,a
        ld      de,(V_tax_collected)
        ld      a,(V_tax_collected+2)
        ld      b,a
        call    l_add24
        ld      (V_budget_working_reg),hl
        ld      a,c
        ld      (V_budget_working_reg+2),a
        ld      de,(V_Transport_Funding_Allocated)
        ld      b,0
        call    l_sub24
        bit     7,c
        ret     z
        ld      hl,(V_budget_working_reg)
        ld      a,(V_budget_working_reg+2)
        ld      c,a
        ld      (V_Transport_Funding_Allocated),hl
        ret     


cap_police_funding_to_balance:                                    ; $9429 / 37929 - If police allocation would overdraft, cap it to available balance
.L9429  ld      hl,(V_previous_money)
        ld      a,(V_previous_money+2)
        ld      c,a
        ld      de,(V_tax_collected)
        ld      a,(V_tax_collected+2)
        ld      b,a
        call    l_add24
        ld      de,(V_Transport_Funding_Allocated)
        ld      b,0
        call    l_sub24
        ld      (V_budget_working_reg),hl
        ld      a,c
        ld      (V_budget_working_reg+2),a
        ld      de,(V_Police_Funding_Allocated)
        ld      b,0
        call    l_sub24
        bit     7,c
        ret     z
        ld      hl,(V_budget_working_reg)
        ld      a,(V_budget_working_reg+2)
        ld      c,a
        ld      (V_Police_Funding_Allocated),hl
        ret     


cap_fire_funding_to_balance:                                    ; $9462 / 37986 - If fire allocation would overdraft, cap it to available balance
.L9462  ld      hl,(V_previous_money)
        ld      a,(V_previous_money+2)
        ld      c,a
        ld      de,(V_tax_collected)
        ld      a,(V_tax_collected+2)
        ld      b,a
        call    l_add24
        ld      de,(V_Transport_Funding_Allocated)
        ld      b,0
        call    l_sub24
        ld      de,(V_Police_Funding_Allocated)
        ld      b,0
        call    l_sub24
        ld      (V_budget_working_reg),hl
        ld      a,c
        ld      (V_budget_working_reg+2),a
        ld      de,(V_Fire_Funding_Allocated)
        ld      b,0
        call    l_sub24
        bit     7,c
        ret     z

        ld      hl,(V_budget_working_reg)
        ld      a,(V_budget_working_reg+2)
        ld      c,a
        ld      (V_Fire_Funding_Allocated),hl
        ret     
