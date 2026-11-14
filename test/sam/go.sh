#!/bin/sh
# samgo.sh keys snaps end
S=$(cd "$(dirname "$0")" && pwd)
# The city takes a different time to make each time the keys or the program change (the seed comes from when the level was chosen): SAMREADY says where the clock of the script is when the game
# is up (_frame, the main loop's counter, 0 until it runs) so the frames after the start are counted from then; SAMREADY= (empty) is off, and then SAMSHIFT is how much later than frame 600 the title is.
if [ -z "${SAMREADY+x}" ]; then
    M=${SAMMAP:-/Users/dom/Projects/simcity_z80/build/sam/simcity.map}
    A=$(sed -n 's/^_frame *= \$\([0-9A-Fa-f]*\).*/\1/p' $M)
    [ -n "$A" ] && export SAMREADY=$A:1400
fi
export SAMSHIFT=${SAMSHIFT:-150}      # (the image takes until about frame 720 to load: the tests are written for 600)
pkill -9 -f mame 2>/dev/null
cd ${SAM_MAME:-$HOME/emu/mame0283-arm64} && rm -rf snap/samcoupe
SAMKEYS="$1" SAMSNAPS="$2" SAMEND="$3" ./mame samcoupe ${SAMRAM:+-ramsize $SAMRAM} -flop1 ${SAMDISK:-/Users/dom/Projects/simcity_z80/build/sam/simcity.mgt} -keyboardprovider none -video soft -window -nothrottle -seconds_to_run 300 -autoboot_script $S/keys.lua -skip_gameinfo 2>&1 | grep "pc=\|peek\|pc-trace\|mpr=\|sysvars"
ls snap/samcoupe
