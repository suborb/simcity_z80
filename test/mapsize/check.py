#!/usr/bin/env python3
"""The engine's map arithmetic at 96x96 and 120x100: test/mapsize/driver.asm, assembled inside the headless test platform, runs every routine that
turns a tile's coordinates into an address (the levelmap, the power map's bit, the coverage and density maps' cell, view_cell's read) for every
cell of the map and counts the ones that differ from the sum worked out by adding.  Under z88dk-ticks; no emulator.

    python3 test/mapsize/check.py [WxH ...]        (the default is 96x96 and 120x100)"""
import os
import re
import subprocess
import sys
import tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
NAMES = ['levelmap_xypos_with_check', 'get_power_map_addr', 'map_addr_to_power_minimap', 'map_addr_to_xy',
         'minimap_xypos_25', 'minimap_xypos_50', 'view_cell']


def run(w, h):
    with tempfile.TemporaryDirectory() as tmp:
        subprocess.run(['cp', '-R'] + [os.path.join(ROOT, d) for d in ('engine', 'platform', 'target', 'test', 'assets')] + [tmp], check=True)
        r = subprocess.run(['z88dk-z80asm', '-Iengine', '-DPORTABLE', '-DMAPSIZE_TEST', f'-DMAP_W={w}', f'-DMAP_H={h}', '-b', '-m',
                            'target/test/test_platform.asm'], cwd=tmp, capture_output=True, text=True)
        if r.returncode:
            print(f'FAIL  {w}x{h}: assembling\n{r.stdout}{r.stderr}')
            return False
        syms = {m.group(1): int(m.group(2), 16) for m in re.finditer(r'^(\S+)\s*=\s*\$([0-9A-Fa-f]+)', open(f'{tmp}/target/test/test_platform.map').read(), re.M)}
        img = f'{tmp}/image.bin'
        out = f'{tmp}/mem.bin'
        with open(img, 'wb') as f:                      # the program is at $0100, in a 64 KB memory
            f.write(bytes(0x100) + open(f'{tmp}/target/test/test_platform.bin', 'rb').read())
        subprocess.run(['z88dk-ticks', '-pc', '100', '-end', f'{syms["mapsize_end"]:x}', '-counter', '4000000000', '-output', out, img],
                       capture_output=True)
        mem = open(out, 'rb').read()
    if mem[syms['mapsize_no']] != len(NAMES):           # (a run that stopped early would pass every test)
        print(f'FAIL  {w}x{h}: ran {mem[syms["mapsize_no"]]} of {len(NAMES)} tests')
        return False
    ok = True
    for n, name in enumerate(NAMES):
        fail = mem[syms['mapsize_fail'] + 2 * n] | mem[syms['mapsize_fail'] + 2 * n + 1] << 8
        x, y1 = mem[syms['mapsize_first'] + 2 * n], mem[syms['mapsize_first'] + 2 * n + 1]
        where = f', the first at x={x}, y={y1 - 1}' if fail else ''
        print(('PASS' if not fail else 'FAIL') + f'  {w}x{h}  {name}: {fail} wrong{where}')
        ok = ok and not fail
    return ok


def main():
    sizes = [tuple(int(v) for v in a.split('x')) for a in sys.argv[1:]] or [(96, 96), (120, 100)]
    return 0 if all([run(w, h) for w, h in sizes]) else 1


if __name__ == '__main__':
    sys.exit(main())
