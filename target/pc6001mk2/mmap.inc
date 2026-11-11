; The standard classic map: the program, its read-only tables and its initialised data are the flat image the boot sector loads at $0000 (tracks 1-11 of the disc); the
; uninitialised data follows at CRT_ORG_BSS (not in the image: CRT_INITIALIZE_BSS clears it).
    INCLUDE "crt/classic/crt_section_standard.inc"

; The UI overlays (ui/platform.h: PLAT_CODE_GAME_OVERLAY, PLAT_CODE_MODAL_OVERLAY ...; target/pc6001mk2/plat_config.h gives the sections) are linked at the same address, in a window above the
; uninitialised data: OVERLAY_0 the game's, 1 the budget's, 2 the file dialogues', 3 the start-up's, 4 the evaluation's.  z88dk (-subtype=mk2disc) writes each as a file (simcity_OVERLAY_n.bin), puts them
; on the disc after the program (appmake +pc6001mk2) and reads one into the window with pc6001mk2_overlay_load(n).  The boot sector does not load them: plat_init loads the game overlay.
; The Makefile checks that the window is above the uninitialised data and that it and the stack (under $C000, the VRAM) fit.
    defc    OVERLAY_WINDOW = $B0F0
    SECTION OVERLAY_0
    org     OVERLAY_WINDOW
    SECTION OVERLAY_1
    org     OVERLAY_WINDOW
    SECTION OVERLAY_2
    org     OVERLAY_WINDOW
    SECTION OVERLAY_3
    org     OVERLAY_WINDOW
    SECTION OVERLAY_4
    org     OVERLAY_WINDOW
