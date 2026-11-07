# Sim City Z80

This is a work-in-progress disassembly of the ZX Spectrum version of Sim City.

## Background

This disassembly was started back in 2000 with the aim of porting the whole
game to the z88. Sufficient information has been determined to allow porting
of the engine to other z80 machines.



## Analysis

As can be seen with the NES version (and presumably others as well), the
game consists of two processes:

* A UI process, responsible for handling user input and rendering the display
* A simulation process

On the Spectrum this is achieved by im2 based task swapping.

This clear separation has made it possible to retarget the engine to run on multiple z80 based computers.

## Comparison with CPC z80 engine

The CPC also had a port of SimCity. Small changes were made to the simulation engine as a result
of more memory being available:

* ZX had 4/4/4 evolution points for RIC zones, CPC had 8/8/10
* As a result ZX had 345 8x8 glyps, and CPC had 471
* Warning thresholds are different: 
    * Pollution 40 on the CPC against 60 on the ZX
    * Crime 30 against 20
    * Traffic 42 against 60. 
    * The "need" (more zones) message is sent 25 zone imbalance against 19.
* Pollution average: This is calculated differently 
* Other changes in growth logic

## Rebuild

The rebuild utilises the original simulation engine and assets. Instead of being interrupt based, the
simulation and UI cooperatively multitask which allows porting to hardware where an interrupt source
is not available.

The following targets are available:

* Amstrad PCW
* Aquarius+
* Cambridge z88
* Casio FP-1100
* Mitsubishi Multi8
* MSX
* NEC PC-88
* Sam Coupe
* Samsung SPC-1000
* Sharp MZ-2500
* Sharp X1
* Tatung Einstein 256
* ZX Spectrum Next




### Layout

