#!/bin/sh
# The SAM's shifted keys in MAME, in one run: the cursor keys and the letters Q, A, O, P go eight cells with the shift, one without.  The
# cursor's column and row are read after each try.  Usage: test/sam/shift_check.sh   (MAME in $SAM_MAME; make sam first)
D=$(cd "$(dirname "$0")" && pwd)
cd "$D/../.." || exit 1
sym() { sed -n "s/^$1 *= \\\$\\([0-9A-Fa-f]*\\).*/\\1/p" build/sam/simcity.map; }
CX=$(sym _cur_x); CY=$(sym _cur_y)
# each try is 120 frames: its keys, then a look at the cursor 100 frames in.  dx, dy wanted.
KEYS="700|kbd_3|1  !|10"
MEM="1490:$CX,1490:$CY"
WANT=""
f=1500
try() {   # name, dx, dy, then keys as "offset|port|field|length" (offsets from the try's start)
    name=$1; dx=$2; dy=$3; shift 3
    for k in "$@"; do KEYS="$KEYS,$(( f + ${k%%|*} ))|${k#*|}"; done
    MEM="$MEM,$(( f + 100 )):$CX,$(( f + 100 )):$CY"
    WANT="$WANT|$name:$dx:$dy"
    f=$(( f + 120 ))
}
try "cursor right"                1  0  "0|kbd_8|Cursor Right|8"
try "shift, cursor right"         8  0  "0|kbd_0|Shift|60" "10|kbd_8|Cursor Right|8"
try "shift and cursor in one frame" 0 8 "0|kbd_0|Shift|20" "0|kbd_8|Cursor Down|8"
try "cursor, shift while held"    -1 0  "0|kbd_8|Cursor Left|40" "20|kbd_0|Shift|20"
try "shift, cursor up"            0 -8  "0|kbd_0|Shift|60" "10|kbd_8|Cursor Up|8"
try "p"                           1  0  "0|kbd_5|p  P|8"
try "shift, p"                    8  0  "0|kbd_0|Shift|60" "10|kbd_5|p  P|8"
try "shift, o"                   -8  0  "0|kbd_0|Shift|60" "10|kbd_5|o  O|8"
try "shift, q"                    0 -8  "0|kbd_0|Shift|60" "10|kbd_2|q  Q  <|8"
try "shift, a"                    0  8  "0|kbd_0|Shift|60" "10|kbd_1|a  A|8"
try "o"                          -1  0  "0|kbd_5|o  O|8"
out=$(SAMMEM="$MEM" $D/go.sh "$KEYS" "" $(( f + 20 )) | grep "^peek-mem ")
python3 - "$WANT" "$CX" "$CY" <<PY
import sys
want, cx, cy = sys.argv[1].split('|')[1:], sys.argv[2], sys.argv[3]
vals = {}
for line in '''$out'''.splitlines():
    _, frame, addr, value = line.split()   # (peek-mem frame addr value)
    vals[(int(frame), addr.upper())] = int(value)
cx, cy = cx.upper(), cy.upper()
frame, prev = 1490, (vals[(1490, cx)], vals[(1490, cy)])
bad = 0
for w in want:
    name, dx, dy = w.rsplit(':', 2)
    now = (vals[(frame + 110, cx)], vals[(frame + 110, cy)])
    got = (now[0] - prev[0], now[1] - prev[1])
    ok = got == (int(dx), int(dy))
    print(('PASS' if ok else 'FAIL') + f'  {name}: the cursor moved {got}' + ('' if ok else f', wanted ({dx}, {dy})'))
    bad += not ok
    prev, frame = now, frame + 120
sys.exit(1 if bad else 0)
PY
