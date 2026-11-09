#!/bin/sh
# MAME: build a road, save it as "test" on a copy of a Lynx disc image, build more, load it back; the map must come back as saved.
# Usage: test/lynx/roundtrip.sh [scratch dir]   (a copy of build/lynx/simcity.ldf, whose art the game loads itself: make lynx first; LYNX_DISC for another image)
D=$(cd "$(dirname "$0")" && pwd); R=$(cd "$D/../.." && pwd)
W=${1:-${TMPDIR:-/tmp}/lynx_roundtrip}; mkdir -p $W
A=$(sed -n 's/^_levelmap *= \$\([0-9A-Fa-f]*\).*/\1/p' $R/build/lynx/simcity.map)
M=${LYNX_MAME:-$HOME/emu/mame0283-arm64}
cp ${LYNX_DISC:-$R/build/lynx/simcity.ldf} $W/disk.ldf; rm -f $W/map_*.bin
B=""; f=1000; for i in 1 2 3 4 5 6 7 8 9 10 11 12; do B="$B,$f:Space:8,$((f+40)):Right:8"; f=$((f+90)); done
# 450 start (level 1), 900 pause, then a road; S (the slot list reads the disc), Return on <NEW FILE>, the name TEST, Return; more road; L, Return on the slot
KEYS="450:1 !:12,900:H GOSUB:10$B,2300:S STOP:10,3100:Return:10,3500:T TRACE:10,3600:E DATA:10,3700:S STOP:10,3800:T TRACE:10,4000:Return:10"
C=""; f=5200; for i in 1 2 3 4 5 6; do C="$C,$f:Space:8,$((f+40)):Down:8"; f=$((f+90)); done
KEYS="$KEYS$C,6100:L LIST:10,6900:Return:10"
cd $M && L_BIN=$R/build/lynx/simcity.bin L_ORG=0000 L_START=0000 L_ISR=0 L_AT=300 L_KEYS="${KEYS#,}" L_SNAPS="3000,3400,4900,6800,8250" L_DUMPS="5000:$A:9216:$W/map_saved.bin,5900:$A:9216:$W/map_modified.bin,8200:$A:9216:$W/map_loaded.bin" L_END=8300 ./mame lynx128k -rompath roms -flop1 $W/disk.ldf -window -nothrottle -seconds_to_run 600 -autoboot_script $D/inject.lua -snapshot_directory $R/snap > $W/mame.log 2>&1
python3 - $W <<'PY'
import sys
W=sys.argv[1]
a,b,c=(open(f'{W}/map_{n}.bin','rb').read() for n in ('saved','modified','loaded'))
mod=sum(x!=y for x,y in zip(a,b)); bad=sum(x!=y for x,y in zip(a,c))
print('modified vs saved differ in',mod,'tiles; loaded vs saved differ in',bad)
ok=len(a)==len(c)==9216 and mod>0 and bad==0
print('lynx file round trip:','ok' if ok else 'FAILED'); sys.exit(0 if ok else 1)
PY
