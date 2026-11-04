; Start-up: copy the common memory part of the program up to where it runs (target/pcw/plat_pcw.asm).
; The HIMEM image is stored after the BSS in the file (appmake appends it): the start-up copies it up to where it runs.
        SECTION code_crt_init
        EXTERN  __BSS_END_tail
        EXTERN  __HIMEM_head
        EXTERN  __HIMEM_END_tail
        ld      hl,__BSS_END_tail
        ld      de,__HIMEM_head
        ld      bc,__HIMEM_END_tail-__HIMEM_head
        ldir
