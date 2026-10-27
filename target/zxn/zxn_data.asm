; The art of the Next build (tools/st_tiles_3bpp.py --zxn): the palette, the attribute colours and the tool icons stay in the
; program; the pictures are in two 16 KB banks of their own, 20 and 21 (8 KB pages 40 to 43), which appmake puts in the NEX file and
; the placer maps a page at a time (plat_zxn.asm).
        SECTION rodata_user
        PUBLIC  _zxn_head
_zxn_head:
        BINARY  "build/zxn/head.bin"

        SECTION BANK_20
        BINARY  "build/zxn/atlas0.bin"

        SECTION BANK_21
        BINARY  "build/zxn/atlas1.bin"

; The tool icons, 14 of 22x20, a byte a pixel (a palette index): in a bank of their own, 8 KB page 44 (ICON_PAGE in plat_zxn.c)
        SECTION BANK_22
        BINARY  "build/zxn/icons.bin"

        IFDEF   ZXN_SCENARIOS
        INCLUDE "build/zxn/scenarios/scenarios.asm"
        ENDIF
