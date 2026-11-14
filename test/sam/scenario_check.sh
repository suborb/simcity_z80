#!/bin/sh
# The SAM's scenarios in MAME, in one run (make sam): 4 on the title screen shows the picker (the start-up overlay, ol_cur 3),
# the arrow keys change the scenario and its text, Enter reads the second one (Boston, 2010) from the disk: the city's map must be the file's (the map the simulation has had a short time to change),
# and the picker's snapshots are for looking at (the previews and the texts).  Usage: test/sam/scenario_check.sh (MAME in $SAM_MAME; SAM_BUILD defaults to build/sam)
D=$(cd "$(dirname "$0")" && pwd)
cd "$D/../.." || exit 1
B=${SAM_BUILD:-build/sam}
export SAMREADY=             # (these count absolute frames)
export SAMSHIFT=0            # (the frames in this script are for the big image already)
export SAMDISK=$PWD/$B/simcity.mgt
sym() { sed -n "s/^$1 *= \\\$\\([0-9A-Fa-f]*\\).*/\\1/p" $B/simcity.map; }
OL=$(sym ol_cur); YR=$(sym _V_year); LM=$(sym _levelmap)
W=${TMPDIR:-/tmp}/sam_scenario; mkdir -p $W; rm -f $W/map.bin
K="1000|kbd_3|4  \$|24,1150|kbd_8|Cursor Right|24,1300|kbd_8|Cursor Down|24,1450|kbd_6|Enter|24"   # (the 120 KB image takes until about frame 720 to load)
out=$(SAMDUMP="$LM:12000:$W/map.bin" SAMDUMPAT=1950 SAMMEM="1100:$OL,2000:$OL,2000:$YR" $D/go.sh "$K" "1100,1250,1400,2000" 2100 | grep "^peek-mem ")
echo "$out"
python3 - "$OL" "$YR" "$W/map.bin" "build/sam/scenarios/scen1" "${SAM_MAME:-$HOME/emu/mame0283-arm64}" <<PY
import sys
ol, yr, mapf, scen, mame = sys.argv[1].upper(), sys.argv[2].upper(), sys.argv[3], sys.argv[4], sys.argv[5]
vals = {}
for line in '''$out'''.splitlines():
    _, frame, addr, value = line.split()
    vals[(int(frame), addr.upper())] = int(value)
bad = 0
def check(name, ok, detail):
    global bad
    print(('PASS' if ok else 'FAIL') + f'  {name}: {detail}')
    bad += not ok
check('the picker has the start-up overlay', vals.get((1100, ol)) == 3, vals.get((1100, ol)))
check('and the city the game one', vals.get((2000, ol)) == 0, vals.get((2000, ol)))
got = open(mapf, 'rb').read()
want = open(scen, 'rb').read()[1500 + 2 + 512:]
diff = sum(1 for a, b in zip(got, want) if a != b)
check('the city is the second scenario\\'s map', len(got) == len(want) == 12000 and diff < 12000 * 0.01, f'{diff} of {len(want)} tiles differ from the file (the simulation has run a little)')
check('the year is 2010', vals.get((2000, yr)) in (2010 & 255, ), f'low byte {vals.get((2000, yr))} (2010 is {2010 & 255})')
print('snapshots (look at them): the picker (Bern), the next scenario, its text on the next page, the city, in', mame + '/snap/samcoupe')
sys.exit(1 if bad else 0)
PY
