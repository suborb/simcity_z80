; The tool icons of the Amstrad CPC game (four cells each; see tools/extract_cpc_icons.py) and the line pieces of the boxes' frames.
        SECTION rodata_user
        PUBLIC  _mp_icons, _fp_box
_mp_icons:
        BINARY  "assets/cpc_icons.bin"
; Pipes two pixels thick with rounded corners: 1 top left, 2 top right, 3 bottom left, 4 bottom right, 5 across, 6 down (the codes below the space
; that the frames' strings in plat_config.h have)
_fp_box:
        defb    $00,$00,$00,$0F,$1F,$18,$18,$18
        defb    $00,$00,$00,$F0,$F8,$18,$18,$18
        defb    $18,$18,$18,$1F,$0F,$00,$00,$00
        defb    $18,$18,$18,$F8,$F0,$00,$00,$00
        defb    $00,$00,$00,$FF,$FF,$00,$00,$00
        defb    $18,$18,$18,$18,$18,$18,$18,$18
