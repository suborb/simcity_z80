#!/usr/bin/env python3
"""Put the SAM's UI overlays (target/sam/mmap.inc) into the image's pictures' block and check that the layout holds.

    tools/sam_overlays.py BUILD_DIR WINDOW TILES

BUILD_DIR has simcity.map, simcity_OVERLAY_n.bin (n = 0, 1, 3) and simcity.all (the low 32 KB, the next 32 KB, then the pictures' block, which starts at 65536); the
overlays go into slots in that block after the pictures, where plat_overlay_load (plat_sam.asm) has them: the same offsets as OVL_n_AT there.  WINDOW is the
address the overlays are linked at (mmap.inc OVERLAY_WINDOW), and TILES the pictures' file, which must end before the slots, which the resident code must end below and which, with the biggest overlay and the stack, must fit under $8000.
"""
import os
import re
import sys

BLOCK = 65536
SLOTS = {0: (0x5000, 0x6400), 1: (0x6400, 0x7600), 3: (0x7600, 0x8000)}   # (offset in the block, its end): the same as OVL_n_AT
STACK = 768


def main():
    build, window, tiles = sys.argv[1], int(sys.argv[2], 0), sys.argv[3]
    syms = {}
    for line in open(os.path.join(build, 'simcity.map')):
        m = re.match(r'(\S+)\s+=\s+\$([0-9A-Fa-f]+)', line)
        if m:
            syms[m.group(1)] = int(m.group(2), 16)
    problems = []
    big = 0
    imgs = {}
    for n in SLOTS:
        path = os.path.join(build, f'simcity_OVERLAY_{n}.bin')
        data = open(path, 'rb').read() if os.path.exists(path) else b''
        imgs[n] = data
        big = max(big, len(data))
        head = syms.get(f'__OVERLAY_{n}_head')
        if data and head != window:
            problems.append(f'overlay {n} is linked at ${head:04X}, not at the window ${window:04X} (mmap.inc OVERLAY_WINDOW)')
        if syms.get(f'__OVERLAY_{n}_size', 0) != len(data):
            problems.append(f'overlay {n}: the map says {syms.get(f"__OVERLAY_{n}_size")} bytes, the file has {len(data)}')
        lo, hi = SLOTS[n]
        if len(data) > hi - lo:
            problems.append(f'overlay {n} is {len(data)} bytes: its slot in the pictures\' block is {hi - lo}')
    tail = syms['__code_user_tail']
    if tail > window:
        problems.append(f'the resident code ends at ${tail:04X}, over the overlay window at ${window:04X}: raise it in the Makefile and mmap.inc')
    if window + big > 0x8000 - STACK:
        problems.append(f'the window (${window:04X}) and the biggest overlay ({big} bytes) run into the stack (under $8000, {STACK} bytes)')
    allp = os.path.join(build, 'simcity.all')
    out = bytearray(open(allp, 'rb').read())
    if os.path.getsize(tiles) > SLOTS[0][0]:
        problems.append(f"the pictures' file is {os.path.getsize(tiles)} bytes: the slots start at {SLOTS[0][0]}")
    if problems:
        print('sam_overlays: ' + '\n              '.join(problems), file=sys.stderr)
        sys.exit(1)
    out.extend(bytes(BLOCK + 0x8000 - len(out)) if len(out) < BLOCK + 0x8000 else b'')
    for n, (lo, hi) in SLOTS.items():
        out[BLOCK + lo:BLOCK + lo + len(imgs[n])] = imgs[n]
    open(allp, 'wb').write(out)
    print(f'sam overlays: game {len(imgs[0])}, modal {len(imgs[1])}, start {len(imgs[3])} bytes at ${window:04X}; resident code ends at ${tail:04X} ({window - tail} spare below the window), '
          f'{0x8000 - STACK - window - big} spare above the biggest overlay')


if __name__ == '__main__':
    main()
