#!/bin/sh
# The SAM's UI overlays in MAME, in one run (SAM_OVERLAYS: target/sam/mmap.inc): the title screen (the start-up overlay) is up at frame 600, the budget and evaluation screens (the modal one)
# are opened and closed, and the popup menu and the file dialogue (the game's) are used; ol_cur (plat_sam.asm), the overlay that is in the window, is read at each step, the screens are
# snapshotted (snap/samcoupe: look at them) and the city must come back as it was.  Usage: test/sam/overlay_check.sh (MAME in $SAM_MAME; SAM_BUILD for another build directory)
D=$(cd "$(dirname "$0")" && pwd)
cd "$D/../.." || exit 1
B=${SAM_BUILD:-build/sam}
export SAMDISK=$PWD/$B/simcity.mgt
sym() { sed -n "s/^$1 *= \\\$\\([0-9A-Fa-f]*\\).*/\\1/p" $B/simcity.map; }
OL=$(sym ol_cur); FR=$(sym _frame)
[ -n "$OL" ] || { echo "no ol_cur in $B/simcity.map: build with SAM_OVERLAYS=1"; exit 1; }
K="700|kbd_3|1  !|10"
K="$K,1650|kbd_7|b  B|24,1800|kbd_3|Esc|24"          # the budget, and out of it
K="$K,1900|kbd_0|v  V|24,2050|kbd_3|Esc|24"          # the evaluation
K="$K,2150|kbd_3|Esc|24,2300|kbd_3|Esc|24"           # the popup menu
K="$K,2400|kbd_1|s  S|24,2550|kbd_3|Esc|24"          # the file dialogue
MEM="700:$OL,1600:$OL,1750:$OL,1850:$OL,1990:$OL,2100:$OL,2250:$OL,2350:$OL,2500:$OL,2650:$OL,2700:$FR,2820:$FR"
out=$(SAMMEM="$MEM" $D/go.sh "$K" "1600,1750,1850,1990,2100,2250,2500,2700" 2850 | grep "^peek-mem ")
python3 - "$OL" "$FR" "${SAM_MAME:-$HOME/emu/mame0283-arm64}" <<PY
import sys, glob, os
ol, fr, mame = sys.argv[1].upper(), sys.argv[2].upper(), sys.argv[3]
vals = {}
for line in '''$out'''.splitlines():
    _, frame, addr, value = line.split()
    vals[(int(frame), addr.upper())] = int(value)
bad = 0
def check(name, ok, detail):
    global bad
    print(('PASS' if ok else 'FAIL') + f'  {name}: {detail}')
    bad += not ok
def o(f):
    return vals.get((f, ol))
check('the title screen has the start-up overlay', o(700) == 3, o(700))
check('the city has the game overlay', o(1600) == 0, o(1600))
check('the budget has the modal overlay', o(1750) == 1, o(1750))
check('and the city the game one again', o(1850) == 0, o(1850))
check('the evaluation has the modal overlay', o(1990) == 1, o(1990))
check('the popup menu has the game overlay', o(2100) == 0 and o(2250) == 0, (o(2100), o(2250)))
check('the file dialogue has the game overlay', o(2500) == 0 and o(2650) == 0, (o(2500), o(2650)))
check('the game loop is running at the end', vals.get((2820, fr)) != vals.get((2700, fr)), (vals.get((2700, fr)), vals.get((2820, fr))))
try:
    from PIL import Image
    shots = sorted(glob.glob(os.path.join(mame, 'snap/samcoupe/*.png')))
    ims = [Image.open(p).convert('RGB') for p in shots]
    def differ(a, b):
        pa, pb = a.load(), b.load()
        w, h = a.size
        return sum(pa[x, y] != pb[x, y] for x in range(w) for y in range(h)) / (w * h)
    d = differ(ims[0], ims[2])
    check('the city after the budget is the city before it', d < 0.05, f'{d * 100:.2f}% of the pixels differ ({os.path.basename(shots[0])} and {os.path.basename(shots[2])})')
    print('snapshots (look at them):', ', '.join(os.path.basename(p) for p in shots), 'in', os.path.join(mame, 'snap/samcoupe'), ': city, budget, city, evaluation, menu, file dialogue (the 2250 one is after the menu is closed), then the city')
except Exception as e:
    print('FAIL  snapshots could not be compared:', e)
    bad += 1
sys.exit(1 if bad else 0)
PY
