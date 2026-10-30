; main() and the bank switch of the MZ-2500 build.  The IPL has loaded every page (the program, both banks, the atlas) and appmake's stub has mapped the program and the UI
; bank, so there is nothing to load: the game runs in the UI bank (game_run) and the simulation's bank is mapped in over it by the engine's entry points (engine_bank.inc).
        MODULE  mz_boot
        SECTION code_user

        PUBLIC  _main, mz_bank_in, mz_bank_out
        EXTERN  _game_run, __Exit, mz_w2, mz_w3

; Window 2 and 3 = the simulation's pages; every register is kept.
mz_bank_in:
        push    af
        ld      a,2
        out     ($b4),a
        ld      a,20
        ld      (mz_w2),a
        out     ($b5),a
        inc     a
        ld      (mz_w3),a
        out     ($b5),a
        pop     af
        ret

; ... and the UI's.
mz_bank_out:
        push    af
        ld      a,2
        out     ($b4),a
        ld      a,18
        ld      (mz_w2),a
        out     ($b5),a
        inc     a
        ld      (mz_w3),a
        out     ($b5),a
        pop     af
        ret

_main:
        call    _game_run
        ld      hl,0
        jp      __Exit
