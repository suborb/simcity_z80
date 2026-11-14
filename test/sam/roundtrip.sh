#!/bin/sh
# Save a city and load it again, through the popup menu (Esc), in MAME (test/sam/go.sh; the clock of the scripts is counted from when the game is up: script frame 1400):
#  1. build a road, save the city as "test" on a copy of the disk (MENU: SAVE CITY, <NEW FILE>, the name), and note the map and the funds;
#  2. a fresh game from the copy: LOAD CITY, the file: the map and the funds must be what was saved;
#  3. the same game, but from a new city (MENU: NEW CITY, a level) after the save: LOAD CITY must bring back the saved city over the new one.
# The file module has a length check (plat_file_list lists only files of a city's length), so a file of the wrong length is not offered.
# Usage: test/sam/roundtrip.sh (MAME in $SAM_MAME; SAM_BUILD=build/sam by default)
D=$(cd "$(dirname "$0")" && pwd)
cd "$D/../.." || exit 1
W=${TMPDIR:-/tmp}/sam_roundtrip; mkdir -p $W; rm -f $W/*.bin $W/*.png
BD=${SAM_BUILD:-build/sam}
cp $BD/simcity.mgt $W/disk.mgt
cp $BD/simcity.mgt $W/disk3.mgt
SNAP=${SAM_MAME:-$HOME/emu/mame0283-arm64}/snap/samcoupe
sym() { sed -n "s/^$1 *= \\\$\\([0-9A-Fa-f]*\\).*/\\1/p" $BD/simcity.map; }
MAPADDR=$(sym _levelmap); MONEY=$(sym _V_money); FRAME=$(sym _frame)
export SAMMAP=$PWD/$BD/simcity.map
# keys: key frame name... (each held 24 frames, 100 apart from the frame)
typ() { K=""; f=$1; shift; for k in "$@"; do K="$K,$f|${k}|24"; f=$((f+100)); done; echo "$K"; }
ESC='kbd_3|Esc'; DOWN='kbd_8|Cursor Down'; ENTER='kbd_6|Enter'; T='kbd_2|t  T  ]'; E='kbd_2|e  E'; S='kbd_1|s  S'
# the cursor may start on water, where nothing can be built: a row of cells is tried
B=""; f=1500; for i in 1 2 3 4 5 6 7 8 9 10 11 12; do B="$B,$f|kbd_7|Space|24,$((f+60))|kbd_8|Cursor Right|24"; f=$((f+120)); done
SAVE="$(typ 3050 "$ESC" "$DOWN" "$DOWN" "$ENTER")$(typ 3700 "$ENTER" "$T" "$E" "$S" "$T" "$ENTER")"
K1="700|kbd_3|1  !|10$B$SAVE"
SAMDISK=$W/disk.mgt SAMDUMP="$MAPADDR:12000:$W/map_saved.bin" SAMDUMPAT=3040 SAMMEM="3040:$MONEY,3041:$((0x$MONEY+1)),3042:$((0x$MONEY+2))" $D/go.sh "$K1" "3040,4700" 4750 >/dev/null 2>&1
cp $SNAP/0000.png $W/saved_city.png; cp $SNAP/0001.png $W/after_save.png
# 2. a fresh game: load it
LOAD="$(typ 1500 "$ESC" "$DOWN" "$DOWN" "$DOWN" "$ENTER")$(typ 2300 "$ENTER")"
K2="700|kbd_3|1  !|10$LOAD"
SAMDISK=$W/disk.mgt SAMDUMP="$MAPADDR:12000:$W/map_loaded.bin" SAMDUMPAT=3000 $D/go.sh "$K2" "1450,2900" 3050 >/dev/null 2>&1
cp $SNAP/0000.png $W/fresh_city.png; cp $SNAP/0001.png $W/after_load.png
# 3. the same game: after the save, a new city (MENU: NEW CITY, level 1), then LOAD CITY over it
NEWC="$(typ 4500 "$ENTER")$(typ 4650 "$ESC" "$DOWN" "$DOWN" "$DOWN" "$DOWN" "$DOWN" "$DOWN" "$DOWN" "$ENTER")"
LOAD3="$(typ 7900 "$ESC" "$DOWN" "$DOWN" "$DOWN" "$ENTER")$(typ 8700 "$ENTER")"
K3="700|kbd_3|1  !|10$B$SAVE$NEWC,5600|kbd_3|1  !|24$LOAD3"
SAMDISK=$W/disk3.mgt SAMDUMP="$MAPADDR:12000:$W/map_new.bin" SAMDUMPAT=7800 SAMDUMP2="$MAPADDR:12000:$W/map_loaded3.bin" SAMDUMP2AT=9500 $D/go.sh "$K3" "5600,7800,9500" 9550 >/dev/null 2>&1
cp $SNAP/0000.png $W/new_menu.png; cp $SNAP/0001.png $W/new_city.png; cp $SNAP/0002.png $W/after_load3.png
python3 - $W <<'PY'
import sys
from PIL import Image, ImageChops
W=sys.argv[1]
def diff(a, b):
    return sum(1 for p in ImageChops.difference(a, b).convert('L').tobytes() if p > 40)
ms, ml = open(f'{W}/map_saved.bin', 'rb').read(), open(f'{W}/map_loaded.bin', 'rb').read()
bad = sum(1 for x, y in zip(ms, ml) if x != y)
roads = sum(1 for x in ms if x in (7, 8))
print('map: the saved city and the loaded one differ in', bad, 'of', len(ms), 'tiles;', roads, 'road tiles in the saved one' if roads else 'NO road tiles: the test built nothing')
panel = (30, 34, 546, 34 + 24)
a, b = Image.open(f'{W}/after_save.png').convert('RGB').crop(panel), Image.open(f'{W}/after_load.png').convert('RGB').crop(panel)
print('status panel (date, funds): after the save against after the load differs in', diff(a, b), 'pixels (the date may have moved on)')
ok = bad == 0 and roads > 0 and len(ms) == len(ml) == 12000
mn, m3 = open(f'{W}/map_new.bin', 'rb').read(), open(f'{W}/map_loaded3.bin', 'rb').read()
differ_new = sum(1 for x, y in zip(ms, mn) if x != y)
bad3 = sum(1 for x, y in zip(ms, m3) if x != y)
print('via a new city: the new city differs from the saved one in', differ_new, 'tiles (it must: else nothing was tested); after LOAD CITY the saved city and the loaded one differ in', bad3, 'tiles')
ok = ok and differ_new > 100 and bad3 == 0
print('sam file round trip:', 'ok' if ok else 'FAILED')
sys.exit(0 if ok else 1)
PY
