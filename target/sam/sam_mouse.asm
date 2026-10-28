; SAM Coupe mouse: the game's side of it.  The scanning and detection are z88dk's in_MouseSAM (libsrc/target/sam/input), and the pointer's events, keys and modal-screen
; keys are target/common/pointer.c (ptr_driver.h); this starts the driver and hit-tests the tool icons.  The library keeps its state in the bss, which is in the data
; bank: every entry here pages that in.

        SECTION code_user
        PUBLIC  _plat_mouse_init
        PUBLIC  _plat_mouse_icon_hit
        EXTERN  _in_MouseSAMInit
        EXTERN  _pointer_start
        EXTERN  _plat_mouse_x, _plat_mouse_y
        IFDEF   TARGET_SAM
        EXTERN  _sam_page_data
        ENDIF

_plat_mouse_init:
        IFDEF   TARGET_SAM
        call    _sam_page_data
        ENDIF
        call    _in_MouseSAMInit
        jp      _pointer_start

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
        PUBLIC  _plat_mouse_pointer_cell_count
        PUBLIC  _plat_mouse_pointer_cells
        PUBLIC  _plat_mouse_pointer_background
        PUBLIC  _plat_mouse_pointer_mask

_plat_mouse_pointer_cell_count: defs 1
_plat_mouse_pointer_cells: defs 18
_plat_mouse_pointer_background: defs 288
_plat_mouse_pointer_mask: defs 288
