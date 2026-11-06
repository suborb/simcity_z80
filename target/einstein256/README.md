# Tatung Einstein 256 target

Build the CP/M disk with `make einstein256`: `SIMCITY.COM` (the whole program), `SIMCITY.GAM` and `SIMCITY.MOD`
(the UI overlays, which the start-up keeps in VRAM and copies into one CPU window as needed) and `TILES.DAT`
(the graphics atlas, loaded into VRAM) and `SIMCITY.SND` (the sound effects and player, loaded at start-up).

The older 80cc is needed while the compiler's size regression stands (the current one makes the code larger):

```sh
PATH=/private/tmp/old80bin:/Users/dom/z88dk/bin:$PATH make einstein256 \
    ZCC='zcc -compiler=80cc -fframe-pointer'
```

The memory map is in [`docs/EINSTEIN256-layout.md`](../../docs/EINSTEIN256-layout.md). It boots and runs (reported 2026-11-03): the mini maps, the budget and the evaluation screens work, so the CP/M file
reads and the VDP overlay copies are good. Not yet checked: save/load of a city, the title and scenario screens,
sound (the AY, from `SIMCITY.SND`: it builds, not yet run), and the TPA top on a real machine (`EINSTEIN256_TPA_TOP` in the Makefile assumes $E000).