| Path | What |
|---|---|
| `disassembly/` | The Spectrum disassembly. Kept as a faithful reference: comments and extra labels only; `test/golden/run.py` checks that nothing else changes. |
| `engine/` | The simulation and tool logic extracted from it as a platform-independent engine (`engine/PLATFORM_INTERFACE.md`). |
| `ui/` | The shared game user interface, in C, written against the small platform API in `ui/platform.h`. |
| `target/zx-original/` | The original Spectrum build, assembled from the engine and original UI code; byte-identical to the disassembly. |
| `platform/common/` | Settings and hooks the engine needs, for C programs. |
| `platform/console/` | z88dk console and keyboard front end. |
| `target/aqplus/` | Aquarius+-specific platform implementation: bitmap renderer with the Spectrum's art in colour, hardware sprite pointer and mouse, 4bpp mini maps, AY sound, save/load, capabilities and AQX CRT settings. |
| `target/common/` | Code shared between targets: the pointer (keys and mouse), the AY/SAA sound-effect player and hooks, line editor, mini map, icon and chart drawing, the V9938 core (`v9938/`). |
| `target/multi8/` | Mitsubishi Multi 8: planar bitmap renderer (pictures baked from the `TILESET` art, the CPC game's by default), PSG sound, tape (.cas) image. |
| `target/pc88/` | NEC PC-8801: ALU/bank-switched renderer (the same baked pictures as the Multi 8), D88 disk image. |
| `target/sam/` | SAM Coupe: allram layout with paged data, the Atari ST's art, animated tiles, a software arrow pointer and mouse, SAA 1099 sound, MGT disk image with save/load. |
| `target/z88/` | Z88-specific implementation: OZ integration (the menus and their `<>` shortcuts, a framed 7-row text window), tool icons (greyed out when unaffordable), demand bars, sound and ROM CRT settings. |
| `target/spc1000/` | Samsung SPC-1000: MC6847 256x192 mono and 128x192 colour (mini maps) through I/O ports, AY sound, cassette save/load in the ROM's format (z88dk's tape_save/tape_load_to), a packed program with a bootstrap that unpacks it. |
| `target/msx2/` | MSX2 under MSX-DOS 2: screen 5 with the Atari ST's art copied by the VDP out of an atlas in video RAM (the drawing core is shared with the Einstein 256, `target/common/v9938/`), the code in two mapper segments (UI and simulation) switched into page 2, PSG sound from `H.TIMI` (in page 3), a mouse in a joystick connector, DOS file save/load. |
| `target/mz2500/` | Sharp MZ-2500: 320x200 in 16 colours on planar video RAM (the Atari ST's art in a planar atlas, tiles blitted through borrowed 8 KB windows), banked UI and simulation code, YM2203 sound, SIO mouse and keyboard pointer, boot disk image whose last cylinders hold 8 save slots (floppy controller driven directly by z88dk's mz2500_disk_rw). 96x96 map, no scenarios. |
| `target/fp1100/` | Casio FP-1100 on its own boot disc (no CP/M): 320x200 in eight colours on three planes of video RAM that belong to the sub-CPU, drawn by a small program the game loads into it and drives a byte at a time (maps, text and icons as pictures kept in the sub-CPU's RAM), the CPC art baked for the Multi 8, a polled uPD765A driver (z88dk's `fp1100_disk_read`/`write`), 8 save slots on the boot disc, mini maps, no sound or scenarios. Built by z88dk's `+fp1100 -subtype=allram`; see `docs/FP1100.md`. |
| `target/x1/` | Sharp X1: the 320x200 colour screen behind I/O ports (the pictures baked for the PC-8801, from the `TILESET` art), PSG sound, keyboard from the sub CPU's interrupt, 2D disk image with save/load (z88dk's x1_disk_read/x1_disk_write). |
| `target/zx/` | Spectrum-specific platform implementation: bitmap renderer, capabilities and CRT settings. |
| `target/zxn/` | ZX Spectrum Next: the program at $0000 with its own start-up and NEX packaging, Layer 2 graphics from the Amiga SimCity 1 Meg's art (the 512K's with `ZXN_TILES`/`ZXN_ICONS`), a hardware sprite pointer and mouse, AY sound from the frame interrupt, esxDOS save/load. |
| `target/einstein256/` | Tatung Einstein 256 under CP/M: V9938 screen 5 with the Atari ST's art, as the MSX2 (`target/common/v9938/`); the program in a COM with two UI overlays (`SIMCITY.GAM`, `SIMCITY.MOD`, kept in video RAM and copied in as needed), a sound file (`SIMCITY.SND`) and the `TILES.DAT` atlas, AY sound, CP/M file save/load. See its README. |
| `target/pcw/` | Amstrad PCW under CP/M Plus: the 720x256 monochrome bitmap as a 40x32 grid of 16x8 cells (each 8x8 tile drawn twice across), the Spectrum's icons, popup menus, no sound. |
| `target/cpm/` | A generic CP/M text target (80x24 characters): no graphics or sound, CP/M file save/load. |
| `target/test/` | Headless assembly platform used by the golden-master tests. |
| `target/test_ui/` | Headless C platform used by the UI tests. |
| `assets/` | Binary art and sound data used by the targets (tiles, icons, `st_sounds.bin`). |
| `tools/` | `extract_text.py` (generate `ui/text.h` and `ui/text.c`), `find_dead.py`, `make_map_art.py`, `make_z88_icons.py`, the `extract_*` and `make_*assets` scripts that build `assets/` from the Atari ST and CPC versions (the ST sound effects are packed by `extract_st_sounds.py` and played by `target/common/ay_sfx.asm`). |
| `Makefile` | Builds every platform (`make zx`, `make aqplus`, ...) and runs the tests (`make check`). |
| `docs/` | Memory maps and handover notes for some targets (not every file is tracked). |
| `test/` | `run_all.sh` runs everything (the SAM MAME tests only when `SAM_MAME` is set, the Next's JNext tests only when `JNEXT` is). |
| `PORTING.md` | Strategy, status and plan. |

### Building and testing

Needs [z88dk](https://z88dk.org).

    make aqplus     # Aquarius+   -> build/aqplus/simcity.aqx (the loader) and simcity.bin (the game; keep them together)
    make z88rom     # Z88 ROM application, 32 KB card image -> build/z88rom/simcity.epr
    make zx         # ZX Spectrum -> build/zx/simcity.tap (incomplete)
    make multi8     # Multi 8     -> build/multi8/simcity.cas
    make pc88       # PC-8801     -> build/pc88/simcity.d88
    make pcw        # Amstrad PCW -> build/pcw/simcity.dsk (CP/M Plus)
    make cpm        # generic CP/M text -> build/cpm/simcity.com
    make einstein256 # Tatung Einstein 256 -> build/einstein256/simcity.dsk
    make fp1100     # Casio FP-1100 -> build/fp1100/simcity.d88 (a boot disc; needs a z88dk with the fp1100 allram subtype and appmake --data)
    make x1         # Sharp X1   -> build/x1/simcity.d88
    make spc1000    # Samsung SPC-1000 -> build/spc1000/simcity.spc
    make msx2       # MSX2 (MSX-DOS 2) -> build/msx2/simcity.dsk and disk/ (SIMCITY.COM, .UI, .SIM, .HI and TILES.DAT: all five are needed)
    make mz2500     # Sharp MZ-2500 -> build/mz2500/simcity.dsk (needs a z88dk with the mz2500 --low appmake and disk driver)
    make sam        # SAM Coupe   -> build/sam/simcity.mgt
    make zxn       # ZX Spectrum Next -> build/zxn/simcity.nex
    make check      # golden master, tile drawing, UI tests, all builds

z88dk's tools (`zcc`, `z88dk-z80asm`, `z88dk-ticks`) must be on the `PATH`.

