; zx_input2: lines 4800-4984 of disassembly/sim_game.asm (zx)
; Converts kempston into directional keypresses
kempston_to_keystore:                                    ; $7A01 / 31233 - Read Kempston joystick and synthesise equivalent key-store bits (P/O/A/Q/SPACE)
.L7a01  call    read_kempston
        ld      c,a
        bit     0,c
        jr      nz,L7a0e                ; (5)
        ld      hl,keystore+5
        res     0,(hl)      ;'P'

.L7a0e  bit     1,c
        jr      nz,L7a17                ; (5)
        ld      hl,keystore+5
        res     1,(hl)      ;'O'

.L7a17  bit     2,c
        jr      nz,L7a20                ; (5)
        ld      hl,keystore+1
        res     0,(hl)      ;'A'

.L7a20  bit     3,c
        jr      nz,L7a29                ; (5)
        ld      hl,keystore+2
        res     0,(hl)      ;'Q'

.L7a29  bit     4,c
        ret     nz

        ld      hl,keystore+7
        res     0,(hl)      ;'SPACE'
        ret     


cursor_keys_sym_shift:                                    ; $7A32 / 31282 - Read SYM+SHIFT held; if both, translate cursor keys to P/O/A/Q; alternate scroll input path
.L7a32  ld      a,(keystore+7)
        and     2           ;'SYM'
        ret     z


.L7a38  ld      a,(keystore)
        and     1           ;'SHIFT'
        ret     z

        ld      a,(keystore+4)
        ld      c,a
        bit     3,c
        jr      nz,L7a4b                ; (5)
        ld      hl,keystore+5
        res     0,(hl)      ;'P'

.L7a4b  bit     4,c
        jr      nz,L7a54                ; (5)
        ld      hl,keystore+5
        res     1,(hl)      ;'O'

.L7a54  bit     2,c
        jr      nz,L7a5d                ; (5)
        ld      hl,keystore+1
        res     0,(hl)      ;'A'

.L7a5d  bit     1,c
        jr      nz,L7a66                ; (5)
        ld      hl,keystore+2
        res     0,(hl)      ;'Q'

.L7a66  bit     0,c
        ret     nz

        ld      hl,keystore+7
        res     0,(hl)      ;'SPACE'
        ret     


scroll_view_arrow_keys:                                    ; $7A6F / 31343 - Handle cursor-key map scrolling (SHIFT not held); calls draw_map if scrolled
.L7a6f  ld      a,(keystore)
        and     1           ;'SHIFT'
        ret     nz

        ld      hl,0
        ld      a,(keystore+4)
        and     4           ;'8'
        call    z,L6d0f
        ld      a,(keystore+3)
        and     16          ;'5'
        call    z,L6d05
        ld      a,(keystore+4)
        and     8           ;'7'
        call    z,L6d19
        ld      a,(keystore+4)
        and     16          ;'6'
        call    z,L6d23
        ld      a,h
        or      l
        ret     z

        jp      draw_map

draw_minimap_menu:                                    ; $7A9E / 31390 - Draw the minimap selection panel (boxes, map names list) using prt_ctrl sequences
.L7a9e  call    setminimap_col
        call    prt_ctrl
        defb        T_SETCOL,69
        defb        T_BOX,0,0,8,9
        defb        T_BOX,3,2,5,5
        defb        T_BOX,17,0,8,7
        defb        T_SETCOL,66
        defb        T_SETXY,1,2
        defm        "MAPS"
        defb        T_SETCOL,68
        defb        T_SETXY,9,0
        defm        "CITY"
        defb        T_SETXY,10,0
        defm        "POLLUTN"
        defb        T_SETXY,11,0
        defm        "POLICE"
        defb        T_SETXY,12,0
        defm        "FIREDEP"
        defb        T_SETXY,13,0
        defm        "TRAFFIC"
        defb        T_SETXY,14,0
        defm        "POWER"
        defb        T_SETXY,15,0
        defm        "TRANSPT"
        defb        T_SETXY,16,0
        defm        "CRIME"
        defb        T_END
.draw_minimap_legend                        ; $7B09 / 31497
.L7b09
        call        prt_ctrl
        defb        T_SETCOL,70
        defb        T_SETXY,4,3
        defm        "123"
        defb        T_SETXY,5,3
        defm        "456"
        defb        T_SETXY,6,3
        defm        "789"
        defb        T_SETXY,18,1
        defm        "  MAX"
        defb        T_SETXY,22,1
        defm        "  MIN"
        defb        T_SETCOL,127
        defb        T_SETXY,18,1
        defm        " "
        defb        T_SETCOL,118
        defb        T_SETXY,19,1
        defm        " "
        defb        T_SETCOL,100
        defb        T_SETXY,20,1
        defm        " "
.draw_minimap_legend_colours                ; $7B42 / 31554
.L7b42
        defb        T_SETCOL,82
        defb        T_SETXY,21,1
        defm        " "
        defb        T_SETCOL,73
        defb        T_SETXY,22,1
        defm        " "
        defb        T_END
        ret

.V_minimap_frame_counter        defb        0        ; VAR $7B50 / 31568 - incremented each minimap loop iteration; low 2 bits rate-limit key input

show_mini_maps:
.L7b51  xor     a
        ld      (V_show_mini_maps),a
        call    draw_minimap_menu

.L7b58  call    toggle_minimap_section_flash
        call    highlight_minimap_label
        call    start_minimap_render
        call    highlight_minimap_label
        call    toggle_minimap_section_flash
        ld      a,(V_wait_for_budget_confirm)
        and     a
        jr      nz,L7b7d                ; (16)
        ld      a,(keystore+7)
        and     1       ;'SPACE'
        jr      z,L7b7d                 ; (9)
        call    handle_minimap_key_input
        ld      hl,V_minimap_frame_counter
        inc     (hl)
        jr      L7b58                   ; (-37)

.L7b7d  call    cls_white
        call    ingame_scrdraw
        jp      draw_map

