; The bank sections and where they are linked: (RAM page << 16) | the address they are mapped at.  This is linked first so that the ORGs are the ones the linker sees.
; the code in BANK_12 is the platform's drawing and pointer (plat_mz2500.c, mz_pointer.c, pointer_res.c: #pragma codeseg BANK_12), which has to be callable from either bank.
; appmake (a program with a BOOTSTRAP stub) puts the UI bank (16 KB from page 18) and the simulation (16 KB from page 20) after the program and spills each into the next page; the atlas is pages 22-24.
        MODULE  mz_banks
        SECTION BANK_12                 ; RAM page 12, which the IPL maps at $8000 and the crt's BOOTSTRAP stub (appmake) starts in its first 32 bytes: the rest is code that is always mapped
        org     $0c8000
        defs    32
        SECTION BANK_18
        org     $124000
        SECTION BANK_20
        org     $144000
        SECTION BANK_22
        org     $164000
        SECTION code_user
