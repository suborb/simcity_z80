#!/bin/sh
# The SAM's pointer in MAME (no mouse there: only the keys move it), in one run: each key held for 20 frames moves the arrow the right way, and Shift makes it go about
# twice as far.  The pointer's x and y (plat_mouse_x, plat_mouse_y: 0..255 by 0..191, so their low bytes) are read after each try.  Usage: test/sam/pointer_check.sh
# (MAME in $SAM_MAME; make sam first)
D=$(cd "$(dirname "$0")" && pwd)
cd "$D/../.." || exit 1
sym() { sed -n "s/^$1 *= \\\$\\([0-9A-Fa-f]*\\).*/\\1/p" build/sam/simcity.map; }
PX=$(sym _plat_mouse_x); PY=$(sym _plat_mouse_y)
# each try is 120 frames: its keys, then a look at the pointer 100 frames in.  The pointer starts in the middle of the map, so the tries alternate to stay away from the edges.
KEYS="700|kbd_3|1  !|10"
MEM="1490:$PX,1490:$PY"
WANT=""
f=1500
try() {   # name, then keys as "offset|port|field|length" (offsets from the try's start)
    name=$1; shift
    for k in "$@"; do KEYS="$KEYS,$(( f + ${k%%|*} ))|${k#*|}"; done
    MEM="$MEM,$(( f + 100 )):$PX,$(( f + 100 )):$PY"
    WANT="$WANT|$name"
    f=$(( f + 120 ))
}
try "p moves right"             "0|kbd_5|p  P|20"
try "o moves left"              "0|kbd_5|o  O|20"
try "shift and p, faster"       "0|kbd_0|Shift|30" "0|kbd_5|p  P|20"
try "q moves up"                "0|kbd_2|q  Q  <|20"
try "a moves down"              "0|kbd_1|a  A|20"
try "cursor right moves right"  "0|kbd_8|Cursor Right|20"
try "cursor left moves left"    "0|kbd_8|Cursor Left|20"
try "cursor up moves up"        "0|kbd_8|Cursor Up|20"
try "cursor down moves down"    "0|kbd_8|Cursor Down|20"
try "shift and o, back to the middle" "0|kbd_0|Shift|30" "0|kbd_5|o  O|20"
try "nothing held"              "0|kbd_0|Shift|2"
# the mini map: M shows it, then fire on its picture (the pointer is where the tries left it) goes to that tile and shows the city again
MV=$(sym _map_view); CX=$(sym _cur_x)
KEYS="$KEYS,$(( f + 0 ))|kbd_7|m  M|8,$(( f + 60 ))|kbd_7|Space|8"
MEM="$MEM,$(( f - 10 )):$CX,$(( f + 50 )):$MV,$(( f + 110 )):$MV,$(( f + 110 )):$CX"
MAPF=$f
f=$(( f + 120 ))
out=$(SAMMEM="$MEM" $D/go.sh "$KEYS" "" $(( f + 20 )) | grep "^peek-mem ")
python3 - "$WANT" "$PX" "$PY" "$MAPF" "$MV" "$CX" <<PY
import sys
want, px, py = sys.argv[1].split('|')[1:], sys.argv[2].upper(), sys.argv[3].upper()
mapf, mv, cx = int(sys.argv[4]), sys.argv[5].upper(), sys.argv[6].upper()
vals = {}
for line in '''$out'''.splitlines():
    _, frame, addr, value = line.split()   # (peek-mem frame addr value)
    vals[(int(frame), addr.upper())] = int(value)
frame, prev, moved, bad = 1490, (vals[(1490, px)], vals[(1490, py)]), {}, 0
for name in want:
    now = (vals[(frame + 110, px)], vals[(frame + 110, py)])
    d = (now[0] - prev[0], now[1] - prev[1])
    moved[name] = d
    prev, frame = now, frame + 120
def check(name, ok, detail):
    global bad
    print(('PASS' if ok else 'FAIL') + f'  {name}: the arrow moved {detail}')
    bad += not ok
check('p moves right', moved['p moves right'][0] > 8 and moved['p moves right'][1] == 0, moved['p moves right'])
check('o moves left', moved['o moves left'][0] < -8 and moved['o moves left'][1] == 0, moved['o moves left'])
slow, fast = moved['p moves right'][0], moved['shift and p, faster'][0]
check('shift makes it about twice as far', slow > 0 and 1.6 * slow <= fast <= 2.4 * slow, f'{fast} against {slow}')
for name, axis, sign in (('q moves up', 1, -1), ('a moves down', 1, 1), ('cursor right moves right', 0, 1), ('cursor left moves left', 0, -1),
                         ('cursor up moves up', 1, -1), ('cursor down moves down', 1, 1)):
    d = moved[name]
    check(name, d[axis] * sign > 8 and d[1 - axis] == 0, d)
check('nothing held: it stays', moved['nothing held'] == (0, 0), moved['nothing held'])
shown, back = vals[(mapf + 50, mv)], vals[(mapf + 110, mv)]
check('M shows the mini map and fire on it shows the city again', shown != 0 and back == 0, f'map view {shown}, then {back}')
check('fire on the mini map puts the cursor on that tile', vals[(mapf + 110, cx)] != vals[(mapf - 10, cx)], f'cursor column {vals[(mapf - 10, cx)]}, then {vals[(mapf + 110, cx)]}')
sys.exit(1 if bad else 0)
PY
