#!/bin/sh
# Run every automated check:
#   1. the Spectrum build assembled from the split files is byte-identical to the original
#   2. the portable engine behaves exactly like the original (simulation, tools, map view),
#      and writes nothing below the start of its RAM sections (so it can run from ROM)
#   3. the game core, with the engine, plays correctly under scripted keys
#   4. every platform builds
# Needs z88dk (Z88DK, default ~/z88dk).
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
echo "== ZX Spectrum tile drawing: every picture through the real console code"
python3 test/tiles/run.py
python3 test/tiles/run.py --print
echo
echo "== Z88 menus agree with the commands the game understands"
python3 test/z88/run.py
echo
echo "== UI: game core under scripted keys"
python3 test/ui/run.py | grep -E "^(PASS|FAIL)|passed|FAILED"
echo
echo "== builds"
for t in aqplus nc200 z88 z88rom zx zx-print; do make -s $t >/dev/null && echo "built $t"; done
