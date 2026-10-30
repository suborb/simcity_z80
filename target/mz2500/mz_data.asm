; The palette, the attribute colours and the animations' tables (tools/st_tiles_3bpp.py --mz2500 makes mz2500.inc), and the picture atlas as the pages the IPL loads.
        MODULE  mz_data
        SECTION rodata_user
        INCLUDE "mz2500.inc"

        SECTION RODATA_22
        BINARY  "TILES.BIN"
        SECTION code_user
