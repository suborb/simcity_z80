; ZX Spectrum Next: the esxDOS call handler.  The program is at $0000 (z88dk's appmake puts it in a bank of its own, which a short
; loader maps into slots 0 and 1 before it starts the program), where the ROM normally is.
;
; esxDOS is reached by `rst 8` followed by the function number, which the DivMMC takes over when the ROM is in the lowest 16 KB and a
; fetch is made from $0008.  The program is in that 16 KB, so the call goes to a handler (_z80_rst_08h, which the crt's vector at
; $0008 jumps to) that runs from RAM above $4000: it reads the function number, maps the ROM into slots 0 and 1, makes the call itself
; from there, puts the program's pages back, and returns to the caller.  Interrupts are off (the game keeps them off, or has the
; sound's, which this holds off) and everything esxDOS is given (names, buffers) must be above $4000: the data is.
        SECTION code_crt_init
        EXTERN  __BSS_head
        EXTERN  __BSS_END_tail

        ld      a,31
        nextreg $56,a
        inc     a
        nextreg $57,a
        xor     a
        ld      hl,__BSS_head
        ld      bc,__BSS_END_tail - __BSS_head - 1
        ld      de,__BSS_head + 1
        ld      (hl),a
        ldir

        SECTION code_crt_init
        ld      bc,$243B                ; the pages that are in slots 0 and 1 (the handler puts them back)
        ld      a,$50
        out     (c),a
        inc     b
        in      a,(c)
        ld      (esx_p0),a
        dec     b
        ld      a,$51
        out     (c),a
        inc     b
        in      a,(c)
        ld      (esx_p1),a

        SECTION rodata_user
        PUBLIC  _z80_rst_08h
        defc    _z80_rst_08h = esx_src

; The handler, as it is in the program; it is copied to esx_ram, so it refers to its own bytes (esx_fn, esx_ret) at their addresses in esx_ram.
esx_src:
        ex      (sp),hl                 ; hl = the return address, the caller's hl on the stack
        push    af
        ld      a,i                     ; are interrupts on? (P/V is the flip-flop)
        di                              ; (the ROM is in slot 0 for a while: an interrupt would run its handler)
        ld      a,0
        jp      po,esx_off
        inc     a
esx_off:
        ld      (esx_iff),a
        ld      a,(hl)                  ; the function number (the program is still mapped)
        inc     hl
        ld      (esx_fn),a
        ld      (esx_ret),hl
        ld      a,$FF                   ; the ROM, in slots 0 and 1
        nextreg $50,a
        nextreg $51,a
        pop     af
        pop     hl
        rst     8
esx_fn: defb    0
        push    af                      ; what it returned
        ld      a,(esx_p0)              ; the program's pages
        nextreg $50,a
        ld      a,(esx_p1)
        nextreg $51,a
        pop     af
        push    hl
        ld      hl,(esx_ret)
        ex      (sp),hl                 ; the caller's way back is on the stack, hl is as esxDOS left it
        push    af
        ld      a,(esx_iff)
        or      a
        jr      z,esx_done
        pop     af
        ei                              ; (takes effect after the ret)
        ret
esx_done:
        pop     af
        ret
esx_ret:
        defw    0
esx_iff:
        defb    0
esx_p0: defb    0
esx_p1: defb    0
esx_end:

