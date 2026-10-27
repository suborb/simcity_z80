; SAM Coupe mouse driver prototype.
; User-land SAM Coupe mouse polling using the RDMSEL port.

        SECTION code_user
        PUBLIC  _plat_mouse_init
        PUBLIC  _plat_mouse_poll
        PUBLIC  _plat_mouse_input
        PUBLIC  _plat_mouse_icon_hit
        IFDEF   TARGET_SAM
        EXTERN  _sam_page_data
        ENDIF

_plat_mouse_init:
        IFDEF   TARGET_SAM
        call    _sam_page_data
        ENDIF
        ld      hl,0
        ld      (_plat_mouse_x),hl
        ld      (_plat_mouse_y),hl
        ld      (_plat_mouse_polls),hl
        ld      (_plat_mouse_prev_x),hl
        ld      (_plat_mouse_prev_y),hl
        xor     a
        ld      (_plat_mouse_buttons),a
        ld      (_plat_mouse_present),a
        ld      (_plat_mouse_buttons_last),a
        ld      (_plat_mouse_seen),a
        ld      a,1
        ld      (_plat_mouse_enabled),a
        ret

; Called by user code to consume one complete mouse scan.
_plat_mouse_poll:
        IFDEF   TARGET_SAM
        call    _sam_page_data          ; the coordinates and scan buffer are in the game data bank
        ENDIF
        push    bc
        push    de
        push    hl
        ld      a,(_plat_mouse_enabled)
        or      a
        jp      z,sm_frame_done

        ld      hl,(_plat_mouse_polls)
        inc     hl
        ld      (_plat_mouse_polls),hl

        ld      bc,$fffe                ; RDMSEL and keyboard/mouse port
        ld      hl,_plat_mouse_raw
        in      a,(c)                   ; strobe mouse interface
        ld      (hl),a
        inc     hl
        in      a,(c)                   ; gate/button byte: cursor keys must be released
        ld      (hl),a
        and     $0f
        cp      $0f
        jr      nz,sm_no_gate
        ld      a,1
        ld      (_plat_mouse_present),a
        inc     hl
        ld      d,8                     ; original mouse scan: eight bytes after the keyboard-state gate
sm_scan_loop:
        in      a,(c)
        ld      (hl),a
        inc     hl
        dec     d
        jr      nz,sm_scan_loop

        jr      sm_update

sm_no_gate:
        jp      sm_frame_done          ; held cursor key/control: retry next poll

; Fred's 16-bit X update, with FATPIX=1 for the 256-pixel-wide probe.
sm_update:
        ld      a,(_plat_mouse_raw+7)    ; X delta high nibble
        and     $0f
        rlca
        rlca
        rlca
        rlca
        ld      d,a
        ld      a,(_plat_mouse_raw+8)    ; X delta low nibble
        and     $0f
        or      d
        ld      e,a
        rla                             ; sign extend 8-bit delta to DE
        sbc     a,a
        ld      d,a
        ld      hl,(_plat_mouse_x)
        add     hl,de
        ld      a,h
        inc     a
        jr      z,sm_x_min             ; negative overflow clamps to zero
        cp      2                       ; FATPIX=1: coordinate range is 0..255
        jr      c,sm_x_store
        ld      hl,$00ff
        jr      sm_x_store
sm_x_min:
        ld      hl,0
sm_x_store:
        ld      (_plat_mouse_x),hl

; Fred's Y update with NEG enabled for screen coordinates (zero at the top).
        ld      a,(_plat_mouse_raw+4)    ; Y delta high nibble
        and     $0f
        rlca
        rlca
        rlca
        rlca
        ld      d,a
        ld      a,(_plat_mouse_raw+5)    ; Y delta low nibble
        and     $0f
        or      d
        neg
        ld      d,a
        ld      a,(_plat_mouse_y)
        add     a,d
        cp      192
        jr      c,sm_y_inrange
        xor     a
        bit     7,d
        jr      nz,sm_y_inrange
sm_y_max:
        ld      a,191
        ld      l,a
        ld      h,0
        jr      sm_y_store
sm_y_inrange:
        ld      l,a
        ld      h,0
sm_y_store:
        ld      (_plat_mouse_y),hl

        ld      a,(_plat_mouse_raw+2)    ; mouse button byte
        cpl
        and     $07
        ld      (_plat_mouse_buttons),a

sm_frame_done:
        pop     hl
        pop     de
        pop     bc
        ret

; Poll once, then return bit 0 for coordinate movement, bit 1 for a new
; left-button press, and bit 2 while the left button is held. Keeping this
; comparison in the SAM target avoids growing the low-memory UI section.
_plat_mouse_input:
        IFDEF   TARGET_SAM
        call    _sam_page_data
        ENDIF
        call    _plat_mouse_poll
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
        PUBLIC  _plat_mouse_x
        PUBLIC  _plat_mouse_y
        PUBLIC  _plat_mouse_buttons
        PUBLIC  _plat_mouse_present
        PUBLIC  _plat_mouse_polls
        PUBLIC  _plat_mouse_raw
        PUBLIC  _plat_mouse_enabled
        PUBLIC  _plat_mouse_prev_x
        PUBLIC  _plat_mouse_prev_y
        PUBLIC  _plat_mouse_buttons_last
        PUBLIC  _plat_mouse_seen
        PUBLIC  _plat_mouse_pointer_cell_count
        PUBLIC  _plat_mouse_pointer_cells
        PUBLIC  _plat_mouse_pointer_background
        PUBLIC  _plat_mouse_pointer_mask

_plat_mouse_x:       defs 2
_plat_mouse_y:       defs 2
_plat_mouse_buttons: defs 1
_plat_mouse_present: defs 1
_plat_mouse_polls:   defs 2
_plat_mouse_raw:     defs 10
_plat_mouse_enabled: defs 1
_plat_mouse_prev_x:  defs 2
_plat_mouse_prev_y:  defs 2
_plat_mouse_buttons_last: defs 1
_plat_mouse_seen:    defs 1
_plat_mouse_pointer_cell_count: defs 1
_plat_mouse_pointer_cells: defs 18
_plat_mouse_pointer_background: defs 288
_plat_mouse_pointer_mask: defs 288
