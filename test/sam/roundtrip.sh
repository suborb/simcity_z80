#!/bin/sh
# Save a city (with a road built in it) as the file "test" on a copy of the disk, then load it into a fresh game from the copy:
# the two screens must show the same map and the same funds (MAME, test/sam/go.sh).  Usage: test/sam/roundtrip.sh
D=$(cd "$(dirname "$0")" && pwd)
W=${TMPDIR:-/tmp}/sam_roundtrip; mkdir -p $W
cp build/sam/simcity.mgt $W/disk.mgt
typ() { K=""; f=$1; shift; for k in "$@"; do K="$K,$f|${k}|8"; f=$((f+40)); done; echo "$K"; }
SNAP=${SAM_MAME:-$HOME/emu/mame0283-arm64}/snap/samcoupe
# the cursor may start on water, where nothing can be built: a row of cells is tried
B=""; f=1500; for i in 1 2 3 4 5 6 7 8 9 10 11 12; do B="$B,$f|kbd_7|Space|8,$((f+40))|kbd_8|Cursor Right|8"; f=$((f+80)); done
K1="700|kbd_3|1  !|10$B,2600|kbd_1|s  S|8$(typ 2800 'kbd_2|t  T  ]' 'kbd_2|e  E' 'kbd_1|s  S' 'kbd_2|t  T  ]' 'kbd_6|Enter')"
MAPADDR=$(sed -n 's/^_levelmap *= \$\([0-9A-Fa-f]*\).*/\1/p' build/sam/simcity.map)
SAMDUMP="$MAPADDR:9216:$W/map_saved.bin" SAMDUMPAT=2590 SAMDISK=$W/disk.mgt $D/go.sh "$K1" "2560,3450" 3500 >/dev/null; cp $SNAP/0000.png $W/saved_city.png; cp $SNAP/0001.png $W/after_save.png
K2="700|kbd_3|1  !|10,1800|kbd_6|l  L  £|8$(typ 2000 'kbd_2|t  T  ]' 'kbd_2|e  E' 'kbd_1|s  S' 'kbd_2|t  T  ]' 'kbd_6|Enter')"
SAMDUMP="$MAPADDR:9216:$W/map_loaded.bin" SAMDUMPAT=2750 SAMPEEK="$PEEK" SAMDISK=$W/disk.mgt $D/go.sh "$K2" "1760,2700" ${END2:-2800} | grep peek; cp $SNAP/0000.png $W/fresh_city.png; cp $SNAP/0001.png $W/after_load.png
python3 - $W <<'PY'
import sys
from PIL import Image, ImageChops
W=sys.argv[1]
def region(n, box):
    return Image.open(f'{W}/{n}.png').convert('RGB').crop(box)
FUNDS=(30 + 144, 34, 30 + 304, 34 + 16)     # "$nnnnn" on the panel's first row (columns 9 to 18)
PANEL=(30, 34, 546, 34 + 24)
def diff(a, b):
    return sum(1 for p in ImageChops.difference(a, b).convert('L').tobytes() if p > 40)
saved, fresh, loaded = (region(n, FUNDS) for n in ('saved_city', 'fresh_city', 'after_load'))
print('funds: saved vs loaded', diff(saved, loaded), '(0 if the money came back); saved vs fresh', diff(saved, fresh), '(not 0: the road cost money)')
ms, ml = open(f'{W}/map_saved.bin', 'rb').read(), open(f'{W}/map_loaded.bin', 'rb').read()
bad = sum(1 for x, y in zip(ms, ml) if x != y)
roads = sum(1 for x in ms if x in (7,))
print('map: the saved city and the loaded one differ in', bad, 'of', len(ms), 'tiles (0 if the whole map came back);', 'the map has', roads, 'road tiles' if roads else 'NO road tiles: the test built nothing')
ok = diff(saved, loaded) == 0 and diff(saved, fresh) != 0 and bad == 0 and len(ms) == len(ml) == 9216
print('sam file round trip:', 'ok' if ok else 'FAILED')
sys.exit(0 if ok else 1)
PY
