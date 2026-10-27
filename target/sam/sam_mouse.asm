; SAM Coupe mouse: the game's side of it.  The scanning and detection are z88dk's
; in_MouseSAM (libsrc/target/sam/input); this turns a reading into the events
; the UI wants and hit-tests the tool icons.  The library keeps its state in
; the bss, which is in the data bank: every entry here pages that in.

        SECTION code_user
        PUBLIC  _plat_mouse_init
        PUBLIC  _plat_mouse_input
        PUBLIC  _plat_mouse_icon_hit
        EXTERN  _in_MouseSAMInit
        EXTERN  _in_MouseSAM_callee
        GLOBAL  _in_SAMcoordX, _in_SAMcoordY, _in_SAMpresent
        PUBLIC  _plat_mouse_x, _plat_mouse_y, _plat_mouse_present
        IFDEF   TARGET_SAM
        EXTERN  _sam_page_data
        ENDIF

; the UI's names for the library's position and presence (the keyboard moves the pointer too)
        defc    _plat_mouse_x = _in_SAMcoordX
        defc    _plat_mouse_y = _in_SAMcoordY
        defc    _plat_mouse_present = _in_SAMpresent

_plat_mouse_init:
        IFDEF   TARGET_SAM
        call    _sam_page_data
        ENDIF
        ld      hl,0
        ld      (_plat_mouse_prev_x),hl
        ld      (_plat_mouse_prev_y),hl
        xor     a
        ld      (_plat_mouse_buttons),a
        ld      (_plat_mouse_buttons_last),a
        ld      (_plat_mouse_seen),a
        jp      _in_MouseSAMInit

; Read the mouse, then return bit 0 for coordinate movement, bit 1 for a new
; left-button press, and bit 2 while the left button is held.  Keeping this
; comparison in the SAM target avoids growing the low-memory UI section.
_plat_mouse_input:
        IFDEF   TARGET_SAM
        call    _sam_page_data
        ENDIF
        ld      hl,_plat_mouse_buttons
        push    hl
        ld      hl,_plat_mouse_x
        push    hl
        ld      hl,_plat_mouse_y
        push    hl
        call    _in_MouseSAM_callee
        ld      b,0
        ld      a,(_plat_mouse_seen)
        or      a
        jr      z,sm_input_moved
        ld      hl,(_plat_mouse_x)
        ld      de,(_plat_mouse_prev_x)
        or      a
        sbc     hl,de
        jr      nz,sm_input_moved
        ld      hl,(_plat_mouse_y)
        ld      de,(_plat_mouse_prev_y)
        or      a
        sbc     hl,de
        jr      z,sm_input_buttons
sm_input_moved:
        set     0,b
sm_input_buttons:
        ld      hl,(_plat_mouse_x)
        ld      (_plat_mouse_prev_x),hl
        ld      hl,(_plat_mouse_y)
        ld      (_plat_mouse_prev_y),hl
        ld      a,(_plat_mouse_buttons)
        and     1
        ld      c,a
        ld      a,(_plat_mouse_buttons_last)
        and     1
        jr      nz,sm_input_held
        ld      a,c
        or      a
        jr      z,sm_input_button_store
        set     1,b
sm_input_held:
        ld      a,c
        or      a
        jr      z,sm_input_button_store
        set     2,b
sm_input_button_store:
        ld      a,(_plat_mouse_buttons)
        ld      (_plat_mouse_buttons_last),a
        ld      a,1
        ld      (_plat_mouse_seen),a
        ld      l,b
        ld      h,0
        ret

; Return the clicked tool icon (0..13), or $FF outside its 7-by-2 strip.
; Each button is 24x16 pixels, with its first row beginning at y=8.
_plat_mouse_icon_hit:
        IFDEF   TARGET_SAM
        call    _sam_page_data
        ENDIF
        ld      a,(_plat_mouse_y)
        cp      8
        jr      c,sm_icon_miss
        cp      24
        jr      c,sm_icon_row0
        cp      40
        jr      nc,sm_icon_miss
        ld      b,7
        jr      sm_icon_col
sm_icon_row0:
        ld      b,0
sm_icon_col:
        ld      a,(_plat_mouse_x)
        cp      168
        jr      nc,sm_icon_miss
        ld      c,0
sm_icon_col_loop:
        cp      24
        jr      c,sm_icon_col_done
        sub     24
        inc     c
        jr      sm_icon_col_loop
sm_icon_col_done:
        ld      a,b
        add     a,c
        ld      l,a
        ld      h,0
        ret
sm_icon_miss:
        ld      hl,$00FF
        ret

        SECTION bss_user
        PUBLIC  _plat_mouse_buttons
        PUBLIC  _plat_mouse_pointer_cell_count
        PUBLIC  _plat_mouse_pointer_cells
        PUBLIC  _plat_mouse_pointer_background
        PUBLIC  _plat_mouse_pointer_mask

_plat_mouse_buttons: defs 1
_plat_mouse_prev_x:  defs 2
_plat_mouse_prev_y:  defs 2
_plat_mouse_buttons_last: defs 1
_plat_mouse_seen:    defs 1
_plat_mouse_pointer_cell_count: defs 1
_plat_mouse_pointer_cells: defs 18
_plat_mouse_pointer_background: defs 288
_plat_mouse_pointer_mask: defs 288
