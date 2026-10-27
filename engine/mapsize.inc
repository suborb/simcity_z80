; The size of the map, and what follows from it.  The default is the Spectrum's 96x96; a platform builds a bigger one with -DMAP_W=120 -DMAP_H=100
; (the Next).  The engine's code for 96x96 is, to the byte, what it was when 96 was written in it: the places that multiply by the width have
; the original shifts for 96 and others for 120.  Any other width stops the build (the symbol is undefined: see UNSUPPORTED_MAP_SIZE).
;
; The width must be a multiple of 8 (the power map's byte is 8 cells of a row, and the tile's offset divided by 8 is the bit's address), the
; height of 4 (the coverage maps are a cell to 4x4 tiles, the others to 2x2).
        IFNDEF  MAP_W
        defc    MAP_W = 96
        ENDIF
        IFNDEF  MAP_H
        defc    MAP_H = 96
        ENDIF
        defc    MAP_CELLS = MAP_W * MAP_H           ; the levelmap's bytes

; The minimaps (buffers.asm): fire and police coverage, a cell to 4x4 tiles; pollution and traffic, 2x2; the power map, a bit to a tile.
        defc    MM25_W = MAP_W / 4
        defc    MM25_H = MAP_H / 4
        defc    MM25_SIZE = MM25_W * MM25_H
        defc    MM50_W = MAP_W / 2
        defc    MM50_H = MAP_H / 2
        defc    MM50_SIZE = MM50_W * MM50_H
        defc    MM_POWER_ROW = MAP_W / 8
        defc    MMO_POWER_SIZE = MM_POWER_ROW * MAP_H

        defc    MMO_FIRE = 0
        defc    MMO_POLICE = MM25_SIZE
        defc    MMO_POLLUTION = 2 * MM25_SIZE
        defc    MMO_TRAFFIC = 2 * MM25_SIZE + MM50_SIZE
        defc    MMO_POWER = 2 * MM25_SIZE + 2 * MM50_SIZE
        defc    MM_BYTES = MMO_POWER + MMO_POWER_SIZE      ; the minimaps' bytes (6,912 at 96x96)

; The original map's power search was sized for 16 stations and 128 queued coordinate pairs. Portable builds share the power map as their
; visited bitmap and can refill a bounded queue from powered conductors. The Next's larger map can contain one station per 4x4 block, so reserve
; that capacity and a two-byte zero terminator.
; POWER_CITYWIDE: the power search that shares one capacity across the city (a bounded queue it refills, one map-wide scan), for the maps that have more than
; the original's 96x96 (and for test/power_scan, at any size).  The 96x96 builds keep the original search, one station at a time, to the byte.
        IF      MAP_W != 96
        defc    POWER_CITYWIDE = 1
        ELSE
        IFDEF   POWER_SCAN_TEST
        defc    POWER_CITYWIDE = 1
        ELSE
        defc    POWER_CITYWIDE = 0
        ENDIF
        ENDIF
        IF      MAP_W == 96
        defc    POWER_STATION_SLOTS = 16
        defc    POWER_STATION_LIST_BYTES = 32   ; preserve the original 96x96 layout exactly
        IFDEF   POWER_SCAN_TEST
        defc    POWER_QUEUE_BYTES = 16 ; force refill in the focused scan test
        ELSE
        defc    POWER_QUEUE_BYTES = 256         ; the original's
        ENDIF
        ELSE
        defc    POWER_STATION_SLOTS = (MAP_W / 4) * (MAP_H / 4)
        defc    POWER_STATION_LIST_BYTES = 2 * (POWER_STATION_SLOTS+1) ; include the zero terminator
        IFDEF   POWER_SCAN_TEST
        defc    POWER_QUEUE_BYTES = 16 ; force refill in the focused scan test
        ELSE
        defc    POWER_QUEUE_ENTRIES = (2 * 1350) + 2 ; bounded frontier; overflow triggers a map rescan/refill
        defc    POWER_QUEUE_BYTES = 2 * POWER_QUEUE_ENTRIES
        ENDIF
        ENDIF
