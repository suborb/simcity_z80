# Sim City Z80

This is a work-in-progress disassembly of the ZX Spectrum version of Sim City.

## Background

This disassembly was started back in 2000 with the aim of porting the whole
game to the z88.

## Analysis

As can be seen with the NES version (and presumably others as well), the
game consists of two processes:

* A UI process, responsible for handling user input and rendering the display
* A simulation process

This separation should make it possible to retarget the engine to run on any
Z80 based computer.



## Layout

| Path | What |
|---|---|
| `disassembly/` | The Spectrum disassembly. Kept as a faithful reference: comments and extra labels only; `test/golden/run.py` checks that nothing else changes. |
| `engine/` | The simulation and tool logic extracted from it as a platform-independent engine (`engine/PLATFORM_INTERFACE.md`). |
| `ui/` | The shared game user interface, in C, written against the small platform API in `ui/platform.h`. |
| `target/zx-original/` | The original Spectrum build, assembled from the engine and original UI code; byte-identical to the disassembly. |
| `platform/console/` | NC200 z88dk console and keyboard front end. |
| `target/aqplus/` | Aquarius+-specific platform implementation: bitmap renderer, capabilities and AQX CRT settings. |
| `target/zx/` | Spectrum-specific platform implementation: bitmap renderer, capabilities and CRT settings. |
| `target/z88/` | Z88-specific implementation: OZ integration, icons, sound and ROM CRT settings. |
| `platform/common/` | Settings and hooks the engine needs, for C programs. |
| `target/test/` | Headless assembly platform used by the golden-master tests. |
| `target/test_ui/` | Headless C platform used by the UI tests. |
| `tools/` | `split_engine.py` (extract the engine), `extract_text.py` (generate `ui/text.h` and `ui/text.c`), `find_dead.py`, `make_map_art.py`, `make_z88_icons.py` (the tool icons as Z88 characters). |
| `Makefile` | Builds every platform (`make zx`, `make aqplus`, ...) and runs the tests (`make check`). |
| `test/` | `run_all.sh` runs everything. |
| `PORTING.md` | Strategy, status and plan. |

## Building and testing

Needs [z88dk](https://z88dk.org).

    make aqplus     # Aquarius+   -> build/aqplus/simcity.aqx
    make nc200      # NC200       -> build/nc200/SIMCITY.COM
    make z88        # Z88         -> build/z88/SIMCITY.BAS
    make z88rom     # Z88 ROM application, 32 KB card image -> build/z88rom/simcity.epr
    make zx         # ZX Spectrum -> build/zx/simcity.tap
    make check      # golden master, tile drawing, UI tests, all builds

z88dk's tools (`zcc`, `z88dk-z80asm`, `z88dk-ticks`) must be on the `PATH`.

The ZX Spectrum build has been played; the Aquarius+, NC200 and Z88 builds compile
and link but have not yet been run on hardware or an emulator.
