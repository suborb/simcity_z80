; The console's font and UDG tables, for the tile drawing in plat_console.c.
;
;     void *plat_std_font(void)                       the console's current 32-column font
;     void plat_set_font(const void *p) __z88dk_fastcall   use this 96-character font (char 32 first)
;     void plat_set_udgs(const void *p) __z88dk_fastcall   use these 128 UDGs
;
; On the generic bitmap consoles (NC200, Aquarius+ bitmap mode) printing a character looks
; its 8 bytes up through these two pointers, so storing a pointer is all it takes.  The
; IOCTL_GENCON_SET_FONT32/SET_UDGS calls do that too, but on the Aquarius+ they also copy
; the whole table into character RAM, which a bitmap screen does not need.
;
; The ZX Spectrum keeps the same two pointers in __zx_32col_font and __zx_32col_udgs.  Its
; default tile drawing is zx_blit8 (see plat_console.c), unless built with ZX_PRINT.

        SECTION code_clib
        PUBLIC  _plat_std_font
        PUBLIC  _plat_set_font
        PUBLIC  _plat_set_udgs

        IFDEF   TARGET_ZX
        EXTERN  __zx_32col_font
        EXTERN  __zx_32col_udgs
_plat_std_font:
        ld      hl,(__zx_32col_font)
        ret
_plat_set_font:
        ld      (__zx_32col_font),hl
        ret
_plat_set_udgs:
        ld      (__zx_32col_udgs),hl
        ret
        ELSE
        EXTERN  generic_console_font32
        EXTERN  generic_console_udg32
_plat_std_font:
        ld      hl,(generic_console_font32)
        ret
_plat_set_font:
        ld      (generic_console_font32),hl
        ret
_plat_set_udgs:
        ld      (generic_console_udg32),hl
        ret
        ENDIF
