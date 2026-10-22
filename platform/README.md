# Platforms

| Directory | Status |
|---|---|
| `common/hooks.asm` | The settings and hooks the engine expects (`engine/PLATFORM_INTERFACE.md`), for C programs. |
| `console/` | z88dk conio and input front end for NC200 (`+nc -clib=nc200 -subtype=ram`). |
| `../target/aqplus/` | Aquarius+-specific implementation: 320x200 bitmap renderer, its UI capabilities and AQX CRT settings. |
| `../target/multi8/` | Mitsubishi Multi 8 implementation: 640x200 three plane colour screen, baked colour pictures, cassette, native pixel mini maps. |
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

The Spectrum build of the engine keeps its variables and some self-modifying code inline, so it must run from RAM.
The portable build (`-DPORTABLE`, which every platform here uses) has no self-modifying code and puts its tables, code
and variables in sections of their own (`engine/sections.asm`), so a platform can keep the code in ROM (the Z88); the
NC200 build still needs `-subtype=ram` (not a ROM card image).

## Notes

* The simulation runs in slices (`sim_step()`, one map row each; `engine/coop.asm`), so a platform's frame loop stays
  responsive between them; `ui/game.c` does the scheduling, so a platform only draws and reads keys.
* What a platform draws is up to it: characters (`plat_put`), the engine's own 8x8 pictures (`view_fetch()`, which
  returns 8 bytes of art and an attribute as the Spectrum draws them: `HAVE_TILES`), or its own versions of them (the
  Aquarius+'s colour bytes, the Multi 8's baked colours).  The optional features (budget, evaluation, mini maps, sprites,
  files, sound) are switched on in the platform's `plat_config.h`; `ui/platform.h` says what each needs.
* A platform without them has the annual budget automatic (`V_auto_budget = 1`).
