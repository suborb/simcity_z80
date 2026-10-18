; Which font does the console use right now?  The tile drawing in plat_console.c
; swaps in the tile font for the map and needs the standard one back for text.
;
;     void *plat_std_font(void)       the console's current 32-column font
;
; The pointer is held in a different place on each family of targets.

        SECTION code_clib
        PUBLIC  _plat_std_font

        IFDEF   TARGET_ZX
        EXTERN  __zx_32col_font
_plat_std_font:
        ld      hl,(__zx_32col_font)
        ret
        ELSE
        EXTERN  generic_console_font32
_plat_std_font:
        ld      hl,(generic_console_font32)
        ret
        ENDIF
