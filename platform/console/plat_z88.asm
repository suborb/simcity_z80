; OZ native text output for the Z88 build.
;
;     void z88_sop(const char *s) __z88dk_fastcall      write a string to the current OZ window
;
; This is GN_Sop, OZ's own string output: it understands the VDU codes (1,'3','@',x,y positions the
; cursor, 12 clears the window, 1,'2','C',n selects window n), which is how the status text is put in
; the Z88's text window while the console itself is drawing the map into the graphics window.

        SECTION code_clib
        PUBLIC  _z88_sop
        INCLUDE "stdio.def"
        INCLUDE "director.def"

; The 14 tool icons as OZ character rows (tools/make_z88_icons.py): 4 cells of 8 rows each.
        SECTION rodata_user
        PUBLIC  _z88_icons
_z88_icons:
        BINARY  "assets/z88_icons.bin"

        SECTION code_clib
; void plat_set_name(const char *name) __z88dk_fastcall: the city's name for OZ's Index (DC_Nam, which keeps IX)
        PUBLIC  _plat_set_name
_plat_set_name:
        call_oz (dc_nam)
        ret

_z88_sop:
        call_oz (gn_sop)                ;HL = the string; preserves IX and IY
        ret

; The generic console's three drawing variables, defined here instead of taking the library's copies.
;
; The console draws the map by paging the map's RAM bank into segment 1 ($4000-$7FFF), and while it is
; there it reads these variables.  The library keeps them in the data section, which a ROM build puts
; after all of the BSS, and the engine's buffers make the BSS 16 KB, so the variables ended up above $4000:
; the console then read the map's own memory in place of its font pointer and drew junk.  Here they are
; in bss_compiler, low in RAM.  (The library's definitions are not linked once these exist.)  They start
; at zero; plat_init sets the font and UDG pointers.

        SECTION bss_compiler
        PUBLIC  generic_console_flags
        PUBLIC  generic_console_font32
        PUBLIC  generic_console_udg32

generic_console_flags:  defb    0
generic_console_font32: defw    0
generic_console_udg32:  defw    0
