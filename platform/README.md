# Platforms

| Directory | Status |
|---|---|
| `common/hooks.asm` | The settings and hooks the engine expects (`engine/PLATFORM_INTERFACE.md`), for C programs. |
| `console/` | z88dk conio and input front end for NC200 (`+nc -clib=nc200 -subtype=ram`). |
| `../target/aqplus/` | Aquarius+-specific implementation: 320x200 bitmap renderer, its UI capabilities and AQX CRT settings. |
| `../target/zx/` | Spectrum-specific implementation: fast 8x8 bitmap renderer, its UI capabilities and CRT settings. |
| `../target/zx-original/` | Reference Spectrum build: original UI segments and engine segments in original order; byte-identical to the disassembly. |
| `../target/z88/` | Z88-specific implementation: OZ screen/menu integration, icons, sound and ROM CRT settings. |
| `../target/test/` | Headless assembly platform: the engine with do-nothing hooks and a driver. Used by `test/golden`. A template for writing an assembly platform. |
| `../target/test_ui/` | Headless C platform: RAM screen and scripted keys for the game core. Used by `test/ui`. |

## Writing a platform

A C platform implements the functions in `ui/platform.h` and links
`ui/*.c`, `engine/engine_c.asm` (assembled with `-DPORTABLE`) and
`platform/common/hooks.asm`; the `Makefile` shows the command lines. To draw
the real tile graphics instead of characters, call `view_fetch()` for each
visible cell: it returns 8 bytes of art and an attribute, exactly as the
Spectrum draws them.

The engine keeps its variables and some self-modifying code inline, so the
program must run from RAM: the NC200 needs `-subtype=ram` (not a ROM card
image), and on the Z88 the program must be RAM-resident.

## Known limitations

* One `sim_tick()` is about 6 million T-states. The Spectrum hid this by
  running the simulation as a second task; here it blocks the UI for about
  two seconds on a 3.5 MHz machine (about one second on the NC200). The
  fix is to time-slice `process_ric_zones`, which is a loop over 96 rows.
* The annual budget is automatic (`V_auto_budget = 1`); there is no budget
  dialog yet, nor evaluation, minimap, disaster options, save/load or sound.
* The shared UI draws characters; the tile graphics path is in the engine
  (`view_cell`) and tested, but no platform uses it yet.
