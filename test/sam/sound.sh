#!/bin/sh
# sound.sh "frame:addr,..." endframe log [wav]: calls the sound hooks in MAME (addresses from build/sam/simcity.map) and logs the SAA writes
S=$(cd "$(dirname "$0")" && pwd)
cd ${SAM_MAME:-$HOME/emu/mame0283-arm64}
SAMSFX="$1" SAMEND="$2" SAMLOG="$3" ./mame samcoupe -flop1 ${SAMDISK:-/Users/dom/Projects/simcity_z80/build/sam/simcity.mgt} -keyboardprovider none -video none ${4:+-wavwrite $4} -window -nothrottle -seconds_to_run 300 -autoboot_script $S/sound.lua -skip_gameinfo 2>&1 | tail -12
