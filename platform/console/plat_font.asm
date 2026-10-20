; NC200 console font and UDG pointers, for the tile drawing in plat_console.c.

        SECTION code_clib
        PUBLIC  _plat_std_font
        PUBLIC  _plat_set_font
        PUBLIC  _plat_set_udgs

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
