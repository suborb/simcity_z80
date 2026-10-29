#!/bin/sh
# x1go.sh keys snaps end: one headless MAME run of the X1 build (X1_MAME = the MAME directory); the snapshots are in snap/x1/
S=$(cd "$(dirname "$0")" && pwd)
cd ${X1_MAME:-$HOME/emu/mame0283-arm64} && rm -rf snap/x1
X1KEYS="$1" X1SNAPS="$2" X1END="$3" ./mame x1 -flop1 ${X1DISK:-/Users/dom/Projects/simcity_z80/build/x1/simcity.d88} -video soft -window -nothrottle -seconds_to_run 300 -autoboot_script $S/keys.lua -skip_gameinfo 2>&1 | grep "pc=\|error\|Error"
ls snap/x1
