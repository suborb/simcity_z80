; zx_ui4b: lines 9269-9279 of disassembly/sim_game.asm (zx)
.display_alert_message
.L9997  ld      a,(V_alertmessage)
        add     a,23
        ld      hl,text_table
        call    get_word_from_table
        ld      a,29
        ld      bc,$0601
        jp      print_string
        defb    0               ; padding


