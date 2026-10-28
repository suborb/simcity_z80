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
; build has the whole file in target/zx-original/zx_udgs.asm.
;
; The Aquarius+ build (TARGET_AQPLUS) has assets/map_art_aq.bin instead: the same, with the attribute bytes
; converted to the colour bytes its bitmap wants (tools/make_aq_assets.py), so view_fetch's attribute goes
; straight to the screen.
; ------------------------------------------------------------------------
        defc    ART_TILES      = 0
        defc    ART_ZONES      = 752
        defc    ART_TILE_ATTRS = 2760
        defc    ART_ZONE_ATTRS = 2854

        IFDEF   TARGET_ZXN
        defc    ART_UNREAD = 1
        ENDIF
        IFDEF   TARGET_SAM
        defc    ART_UNREAD = 1
        ENDIF
        IFDEF   TARGET_PC88
        defc    ART_UNREAD = 1
        ENDIF
        IFDEF   TARGET_MULTI8
        defc    ART_UNREAD = 1
        ENDIF
        IFDEF   ART_UNREAD              ; the Next, the SAM, the PC-88 and the Multi 8 draw their own pictures: they number them by the art's address (art - view_tile_art) and never read the art
                                        ; itself, so only the attribute bytes are stored; the art's 2,760 bytes are an address range with nothing in it (not at 0: the SAM's cache
                                        ; holds the art's address, and an empty cache entry is 0)
        defc    view_udgs = $0100
        SECTION rodata_user
view_attrs:
        BINARY  "assets/map_attrs.bin"
        ELSE
        IFDEF   RODATA_IN_RAM           ; (the Z88's console reads the art with the map bank paged over $4000-$7FFF: it stays in ROM)
        SECTION rodata_user
        ELSE
        IN_RODATA
        ENDIF
view_udgs:
        IFDEF   TARGET_AQPLUS
        BINARY  "assets/map_art_aq.bin"
        ELSE
        BINARY  "assets/map_art.bin"
        ENDIF
        defc    view_attrs = view_udgs + ART_TILE_ATTRS
        ENDIF
        IN_CODE
