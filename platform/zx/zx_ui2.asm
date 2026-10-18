; zx_ui2: lines 1641-2136 of disassembly/sim_game.asm (zx)


open_menu:                                    ; $66F2 / 26354 - Clear top box, draw menu icons, run menu interaction loop; entry for all top-bar menus
.L66f2  call    cls_print_topbox
        call    render_status_bar
        call    run_menu
        call    draw_map
        ld      a,57
        ld      (textcol),a
just_a_ret:
        ret     

; Print routine

;6704
.print_routine  
        pop     ix
print_routine_ix:
.L6706  ld      a,(ix+0)
        cp      8
        jr      c,L6719                 ; (12)
        call    cls_map
        call    cls_print_topbox
        call    render_status_bar
        jp      run_menu

.L6719  call    cls_black
        call    prt_ctrl
        defb        T_SETCOL,71
        defb        T_BOX,0,0,32,24
        defb        T_END
        call        render_status_bar
        call        run_menu
        ld      a,57
        ld      (textcol),a
        call    cls_white
        jp      ingame_scrdraw

; Clear the screen and print the top box
.cls_print_topbox
.L6738  call    cls_map
        call    prt_ctrl
        defb        T_SETCOL,68
        defb        T_BOX,8,0,32,16
        defb        T_END
        ret

;6757/26439
V_cmd_stream_base:    defw    0       ; VAR $6747 / 26439 - saved IX register (base pointer into current display command stream)
V_status_row:    defb    0       ; VAR $6749 / 26441 - current status panel row (initialised from command stream, incremented each row)


; Zeros...
V_status_slot_table:                    ; VAR $69A0 / 27040 - Status bar slot table and display command stream buffer; IY base for render_status_bar
        defb        $0C, $3C, $A5, $0E, $52, $A5
        defb        $10, $6A, $A5, $16, $8C, $A5, $FF

        defs        107       ;What's up here? - Selection table? LOOK!

V_update_slot_count:    defb    0       ; VAR $67C2 / 26562 - count of registered display-update slots (incremented by register_update_slot each time an item is registered)

render_status_bar:                                    ; $67C3 / 26563 - Initialise status-bar update: set IY=V_status_slot_table, save IX, clear slot count, load first row from IX stream
.L67c3  ld      iy,V_status_slot_table
        ld      (V_cmd_stream_base),ix
        xor     a
        ld      (V_update_slot_count),a
        ld      a,(ix+0)
        ld      (V_status_row),a
        inc     ix

render_status_bar_item:                                    ; $67D7 / 26583 - Process one command from IX stream: dispatch on opcode (print string, register slot, blank, separator)
.L67d7  ld      hl,V_status_row
        inc     (hl)
        ld      a,1
        ld      (textxy),a
        ld      a,(ix+0)
        cp      4
        jr      z,L6801                 ; (26)
        cp      2
        jr      z,L681f                 ; (52)
        cp      3
        jr      z,L682f                 ; (64)
        cp      1
        jr      z,L684c                 ; (89)
        cp      0
        jr      z,status_bar_print_and_next                 ; (47)
        cp      8
        jr      z,L67fc                 ; (1)
        ret     


.L67fc  call    register_update_slot
        jr      status_bar_print_and_next                   ; (37)

.L6801  ld      (iy+0),255
        ret     


; Save current row and IX into update slots table, increment slot count
.register_update_slot
.L6806  ld      a,(V_status_row)
        ld      (iy+0),a
        push    ix
        pop     hl
        ld      (iy+1),l
        ld      (iy+2),h
        ld      de,3
        add     iy,de
        ld      hl,V_update_slot_count
        inc     (hl)
        ret     


.L681f  call    register_update_slot
        inc     ix
        inc     ix

status_bar_print_and_next:                                    ; $6826 / 26662 - Advance IX past inline string, call print_status_string_at_row, loop to next item
.L6826  inc     ix
        call    print_status_string_at_row
        inc     ix
        jr      render_status_bar_item                   ; (-88)

.L682f  inc     ix
        ld      a,(V_status_row)
        ld      b,a
        ld      c,0
        ld      (textxy),bc
        ld      a,32
        ld      (V_text_col_width),a
        ld      a,64
        ld      b,65
        ld      c,66
        call    print_zone_tile_row
        jr      render_status_bar_item                   ; (-116)

V_setting_display_val:    defb    0   ; VAR $684B / 26699 - temp: boolean setting value read from map, used to print ON/OFF in status panel

.L684c  call    register_update_slot
        inc     ix
        ld      l,(ix+0)
        ld      h,(ix+1)
        ld      a,(hl)
        ld      (V_setting_display_val),a
        inc     ix
        inc     ix
        call    print_status_string_at_row
        call    set_textpos_to_status_end
        ld      a,(V_setting_display_val)
        and     a
        jr      z,L6876                 ; (11)
        call    prt_ctrl
        defm        "ON"
        defb        T_END
        inc        ix
        jp      render_status_bar_item

