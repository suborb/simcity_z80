#!/bin/sh
# samgo.sh keys snaps end
S=$(cd "$(dirname "$0")" && pwd)
pkill -9 -f mame 2>/dev/null
cd ${SAM_MAME:-$HOME/emu/mame0283-arm64} && rm -rf snap/samcoupe
SAMKEYS="$1" SAMSNAPS="$2" SAMEND="$3" ./mame samcoupe -flop1 ${SAMDISK:-/Users/dom/Projects/simcity_z80/build/sam/simcity.mgt} -keyboardprovider none -video soft -window -nothrottle -seconds_to_run 300 -autoboot_script $S/keys.lua -skip_gameinfo 2>&1 | grep "pc=\|peek"
ls snap/samcoupe
