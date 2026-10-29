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


### Layout

| Path | What |
|---|---|
| `disassembly/` | The Spectrum disassembly. Kept as a faithful reference: comments and extra labels only; `test/golden/run.py` checks that nothing else changes. |
| `engine/` | The simulation and tool logic extracted from it as a platform-independent engine (`engine/PLATFORM_INTERFACE.md`). |
| `ui/` | The shared game user interface, in C, written against the small platform API in `ui/platform.h`. |
| `target/zx-original/` | The original Spectrum build, assembled from the engine and original UI code; byte-identical to the disassembly. |
| `platform/common/` | Settings and hooks the engine needs, for C programs. |
| `platform/console/` | z88dk console and keyboard front end. |
| `target/aqplus/` | Aquarius+-specific platform implementation: bitmap renderer, AY sound, capabilities and AQX CRT settings. |
| `target/common/` | Code shared between targets: the AY/SAA sound-effect player and hooks, line editor, mini map, icon and chart drawing. |
| `target/multi8/` | Mitsubishi Multi 8: planar bitmap renderer, PSG sound, tape (.cas) image. |
| `target/pc88/` | NEC PC-8801: ALU/bank-switched renderer, D88 disk image. |
| `target/sam/` | SAM Coupe: allram layout with paged data, SAA 1099 sound, MGT disk image with save/load. |
| `target/z88/` | Z88-specific implementation: OZ integration (the menus and their `<>` shortcuts, a framed 7-row text window), tool icons (greyed out when unaffordable), demand bars, sound and ROM CRT settings. |
| `target/zx/` | Spectrum-specific platform implementation: bitmap renderer, capabilities and CRT settings. |
| `target/zxn/` | ZX Spectrum Next: the program at $0000 with its own start-up and NEX packaging, Layer 2 graphics in the ST art's 16 colours, AY sound from the frame interrupt, esxDOS save/load. |
| `target/test/` | Headless assembly platform used by the golden-master tests. |
| `target/test_ui/` | Headless C platform used by the UI tests. |
| `assets/` | Binary art and sound data used by the targets (tiles, icons, `st_sounds.bin`). |
| `tools/` | `extract_text.py` (generate `ui/text.h` and `ui/text.c`), `find_dead.py`, `make_map_art.py`, `make_z88_icons.py`, the `extract_*` and `make_*assets` scripts that build `assets/` from the Atari ST and CPC versions (the ST sound effects are packed by `extract_st_sounds.py` and played by `target/common/ay_sfx.asm`). |
| `Makefile` | Builds every platform (`make zx`, `make aqplus`, ...) and runs the tests (`make check`). |
| `test/` | `run_all.sh` runs everything (the SAM MAME tests only when `SAM_MAME` is set, the Next's JNext tests only when `JNEXT` is). |
| `PORTING.md` | Strategy, status and plan. |

### Building and testing

Needs [z88dk](https://z88dk.org).

    make aqplus     # Aquarius+   -> build/aqplus/simcity.aqx (the loader) and simcity.bin (the game; keep them together)
    make z88rom     # Z88 ROM application, 32 KB card image -> build/z88rom/simcity.epr
    make zx         # ZX Spectrum -> build/zx/simcity.tap (incomplete)
    make multi8     # Multi 8     -> build/multi8/simcity.cas
    make pc88       # PC-8801     -> build/pc88/simcity.d88
    make sam        # SAM Coupe   -> build/sam/simcity.mgt
    make zxn       # ZX Spectrum Next -> build/zxn/simcity.nex
    make check      # golden master, tile drawing, UI tests, all builds

z88dk's tools (`zcc`, `z88dk-z80asm`, `z88dk-ticks`) must be on the `PATH`.

