; CP/M entry point.
        MODULE  einstein_boot
        SECTION code_compiler
        PUBLIC  _main
        EXTERN  __Exit, _game_run, _einstein_load_base

_main:
        call    _einstein_load_base
        call    _game_run
        ld      hl,0
        jp      __Exit
