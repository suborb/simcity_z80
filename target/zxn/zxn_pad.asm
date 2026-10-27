; Padding, so that the program's data starts at ZXN_DATA ($8A00: the Makefile).  The engine's bank is mapped over $4000 to $7FFF while the simulation
; runs, so what the simulation reads and writes, the variables and its tables, must be at $8000 or above, and the program is a single image: the data
; follows the code and the tables, wherever they end.  The Makefile links twice: the first time says where they end, and this many bytes (ZXN_PAD) is
; what the second adds, at the start of the data (data_driver is the first of the data sections).
        MODULE  zxn_pad
        IFNDEF  ZXN_PAD
        defc    ZXN_PAD = 0
        ENDIF
        SECTION data_driver
        defs    ZXN_PAD