.L6876  call    prt_ctrl
        defm        "OFF"
        defb        T_END
        inc     ix
        jp      render_status_bar_item

print_status_string_at_row:                                    ; $6882 / 26754 - Set textpos to status row col 1, walk IX string printing chars with embedded format codes
.L6882  ld      a,(V_status_row)
        ld      b,a
        ld      c,1
        call    xypos
        ld      (textpos),hl

.L688e  ld      a,(ix+0)
        and     a
        jp      p,L689d
        and     127
        call    prchar
        jp      incprpos

.L689d  cp      33
        jr      z,L68b7                 ; (22)
        cp      6
        jr      z,L68be                 ; (25)
        cp      7
        jr      z,L68d5                 ; (44)
        cp      5
        jr      z,L68eb                 ; (62)
        call    prchar
        call    incprpos
        inc     ix
        jr      L688e                   ; (-41)

.L68b7  call    set_textpos_to_status_end
        inc     ix
        jr      L688e                   ; (-48)

.L68be  ld      a,(ix+1)
        and     a
        call    nz,L6910
        ld      l,(ix+2)
        ld      h,(ix+3)
        call    prtthou
        ld      de,6
        add     ix,de
        jr      L688e                   ; (-71)

.L68d5  ld      a,(ix+1)
        and     a
        call    nz,L6910
        ld      l,(ix+2)
        ld      h,0
        call    prhund
        ld      de,4
        add     ix,de
        jr      L688e                   ; (-93)

.L68eb  ld      a,(ix+1)
        and     a
        call    nz,L6910
        ld      l,(ix+2)
        ld      h,(ix+3)
        ld      c,(ix+4)
        call    prt24bit_cde
        ld      de,5
        add     ix,de
        jr      L688e                   ; (-119) - inner loop entry of print_status_string_at_row

status_row_to_table_ptr:                                    ; $6905 / 26885 - Multiply V_status_row x 3 + base; return HL = pointer into status string table
.L6905  ld      b,a
        add     a,a
        add     a,b
        ld      c,a
        ld      b,0
        ld      hl,26490
        add     hl,bc
        ret     


.L6910  ld      a,(V_status_row)
        call    status_row_to_table_ptr
        ld      a,(textxy)
        ld      (hl),a
        push    ix
        pop     de
        inc     hl
        ld      (hl),e
        inc     hl
        ld      (hl),d
        ret     


set_textpos_to_status_end:                                    ; $6922 / 26914 - Set textxy to (status_row, 24), update textpos; positions cursor at end of status line
.L6922  ld      a,(V_status_row)
        ld      b,a
        ld      c,24
        ld      (textxy),bc
        call    xypos
        ld      (textpos),hl
        ret     


toggle_status_row_attrs:                                    ; $6933 / 26931 - XOR 30 cell attributes at col 1 of V_status_row with 70 (flash highlight toggle)
.L6933  ld      c,1
        call    cxytoattr
        ld      b,30
.L693a  ld      a,(hl)
        xor     70
        ld      (hl),a
        inc     l
        djnz    L693a                   ; (-7)
        ret     

.V_menu_draw_hook        defw        0                ; VAR $6942 / 26946 - sommat with printing address

; Menu interaction loop: Q=up, A=down, SPACE=select
.run_menu
.L6944  ld      a,(V_update_slot_count)
        and     a
        ret     z
        xor     a
        ld      (V_menu_selection),a
        call    invoke_display_hook
.L6950  call    toggle_menu_row_highlight
.L6953  ld      b,8
.L6955  halt    
        djnz    L6955                   ; (-3)
        ld      a,(keystore+2)
        and     1           ;'Q'
        call    z,menu_up
        ld      a,(keystore+1)
        and     1           ;'A'
        call    z,menu_down
        ld      a,(keystore+7)
        and     1           ;'SPACE'
        jr      z,L6971                 ; (2)
        jr      L6953                   ; (-30)

.L6971  ld      a,(keystore+7)
        and     1           ;'SPACE'
        jr      z,L6971                 ; (-7)
        call    get_menu_slot_ptr
        inc     hl
        ld      a,(hl)
        inc     hl
        ld      h,(hl)
        ld      l,a
        ld      a,(hl)
        cp      2                   ;Code 2 is jump to routine
        jp      z,L6a4e
        cp      1
        jp      z,L6a44
        cp      8
        jr      z,L6996                 ; (7)
        ret     


V_menu_max_rows:    defb    0       ; VAR $6990 / 27024 - max options/row
V_menu_selection_ptr:    defw    0       ; VAR $6991 / 27025 -

V_menu_count_xy: defw        0       ; VAR $6993 / 27027 - xy coordinates for menu?

V_key_repeat_counter:    defb    0       ; VAR $6995 / 27029 -

