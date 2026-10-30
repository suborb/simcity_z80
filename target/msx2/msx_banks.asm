; The two bank sections, both linked at $8000 (page 2: banks 1 and 2): the UI's code and the simulation's.  This is linked first so that the ORGs are the ones the linker sees.
        MODULE  msx_banks
        SECTION BANK_UI
        org     $018000                 ; (bank 1, at $8000: the bank number in the high bits is what appmake sorts the files by)
        SECTION BANK_SIM
        org     $028000
        SECTION CODE_HI
        org     $03C000                 ; (the part of the program that lives in page 3, from $C000 up: more resident code, which msx_bank.asm reads from SIMCITY.HI; bank 3 for appmake)
        SECTION code_user
