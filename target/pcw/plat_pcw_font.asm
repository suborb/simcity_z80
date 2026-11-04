; The 8x8 text font of the PCW build: the SPC-1000's (characters 32 to 96; a lower case letter is drawn as its capital).
        SECTION rodata_user
        PUBLIC  _pcw_font
_pcw_font:
        INCLUDE "target/spc1000/font8x8.inc"

; The tool icons: the Spectrum's, four 8x8 pictures each (top left, top right, bottom left, bottom right: the first 448 bytes of assets/udgs.bin)
        PUBLIC  _pcw_icons
_pcw_icons:
        BINARY  "build/pcw/icons.bin"
