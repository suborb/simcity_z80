; The art of the Next build (tools/st_tiles_3bpp.py --zxn): the palette, the attribute colours and the tool icons stay in the
; program; the pictures are in three 16 KB banks of their own, 20, 21 and 22 (8 KB pages 40 to 44: 128 pictures a page), which appmake puts in the
; NEX file and the placer maps a page at a time (plat_zxn.asm).
        SECTION rodata_user
        PUBLIC  _zxn_head
_zxn_head:
        BINARY  "build/zxn/head.bin"

        SECTION BANK_20
        BINARY  "build/zxn/atlas0.bin"

        SECTION BANK_21
        BINARY  "build/zxn/atlas1.bin"

; The last bank has the pictures of pages 40 to 44 in its first page and, in its second (page 45, ICON_PAGE in plat_zxn.c), the tool icons: 14 of 22x20, a byte
; a pixel (a palette index)
        SECTION BANK_22
        BINARY  "build/zxn/atlas2.bin"

        IFDEF   HAVE_SCENARIOS
        INCLUDE "build/zxn/scenarios/scenarios.asm"
        ENDIF
