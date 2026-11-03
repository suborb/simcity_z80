# Einstein 256 memory layout

The Einstein 256 has 64 KB of CPU RAM and 192 KB of V9938 VRAM. The program is one CP/M COM in the
standard z88dk classic map (`target/einstein256/mmap.inc` includes `crt_section_standard.inc`); the only
fixed address is the overlay window.

## CPU RAM

| Address range | Use |
|---|---|
| `$0000–$00ff` | CP/M page zero (the BDOS entry is the word at `$0006`) |
| `$0100–BSS head` | the COM: crt, code, simulation, read-only tables, font, initialised data (about 31.9 KB) |
| BSS | uninitialised data, cleared by the crt before `main`, not in the file: mini maps, city map, the cooperative simulation stack, the compiler's (about 17.6 KB) |
| `OVERLAY_WINDOW` (`mmap.inc`) | the window the UI overlays run in, 4.4 KB (the larger of the two) |
| window end – BDOS | the CP/M and UI stack, growing down from the word at `$0006` (`ld sp,($0006)`) |

`tools/check_einstein_layout.py` (run by `make einstein256`; `EINSTEIN256_TPA_TOP` in the Makefile is the BDOS
entry it assumes) checks that the window is above the BSS and that window plus 512 bytes of stack fit under
the BDOS, and that both overlays fit in their VRAM store. If the BSS grows, it says what to set `OVERLAY_WINDOW` to.

The DOS did not load a COM that ended past `$8000` (observed: ends at `$7DC7`, `$7F5C` and `$7F6F` load, `$8153` did not), so keep the COM under 32 KB: a `-debug` build is about 400 bytes larger and the check only warns about it. The real BDOS entry (the word at `$0006`) is `$EB00` on DOS80 V1.0, not the `$E000` the checker assumes.

The crt clears the BSS from its start to its end before anything else: the BDOS entry must be above the end of the
BSS, or the stack the crt is using is cleared.

## Overlays and VRAM

| VRAM | Use |
|---|---|
| `$0000–$5fff` | Screen 5 display surface (192 lines) |
| `$6000–$7fff` | the overlays: `SIMCITY.GAM` then `SIMCITY.MOD`, each in whole 128-byte records |
| `$8000–$ffff` | the 32 KB graphics atlas from `TILES.DAT` |

Both overlays are linked at `OVERLAY_WINDOW`. At start-up the game reads `SIMCITY.GAM` and `SIMCITY.MOD` into the
window, copies each to VRAM, then restores the game overlay. `plat_overlay_load` copies the wanted one back (256-byte
VDP transfers). The sizes come from the link (`_einstein_game_size`, `_einstein_modal_size` in `einstein_io.asm`).

The game overlay is the minimap code, the mini map's tiles and row buffer, the menus, prompts, the city file
code and the text input; the modal overlay is the budget and evaluation screens. Nothing in an overlay may be
running when `plat_overlay_load` replaces it: the resident `game_budget` and `game_evaluation` load the modal
one and restore the game one before returning to their callers (which may be in the game overlay).

## The disc

`appmake +cpmdisk` copies the CP/M name into the directory unchanged, so the build passes `'TILES   DAT'` (the
11-byte FCB form). It writes a zero record count on the last entry of a file that is an exact multiple of 16 KB, so
`TILES.DAT` goes on with 128 spare bytes.

## DOS errors

The Einstein DOS answers a failed disc operation with `Try Again(Y/N)?` in its own text mode (invisible in screen 5; `N` is
a warm boot). Its BDOS keeps seven error handlers in a RAM table just after the entry jump (the word at `$0006`; DOS80 V1.0 at
`$EB00`, XtalDOS 2.05 at `$EA00`). `einstein_dos_quiet` (game overlay, run from `plat_init`) points them at
`einstein_dos_fail` (`einstein_io.asm`), which finishes the BDOS call with `$FF`, so `open`/`write`/`close` fail and the game shows
its own message; `plat_exit` restores them. A BDOS whose entry code does not have the expected shape is left alone.