.L6996  ld      a,10
        ld      (V_key_repeat_counter),a
        call    toggle_menu_row_highlight
        call    get_menu_slot_ptr
        ld      a,(hl)
        ld      (V_menu_count_xy+1),a
        call    status_row_to_table_ptr
        ld      a,(hl)
        ld      (V_menu_count_xy),a
        inc     hl
        ld      a,(hl)
        inc     hl
        ld      h,(hl)
        ld      l,a
        inc     hl
        inc     hl
        ld      (V_menu_selection_ptr),hl
        inc     hl
        ld      a,(hl)
        ld      (V_menu_max_rows),a
        ld      a,69
        ld      (textcol),a

menu_interaction_loop:                                    ; $69C0 / 27072 - Main menu event loop: decrement repeat timer, handle Q/A navigation, wait for repeat delay
.L69c0  call    decrement_repeat_timer
        call    print_menu_item_count
        ld      a,(keystore+7)
        and     1           ;'SPACE'
        jr      z,L6a04                 ; (55)
        ld      a,(keystore+2)
        and     1           ;'Q'
        call    z,L69ec
        ld      a,(keystore+1)
        and     1           ;'A'
        call    z,L69fa
        call    invoke_display_hook
        ld      a,(V_key_repeat_counter)
        and     a
        jr      z,menu_interaction_loop                 ; (-38)
        ld      b,a

.L69e7  halt    
        djnz    L69e7                   ; (-3)
        jr      menu_interaction_loop                   ; (-44)

; Move down the menu list?
.L69ec  ld      a,(V_menu_max_rows)
        inc     a
        ld      c,a
        ld      hl,(V_menu_selection_ptr)
        ld      a,(hl)
        inc     a
        cp      c
        ret     z
        ld      (hl),a
        ret     

; Move up the menu list?
.L69fa  ld      hl,(V_menu_selection_ptr)
        ld      a,(hl)
        dec     a
        cp      255
        ret     z
        ld      (hl),a
        ret     


.L6a04  ld      a,(keystore+7)
        and     1           ;'SPACE'
        jr      z,L6a04                 ; (-7)
        ld      a,71
        ld      (textcol),a
        call    print_menu_item_count
        jp      L6950

; Print the menu item count (from V_menu_selection_ptr) at the menu position
.print_menu_item_count
.L6a16  ld      bc,(V_menu_count_xy)
        call    xypos
        ld      (textpos),hl
        ld      hl,(V_menu_selection_ptr)
        ld      l,(hl)
        ld      h,0
        call    prhund
        ret     


; Call the display hook stored in V_menu_draw_hook (if non-zero)
.invoke_display_hook
.L6a2a  ld      hl,(V_menu_draw_hook)
        ld      a,h
        or      l
        ret     z
        jp      (hl)

decrement_repeat_timer:                                    ; $6A31 / 27185 - Call twiddlekeys; if key held decrement repeat delay, if released reset to 10
.L6a31  call    twiddlekeys
        jr      z,L6a3e                 ; (8)
        ld      hl,V_key_repeat_counter
        ld      a,(hl)
        and     a
        ret     z
        dec     (hl)
        ret     


.L6a3e  ld      a,10
        ld      (V_key_repeat_counter),a
        ret     


.L6a44  inc     hl
        ld      a,(hl)
        inc     hl
        ld      h,(hl)
        ld      l,a
        ld      a,(hl)
        xor     1
        ld      (hl),a
        ret     


.L6a4e  inc     hl
        ld      a,(hl)
        inc     hl
        ld      h,(hl)
        ld      l,a
        jp      (hl)

menu_up:
.L6a54  ld      hl,V_menu_selection
        ld      a,(hl)
        dec     a
        cp      255
        ret     z
        call    toggle_menu_row_highlight
        ld      (hl),a
; XOR screen attributes on the current menu selection row (highlight/unhighlight)
.toggle_menu_row_highlight
.L6a60  push    hl
        push    af
        call    get_menu_slot_ptr
        ld      b,(hl)
        call    toggle_status_row_attrs
        pop     af
        pop     hl
        ret     

menu_down:
.L6a6c  ld      a,(V_update_slot_count)
        ld      b,a
        ld      hl,V_menu_selection
        ld      a,(hl)
        inc     a
        cp      b
        ret     z
        call    toggle_menu_row_highlight
        ld      (hl),a
        jr      toggle_menu_row_highlight                   ; (-29)


V_menu_selection:    defb        0   ; VAR $6A7D / 27261 - Current menu selection

; Return hl = pointer into update slots table for current menu selection (selection * 3)
.get_menu_slot_ptr
.L6a7e  ld      a,(V_menu_selection)
        ld      b,a
        add     a,a
        add     a,b
        ld      c,a
        ld      b,0
        ld      hl,V_status_slot_table
        add     hl,bc
        ret     

