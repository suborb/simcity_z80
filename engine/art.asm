; ------------------------------------------------------------------------
; The Spectrum game's map graphics: the part of assets/udgs.bin (3764 bytes) that
; view_cell uses, cut out by tools/make_map_art.py as assets/map_art.bin (3105 bytes).
; The rest of udgs.bin is the Spectrum menus' icons and 123 unused bytes.
;
;   +0      map tiles, 8 bytes of 1bpp art each, tile numbers 0..93
;   +752    large-zone pieces, 8 bytes each (251)
;   +2760   one attribute byte per map tile       (Spectrum INK/PAPER/BRIGHT)
;   +2854   one attribute byte per large-zone piece
;
; In udgs.bin the same tables start at +536, +1288, +3296 and +3390.  The Spectrum
; build has the whole file in platform/zx/zx_udgs.asm.
; ------------------------------------------------------------------------
        defc    ART_TILES      = 0
        defc    ART_ZONES      = 752
        defc    ART_TILE_ATTRS = 2760
        defc    ART_ZONE_ATTRS = 2854

        IN_RODATA
view_udgs:
        BINARY  "assets/map_art.bin"
        IN_CODE
