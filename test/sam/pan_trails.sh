#!/bin/sh
# The pointer on a mini map that pans (a 120x100 build): the pointer is held at the picture's right edge, so the window pans, and the picture is snapshotted while it does and after
# it stops; the arrow must be one arrow, not a trail of them.  (Look at the snapshots; the script counts the pixels of the arrow's colour outside a box round the pointer.)
# Usage: test/sam/pan_trails.sh (MAME in $SAM_MAME)
D=$(cd "$(dirname "$0")" && pwd)
cd "$D/../.." || exit 1
B=${SAM_BUILD:-build/sam}
export SAMREADY=             # (these count absolute frames)
export SAMSHIFT=0            # (the frames in this script are for the big image already)
export SAMDISK=$PWD/$B/simcity.mgt
sym() { sed -n "s/^$1 *= \\\$\\([0-9A-Fa-f]*\\).*/\\1/p" $B/simcity.map; }
PX=$(sym _plat_mouse_x); PY=$(sym _plat_mouse_y); CXA=$(sym _cur_x); SX=$(sym _mm_scroll_x)
le() { printf '%02x%02x' $(( $1 & 255 )) $(( $1 >> 8 )); }
f=1500
KEYS="700|kbd_3|1  !|10,$f|kbd_7|m  M|24"
POKES="$(( f - 40 )):$PX=$(le 100),$(( f - 40 )):$PY=$(le 4),$(( f - 10 )):$CXA=1414,$(( f + 60 )):$PX=$(le 187),$(( f + 60 )):$PY=$(le 96),$(( f + 600 )):$PX=$(le 96),$(( f + 600 )):$PY=$(le 150)"
SNAPS="$(( f + 150 )) $(( f + 300 )) $(( f + 450 )) $(( f + 700 ))"
SAMPOKES="$POKES" SAMMEM="$(( f + 150 )):$SX,$(( f + 450 )):$SX,$(( f + 700 )):$SX" $D/go.sh "$KEYS" "$SNAPS" $(( f + 720 )) | grep "^peek-mem "
echo "snapshots: the window panning right with the pointer at the picture's right edge (3), then the pointer taken away (1)"
