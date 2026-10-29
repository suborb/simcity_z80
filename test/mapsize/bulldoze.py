#!/usr/bin/env python3
"""The bulldozer's rubble sequence (bulldoze_degrade_tile, engine/tools_e.asm) with the cursor on each of several rows of a 120x100 map: the 12 rows from six above the
cursor change from rubble to the next picture, kept inside the map, and nothing else in memory changes (the stack that follows the map, the program at the address a
negative row would have wrapped to).  test/mapsize/bulldoze.asm, run twice under z88dk-ticks (once without the call); no emulator.

    python3 test/mapsize/bulldoze.py"""
import os
import re
import subprocess
import sys
import tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
W, H = 120, 100
ROWS = (0, 1, 5, 6, 7, 50, 87, 88, 93, 94, 95, 98, 99)


def main():
    with tempfile.TemporaryDirectory() as tmp:
        subprocess.run(['cp', '-R'] + [os.path.join(ROOT, d) for d in ('engine', 'platform', 'target', 'test', 'assets')] + [tmp], check=True)
        r = subprocess.run(['z88dk-z80asm', '-Iengine', '-DPORTABLE', '-DBULLDOZE_TEST', f'-DMAP_W={W}', f'-DMAP_H={H}', '-b', '-m', 'target/test/test_platform.asm'],
                           cwd=tmp, capture_output=True, text=True)
        if r.returncode:
            print('FAIL  assembling\n' + r.stdout + r.stderr)
            return 1
        syms = {m.group(1): int(m.group(2), 16) for m in re.finditer(r'^(\S+)\s*=\s*\$([0-9A-Fa-f]+)', open(f'{tmp}/target/test/test_platform.map').read(), re.M)}
        prog = open(f'{tmp}/target/test/test_platform.bin', 'rb').read()

        def run(y, skip):
            img = bytearray(bytes(0x100) + prog)
            img[syms['bd_y']] = y                           # (the program is at $0100: the image's offset is the address)
            img[syms['bd_skip']] = skip
            open(f'{tmp}/image.bin', 'wb').write(img)
            subprocess.run(['z88dk-ticks', '-pc', '100', '-end', f'{syms["bulldoze_end"]:x}', '-counter', '400000000', '-output', f'{tmp}/mem.bin', f'{tmp}/image.bin'],
                           capture_output=True)
            return open(f'{tmp}/mem.bin', 'rb').read()

        base = syms['levelmap']
        ok = True
        for y in ROWS:
            before, after = run(y, 1), run(y, 0)
            first = max(0, y - 6)
            last = min(H, first + 12)
            wrong = 0
            for a in range(0xFF00):
                if a == syms['bd_skip']:
                    continue                                # (the flag that tells the two runs apart)
                if base <= a < base + W * H:
                    row = (a - base) // W
                    want = 0x47 if first <= row < last else 0x46
                    wrong += after[a] != want
                else:
                    wrong += before[a] != after[a]          # something outside the map changed
            print(('PASS' if not wrong else 'FAIL') + f'  bulldoze_degrade_tile with the cursor on row {y}: rows {first} to {last - 1} change, {wrong} wrong bytes')
            ok = ok and not wrong
        return 0 if ok else 1


if __name__ == '__main__':
    sys.exit(main())
