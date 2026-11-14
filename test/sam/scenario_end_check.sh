#!/bin/sh
# The end of a scenario's time in MAME, a run for each outcome (the game's own check, game_scenario_end: the goal at the end of the years): a build whose scenarios are over at once
# (make SAM=build/samtest/simcity.mgt SAM_TEST=-DSCENARIO_YEARS_TEST build/samtest/simcity.mgt).  The scenario is chosen on the picker (Enter for the first, Bern, whose goal is
# traffic; Left then Enter for the last, Tokyo, whose goal is the city score above 500), the message is on the screen (the modal overlay, ol_cur 1), Enter takes it away and the game goes on.
# The snapshots (the message, then the city) are for looking at.  Usage: test/sam/scenario_end_check.sh (MAME in $SAM_MAME; SAM_BUILD defaults to build/samtest)
D=$(cd "$(dirname "$0")" && pwd)
cd "$D/../.." || exit 1
B=${SAM_BUILD:-build/samtest}
export SAMREADY=             # (these count absolute frames)
export SAMSHIFT=0            # (the frames in this script are for the big image already)
export SAMDISK=$PWD/$B/simcity.mgt
sym() { sed -n "s/^$1 *= \\\$\\([0-9A-Fa-f]*\\).*/\\1/p" $B/simcity.map; }
OL=$(sym ol_cur); FR=$(sym _frame)
bad=0
run() {   # name, how many frames later than Bern the message comes, keys that choose the scenario
    name=$1; d=$2; shift; shift
    K="1000|kbd_3|4  \$|24$1"
    # the scenario is read and its first tick finished (the time is up at once) by about 1500 frames after Enter, then the message; Enter takes it away
    out=$(SAMMEM="$((3300+d)):$OL,$((3300+d)):$FR,$((3350+d)):$FR,$((3700+d)):$OL,$((3800+d)):$FR,$((3860+d)):$FR" $D/go.sh "$K,$((3400+d))|kbd_6|Enter|24" "$((3300+d)),$((3700+d)),$((3800+d))" $((3900+d)) | grep "^peek-mem ")
    echo "== $name"; echo "$out"
    python3 - "$OL" "$FR" "$d" <<PY
import sys
ol, fr, d = sys.argv[1].upper(), sys.argv[2].upper(), int(sys.argv[3])
v = {}
for line in '''$out'''.splitlines():
    _, f, a, x = line.split()
    v[(int(f), a.upper())] = int(x)
def check(n, ok, d): print(('PASS' if ok else 'FAIL') + f'  {n}: {d}'); return ok
ok = check('the message has the modal overlay', v.get((3300 + d, ol)) == 1, v.get((3300 + d, ol)))
ok &= check('the game waits for the key', v.get((3300 + d, fr)) == v.get((3350 + d, fr)), (v.get((3300 + d, fr)), v.get((3350 + d, fr))))
ok &= check('and goes on after it, with the game overlay', v.get((3700 + d, ol)) == 0 and v.get((3800 + d, fr)) != v.get((3860 + d, fr)), (v.get((3700 + d, ol)), v.get((3800 + d, fr)), v.get((3860 + d, fr))))
sys.exit(0 if ok else 1)
PY
    [ $? -eq 0 ] || bad=1
    mkdir -p ${TMPDIR:-/tmp}/sam_end; for n in 0000 0001 0002; do cp ${SAM_MAME:-$HOME/emu/mame0283-arm64}/snap/samcoupe/$n.png ${TMPDIR:-/tmp}/sam_end/$name-$n.png 2>/dev/null; done
}
run bern 0 ",1150|kbd_6|Enter|24"
run tokyo 400 ",1150|kbd_8|Cursor Left|24,1300|kbd_6|Enter|24"
echo "snapshots: ${TMPDIR:-/tmp}/sam_end/{bern,tokyo}-000{0,1,2}.png (the message, ..., the city after it)"
exit $bad
