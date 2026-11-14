#!/bin/sh
# The SAM's pointer in MAME (no mouse there: only the keys move it), in one run: each key held for 20 frames moves the arrow the right way, and Shift makes it go about
# twice as far.  The pointer's x and y (plat_mouse_x, plat_mouse_y: 0..255 by 0..191, so their low bytes) are read after each try.  Usage: test/sam/pointer_check.sh
# (MAME in $SAM_MAME; make sam first).  The same run also checks the mini map's panning: the pointer put by SAMPOKES at the picture's edges, the window's position after each, and the picture
# panned against the one drawn whole at the same place (the snapshots).
D=$(cd "$(dirname "$0")" && pwd)
cd "$D/../.." || exit 1
B=${SAM_BUILD:-build/sam}
export SAMDISK=$PWD/$B/simcity.mgt
sym() { sed -n "s/^$1 *= \\\$\\([0-9A-Fa-f]*\\).*/\\1/p" $B/simcity.map; }
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
# the panning (a 120x100 build): the pointer is put by poking plat_mouse_x and plat_mouse_y (16 bits each: the next look sends it to the hardware)
SX=$(sym _mm_scroll_x); SY=$(sym _mm_scroll_y)
SNAPS=""; POKES=""; PAN=""
if [ -n "$SX" ]; then
    PAN=$f
    le() { printf '%02x%02x' $(( $1 & 255 )) $(( $1 >> 8 )); }
    ptr() { POKES="$POKES,$1:$PX=$(le $2),$1:$PY=$(le $3)"; }
    peek() { MEM="$MEM,$1:$SX,$1:$SY"; }
    CXA=$(sym _cur_x)
    ptr $(( f - 40 )) 100 4                             # the pointer in the status panel (over the map it puts the cursor under it at each pass of the loop) ...
    POKES="$POKES,$(( f - 10 )):$CXA=1414"              # ... so that the cursor can be put at 20, 20: the mini map opens with its window at 0, 0
    KEYS="$KEYS,$(( f + 0 ))|kbd_7|m  M|8"
    peek $(( f + 40 ))
    ptr $(( f + 50 )) 187 96;  peek $(( f + 400 ))     # the right edge: the window goes right a tile every few passes of the loop, to column 24
    ptr $(( f + 405 )) 96 190; peek $(( f + 500 ))     # the bottom edge: down, to row 4
    ptr $(( f + 505 )) 96 96;  peek $(( f + 520 ))     # the middle again: it stays
    SNAPS="$(( f + 525 ))"                              # (1) panned to 24, 4
    KEYS="$KEYS,$(( f + 530 ))|kbd_7|Space|8"          # fire: the city, the cursor at the tile in the middle of the window
    KEYS="$KEYS,$(( f + 560 ))|kbd_7|m  M|8"           # and the mini map opened again, drawn whole there
    peek $(( f + 650 ))
    SNAPS="$SNAPS $(( f + 655 ))"                      # (2) the same, drawn whole
    ptr $(( f + 660 )) 2 96;  peek $(( f + 1000 ))    # the left edge: to column 0
    ptr $(( f + 1005 )) 96 2;  peek $(( f + 1100 ))    # the top edge: to row 0
    ptr $(( f + 1105 )) 96 96; peek $(( f + 1120 ))
    SNAPS="$SNAPS $(( f + 1125 ))"                      # (3) panned to 0, 0
    KEYS="$KEYS,$(( f + 1130 ))|kbd_7|Space|8,$(( f + 1160 ))|kbd_7|m  M|8"
    peek $(( f + 1250 ))
    SNAPS="$SNAPS $(( f + 1255 ))"                      # (4) drawn whole there
    f=$(( f + 1280 ))
fi
out=$(SAMPOKES="${POKES#,}" SAMMEM="$MEM" $D/go.sh "$KEYS" "$SNAPS" $(( f + 20 )) | grep "^peek-mem ")
python3 - "$WANT" "$PX" "$PY" "$MAPF" "$MV" "$CX" "$PAN" "$SX" "$SY" "${SAM_MAME:-$HOME/emu/mame0283-arm64}" <<PY
import sys
want, px, py = sys.argv[1].split('|')[1:], sys.argv[2].upper(), sys.argv[3].upper()
mapf, mv, cx = int(sys.argv[4]), sys.argv[5].upper(), sys.argv[6].upper()
pan, sx, sy, mame = sys.argv[7], sys.argv[8].upper(), sys.argv[9].upper(), sys.argv[10]
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
if pan:
    f = int(pan)
    def at(off):
        return vals[(f + off, sx)], vals[(f + off, sy)]
    check('the mini map opens at 0, 0 (the cursor at 20, 20)', at(40) == (0, 0), at(40))
    check('the window goes right to column 24', at(400)[0] == 24, at(400))
    check('and down to row 4', at(500) == (24, 4), at(500))
    check('the pointer in the middle: it stays', at(520) == (24, 4), at(520))
    check('the mini map opened again at the tile in the middle of the window is at the same place', at(650) == (24, 4), at(650))
    check('the window goes left to column 0', at(1000)[0] == 0, at(1000))
    check('and up to row 0', at(1100) == (0, 0), at(1100))
    check('opened again at the middle tile: 0, 0', at(1250) == (0, 0), at(1250))
    try:
        from PIL import Image
        import glob, os
        shots = sorted(glob.glob(os.path.join(mame, 'snap/samcoupe/*.png')))[-4:]
        ims = [Image.open(p).convert('RGB') for p in shots]
        def differ(a, b):
            w, h = a.size
            box = (0, 0, w * 3 // 4, h)          # (the picture: 192 of the 256 pixels across; the sidebar has the clock and the cursor)
            pa, pb = a.crop(box).load(), b.crop(box).load()
            n = sum(pa[x, y] != pb[x, y] for x in range(box[2]) for y in range(h))
            return n / (box[2] * h)
        for name, i, j in (('panned to 24, 4 against drawn whole there', 0, 1), ('panned to 0, 0 against drawn whole there', 2, 3)):
            d = differ(ims[i], ims[j])
            check(name, d < 0.02, f'{d * 100:.2f}% of the picture pixels differ ({os.path.basename(shots[i])} and {os.path.basename(shots[j])})')
    except Exception as e:
        print('FAIL  snapshots could not be compared:', e)
        bad += 1
sys.exit(1 if bad else 0)
PY
