; zx_place_tool_keys: lines 3117-3162 of disassembly/sim_game.asm (zx)
place_tool_at_cursor:                                    ; $7012 / 28690 - Main tool-placement dispatcher: check cursor in map, place joinables or dispatch zone action
.L7012  ld      a,(V_pointer_charxy+1)
        cp      8
        ret     c
        ld      a,(V_cursor_validity+1)
        and     a
        ret     z
        call    place_joinables
        ret     c           ;We placed a joinable over another squre
        call    check_bulldoze_then_place       ;check if we can place/auto bulldoze
        jp      nc,L702d
        call    play_place_sound
        jp      wait_all_keys_pressed

.L702d  ld      a,(V_selected_tool)
        add     a,a
        ld      c,a
        ld      b,0
        ld      hl,zone_action_jump_table            ;get the handler for the icon
        add     hl,bc
        ld      a,(hl)
        inc     hl
        ld      h,(hl)
        ld      l,a
        ld      (SMC_28735+1),hl          ;store the address following
SMC_28735:
        call    0               ;TODO: Why not just call  jp(hl)

wait_all_keys_pressed:                                    ; $7042 / 28738 - Spin until A+Q+P+O+SPACE all simultaneously held; used as confirmation gate
.L7042  ld      a,(keystore+1)
        and     1       ;'A'
        ret     z
        ld      a,(keystore+2)
        and     1       ;'Q'
        ret     z
        ld      a,(keystore+5)
        and     1       ;'P'
        ret     z
        ld      a,(keystore+5)
        and     2       ;'O'
        ret     z
        ld      a,(keystore+7)
        and     1       ;'SPACE'
        jr      z,wait_all_keys_pressed                 ; (-31)
        ret     

