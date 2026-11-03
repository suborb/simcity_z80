; The standard classic map: CP/M loads one COM at $0100 holding the code, the read-only tables and the initialised
; data; the BSS follows it (CRT_INITIALIZE_BSS clears it) and is not in the file.
    INCLUDE "crt/classic/crt_section_standard.inc"

; The two UI overlays are linked at the same address, in a window above the BSS.  They are not in the COM: the build
; writes each to a file (SIMCITY.GAM, SIMCITY.MOD), the start-up reads them into the window and keeps them in VRAM, and
; plat_overlay_load copies the one wanted back.  tools/check_einstein_layout.py checks that the window is above the BSS
; and that the window and the stack fit under the BDOS.
    defc    OVERLAY_WINDOW = $C700
    SECTION EINSTEIN_GAME_OVL
    org     OVERLAY_WINDOW
    SECTION EINSTEIN_MODAL_OVL
    org     OVERLAY_WINDOW
