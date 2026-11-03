; Minimal Tatung Einstein 256 V9938 and CP/M console support.
        MODULE  einstein_io
        SECTION code_user

        PUBLIC  _einstein_screen5, _einstein_wait_frame, _einstein_getkey
        PUBLIC  _einstein_fatal
        PUBLIC  _einstein_dos_fail
        EXTERN  __Exit

; Set up V9938 screen 5, 192 lines, with sprites disabled.
_einstein_screen5:
        di
        ld      hl,einstein_regs
        ld      b,8
        ld      c,VDP_CMD
        xor     a
        out     (c),a
        ld      a,$80
        out     (c),a
        ld      hl,einstein_regs
        ld      b,8
        ld      d,0
es5_loop:
        ld      a,(hl)
        inc     hl
        out     (c),a
        ld      a,d
        or      $80
        out     (c),a
        inc     d
        djnz    es5_loop
        ei
        ret
einstein_regs:
        defb    $06,$40,$1F,$80,$01,$EF,$07,$00   ; R#1 $40: display on, NO vertical blank interrupt: with it on the system's handler resets the machine (the game polls S#2 instead)

; Wait for V9938 vertical blank using status register 2's field interrupt flag.
_einstein_wait_frame:
        di                              ; (the system's interrupt handler must not read S#2 for S#0)
        ld      a,2
        out     (VDP_CMD),a
        ld      a,$8F
        out     (VDP_CMD),a
ewf_wait:
        in      a,(VDP_CMD)
        and     $40
        jr      z,ewf_wait
        xor     a
        out     (VDP_CMD),a
        ld      a,$8F
        out     (VDP_CMD),a
        ei
        ret

; CP/M BDOS function 6, E=FF: nonblocking direct console input (0 means none).
_einstein_getkey:
        push    ix
        push    iy
        ld      c,6
        ld      e,$FF
        call    5
        ld      l,a
        ld      h,0
        pop     iy
        pop     ix
        ret

; Print a '$'-terminated message and return to CP/M.
_einstein_fatal:
        ld      hl,2
        add     hl,sp
        ld      e,(hl)
        inc     hl
        ld      d,(hl)
        push    ix
        push    iy
        ld      c,9
        call    5
        pop     iy
        pop     ix
        ld      hl,0
        jp      __Exit

; The overlay window and the two overlays' sizes, from the link (the loader sees them as extern arrays/bytes).
        PUBLIC  _einstein_overlay, _einstein_game_size, _einstein_modal_size
        EXTERN  __EINSTEIN_GAME_OVL_head, __EINSTEIN_GAME_OVL_size, __EINSTEIN_MODAL_OVL_size
        defc    _einstein_overlay = __EINSTEIN_GAME_OVL_head
        defc    _einstein_game_size = __EINSTEIN_GAME_OVL_size
        defc    _einstein_modal_size = __EINSTEIN_MODAL_OVL_size

; The DOS's error handler (einstein_dos_quiet in plat_msx2.c points its vectors here).  The BDOS runs on a stack of its own, with the
; address of the routine that finishes a call (restores IX and IY, loads HL from the result slot) and under that the address of the
; exit routine that reloads the caller's stack: rebuild those two words, set the result to $FF and finish the call from here, whatever
; the BDOS was in the middle of.  The addresses are found by einstein_dos_quiet.
        PUBLIC  _einstein_dos_exit, _einstein_dos_ret, _einstein_dos_top, _einstein_dos_slot
_einstein_dos_exit:     defw    0       ; the exit routine (ld sp,(save); ret)
_einstein_dos_ret:      defw    0       ; the routine the function returns to
_einstein_dos_top:      defw    0       ; the BDOS stack's top
_einstein_dos_slot:     defw    0       ; where the result is kept
_einstein_dos_fail:
        ld      hl,(_einstein_dos_slot)
        ld      (hl),$FF
        inc     hl
        ld      (hl),0
        ld      sp,(_einstein_dos_top)
        ld      hl,(_einstein_dos_exit)
        push    hl
        ld      hl,(_einstein_dos_ret)
        push    hl
        ret
