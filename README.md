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

The following targets are available. 

| Machine | Graphics | Sound | Save/load | Mouse | Scenarios |
|---|---|---|---|---|---|
| Amstrad PCW | ZX | none | disc | no | no |
| Aquarius+ | ZX | ST (AY) | SD (ESP32) | yes | no |
| Cambridge z88 | ZX | 1-bit | RAM filing | no | no |
| Camputers Lynx 128K | CPC | ST (DAC) | disc | no | no |
| Casio FP-1100 | CPC | none | disc | no | no |
| Mitsubishi Multi8 | CPC | ST (PSG) | tape | no | no |
| MSX2 | ST | ST (PSG) | disc | yes | no |
| NEC PC-6001mkII | ZX | custom (PSG) | disc | no | no |
| NEC PC-88 | CPC | none | disc | no | no |
| Sam Coupe | ST | ST (SAA 1099) | disc | yes | no |
| Samsung SPC-1000 | ZX | ST (AY) | tape | no | no |
| Samsung SPC-1500 | CPC | ST (AY) | tape | no | no |
| Sharp MZ-2500 | ST | ST (SSG) | disc | yes | no |
| Sharp MZ-800 | ZX | ST (SN76489) | disc | no | no |
| Sharp X1 | CPC | ST (PSG) | disc | no | no |
| Sony SMC-777 | CPC | none | disc | no | no |
| Tatung Einstein 256 | ST | ST (AY) | disc | no | no |
| Toshiba Pasopia 7 | CPC | ST (SN76489) | disc | no | no |
| ZX Spectrum Next | Amiga | ST (AY) | SD (esxDOS) | yes | yes |

The generic CP/M build (`make cpm`) is text only: a character a square, saved to disc, no sound, mouse or scenarios.


### Layout

| Path | What |
|---|---|
| `disassembly/` | The Spectrum disassembly. Kept as a faithful reference: comments and extra labels only; `test/golden/run.py` checks that nothing else changes. |
| `engine/` | The simulation and tool logic extracted from it as a platform-independent engine (`engine/PLATFORM_INTERFACE.md`). |
| `ui/` | The shared game user interface, in C, written against the small platform API in `ui/platform.h`. |
| `target/zx-original/` | The original Spectrum build, assembled from the engine and original UI code; byte-identical to the disassembly. |
| `platform/common/` | Settings and hooks the engine needs, for C programs. |
| `platform/console/` | z88dk console and keyboard front end. |
| `target/common/` | Code shared between targets: the pointer (keys and mouse), the AY/SAA sound-effect player and hooks, line editor, mini map, icon and chart drawing, the V9938 core (`v9938/`). |
| `target/*/` | Target specific code |
| `target/test/` | Headless assembly platform used by the golden-master tests. |
| `target/test_ui/` | Headless C platform used by the UI tests. |
| `assets/` | Binary art and sound data used by the targets (tiles, icons, `st_sounds.bin`). |
| `tools/` | `extract_text.py` (generate `ui/text.h` and `ui/text.c`), `find_dead.py`, `make_map_art.py`, `make_z88_icons.py`, the `extract_*` and `make_*assets` scripts that build `assets/` from the Atari ST and CPC versions (the ST sound effects are packed by `extract_st_sounds.py` and played by `target/common/ay_sfx.asm`). |
| `Makefile` | Builds every platform (`make zx`, `make aqplus`, ...) and runs the tests (`make check`). |
| `test/` | `run_all.sh` runs everything (the SAM MAME tests only when `SAM_MAME` is set, the Next's JNext tests only when `JNEXT` is; the Lynx's `test/lynx/*_test.py` run under z88dk-ticks on z88dk's `lib/ticks/memory/lynx.lua` and `wd1793.lua`, and `test/lynx/roundtrip.sh` is the MAME save/load check; the Pasopia 7's `test/pasopia7/*_test.py` run on z88dk's `lib/ticks/memory/pasopia7.lua` and `upd765.lua`; the PC-6001mkII's `test/pc6001mk2/*_test.py` run on z88dk's `lib/ticks/memory/pc6001mk2.lua`; the MZ-800's `test/mz800/*_test.py` run on z88dk's `lib/ticks/memory/mz800.lua`, and the ones that boot the game need the 16 KB MZ-800 monitor ROM, `MZ800_ROM`). |
| `PORTING.md` | Strategy, status and plan. |

### Building and testing

Needs [z88dk](https://z88dk.org).

    make [target]  # Build that target
    make check      # golden master, tile drawing, UI tests, all builds

z88dk's tools (`zcc`, `z88dk-z80asm`, `z88dk-ticks`) must be on the `PATH`.

