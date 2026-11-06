#!/bin/sh
# The Next's debug build, in build/zxn-debug/: -debug (C_LINE/ASM_LINE in the map) and --list (a listing of each file and of the whole program).
# simcity-jnext.map is the map without the line entries below $4000, which JNext refuses (it takes that part of the NEX for ROM, and rejects the whole map).
# The ordinary build (build/zxn) is made again afterwards, and the listings zcc leaves beside the sources are moved here.
set -e
cd "$(dirname "$0")/.."
ZCC=${ZCC:-zcc -compiler=80cc -fframe-pointer}
rm -f build/zxn/simcity.nex build/zxn/simcity.bin
make zxn ZCC="$ZCC -debug --list"
rm -rf build/zxn-debug
mkdir -p build/zxn-debug/lis
cp build/zxn/simcity.nex build/zxn/simcity.map build/zxn/simcity.bin build/zxn-debug/
mv build/zxn/simcity.lis build/zxn-debug/
for f in $(find . -name '*.lis' -not -path './.git/*' -not -path './build/*'); do
    mkdir -p "build/zxn-debug/lis/$(dirname "$f")"
    mv "$f" "build/zxn-debug/lis/$f"
done
python3 - <<'PY'
import re
out = []; n = 0
for l in open('build/zxn-debug/simcity.map', errors='replace'):
    m = re.match(r'(__(?:ASM|C)_LINE_\S+)\s*= \$([0-9A-Fa-f]+) ;', l)
    if m and int(m.group(2), 16) < 0x4000:
        n += 1
        continue
    out.append(l)
open('build/zxn-debug/simcity-jnext.map', 'w').write(''.join(out))
print('simcity-jnext.map: dropped %d line entries below $4000' % n)
PY
rm -f build/zxn/simcity.nex build/zxn/simcity.bin
make zxn
echo "zxn-debug: build/zxn-debug/ (simcity.nex, .map, simcity-jnext.map, .lis, lis/); build/zxn is the ordinary build again"
