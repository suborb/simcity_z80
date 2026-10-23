#!/bin/sh
# Run every automated check:
#   1. the Spectrum build assembled from the split files is byte-identical to the original
#   2. the portable engine behaves exactly like the original (simulation, tools, map view),
#      and writes nothing below the start of its RAM sections (so it can run from ROM)
#   3. the game core, with the engine, plays correctly under scripted keys
#   4. every platform builds
# Needs z88dk's tools on the PATH.
set -e
cd "$(dirname "$0")/.."
echo "== golden master: engine vs original Spectrum program"
python3 test/golden/run.py --ticks 60 --views
echo
echo "== golden master again, ticking in cooperative slices (sim_step)"
python3 test/golden/run.py --ticks 60 --views --coop
echo
echo "== engine is ROM-clean: no stores into its own code"
python3 tools/find_dead.py --smc
echo
echo "== FINE_ZONE_LEVELS: the engine with a picture for every growth level (the CPC game's)"
python3 test/fine_zones/run.py
echo
echo "== ZX Spectrum tile drawing: every picture through the real console code"
python3 test/tiles/run.py
echo
echo "== Aquarius+ glyph placer and colour tables"
python3 test/aqplus/run.py
echo
echo "== Multi 8 placer: three planes, paging and colours"
python3 test/multi8/run.py
echo
echo "== PC-8801 placer: plane paging and the ALU, V1 and V2"
python3 test/pc88/run.py
echo
echo "== PC-8801 file routines and the file name editor (a disk in memory, scripted keys)"
python3 test/pc88/files.py
echo
echo "== PC-8801 disk routines against the real disk unit (MAME; skipped without PC88_ROMS)"
python3 test/pc88/disk.py
echo
echo "== z88dk's Multi 8 tape routines (tape_save, tape_load_to)"
python3 test/multi8/tape.py
echo
echo "== the Z88's sound routines"
python3 test/sound/run.py
echo
echo "== number printing"
python3 test/fmt/run.py
echo
echo "== Z88 menus agree with the commands the game understands"
python3 test/z88/run.py
echo
echo "== UI: game core under scripted keys"
python3 test/ui/run.py | grep -E "^(PASS|FAIL)|passed|FAILED"
echo
echo "== builds"
status=0
for t in aqplus z88rom zx multi8; do
    if make -s $t >/dev/null 2>&1; then echo "built $t"; else echo "FAIL  build $t"; status=1; fi
done
exit $status
