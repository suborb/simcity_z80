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
| `platform/zx/` | The Spectrum build, assembled from the engine and the original UI code; byte-identical to the disassembly. |
| `platform/console/` | z88dk console and keyboard front end used by the Aquarius+, NC200 and Z88 builds. |
| `platform/common/` | Settings and hooks the engine needs, for C programs. |
| `platform/test`, `platform/test_ui/` | Headless platforms used by the tests. |
| `tools/` | `split_engine.py` (extract the engine), `extract_text.py` (generate `ui/text.h`), `build.sh`. |
| `test/` | `run_all.sh` runs everything. |
| `PORTING.md` | Strategy, status and plan. |

## Building and testing

Needs [z88dk](https://z88dk.org).

    tools/build.sh aqplus     # Aquarius+   -> build/aqplus/simcity.caq
    tools/build.sh nc200      # NC200       -> build/nc200/SIMCITY.COM
    tools/build.sh z88        # Z88         -> build/z88/SIMCITY.BAS
    test/run_all.sh           # golden master, UI tests, all builds

The three machine builds compile and link, but have not yet been run on
hardware or an emulator.
