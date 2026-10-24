#!/usr/bin/env python3
"""Extract the 14 tool icons of the Amiga SimCity (1 Meg version) from its graphics file.

  tools/extract_amiga_1meg_icons.py "Classic Graphics.SimData" [--out assets/amiga_1meg_icons.bin] [--sheet icons.png]

The graphics file (tools/extract_amiga_1meg_tiles.py has the map's pictures from it) holds, among its other objects, a table of Intuition Image
records, 20 bytes each (left, top, width, height, depth, data pointer, plane pick, plane on/off, next), and after the table their data:
the toolbar's 14 buttons are 14 records of 22x20 pixels, 6 bitplanes (the thirteenth record, the fire station, says 19 rows and has
19 rows of data).  The table is found by looking for the run, wherever it is in the file (not on an even offset).  The data is the planes one
after another, a plane being its rows of 4 bytes (22 pixels), each image 480 bytes after the last: the pointers in the records are 500 apart
(they count the 20 byte records, which are not between the images in the file).  A pixel is an index into the file's 32 colour palette (at
$1FB1) and, with the sixth plane, the half-bright version of that colour: 0 to 63.

The toolbar's order is the game's: bulldozer, road, rail, power lines, park, residential, commercial, industrial, fire station, police station,
power station, stadium, airport, seaport.  The output is in the engine's order (bulldozer, road, power lines, rail, park, residential, commercial,
industrial, police, fire, stadium, power station, seaport, airport): 14 * 22 * 20 = 6160 bytes, one palette index byte a pixel; the fire
station's missing row is its bottom row again.

The art belongs to the game (see PORTING.md): keep the disk image out of the repository.

  --sheet FILE  a contact sheet in the game's colours (needs Pillow), 7 to a row
"""
import argparse
import os
import struct
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from unpack_amiga import unpack      # noqa: E402

W, H, DEPTH = 22, 20, 6
RB = 4                                  # bytes in a row of a plane
IMAGE = RB * H * DEPTH                  # 480
ORDER = (0, 1, 3, 2, 4, 5, 6, 7, 9, 8, 11, 10, 13, 12)      # the engine's tool e is the toolbar's icon ORDER[e]
PALETTE_AT = 0x1fb1


def find_table(data):
    """The offset of the 14 records of the toolbar's images."""
    for o in range(len(data) - 20 * 14):
        if data[o:o + 10] != b'\x00\x00\x00\x00\x00\x16\x00\x14\x00\x06':
            continue
        recs = [struct.unpack_from('>HHHHHIBBI', data, o + 20 * i) for i in range(14)]
        if all(r[0] == 0 and r[1] == 0 and r[2] == W and r[3] in (H, H - 1) and r[4] == DEPTH and r[6] == 0x3f for r in recs):
            return o, recs
    sys.exit('the table of the 14 toolbar images was not found')


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('file')
    ap.add_argument('--out', default='assets/amiga_1meg_icons.bin')
    ap.add_argument('--sheet')
    a = ap.parse_args()
    data = open(a.file, 'rb').read()
    if data[:4] in (b'GSET', b'CLAS'):                # packed (the graphics sets' disks)
        data = unpack(data)[2]
    at, recs = find_table(data)
    first = at + 20 * 14                           # the data follows the table
    icons = []
    for k, r in enumerate(recs):
        h = r[3]
        o = first + k * IMAGE
        px = bytearray()
        for y in range(h):
            for x in range(W):
                px.append(sum(((data[o + p * RB * h + y * RB + x // 8] >> (7 - (x & 7))) & 1) << p for p in range(DEPTH)))
        if h < H:
            px += px[-W:]                          # (a row short: the last one again)
        icons.append(bytes(px))
    out = b''.join(icons[ORDER[e]] for e in range(14))
    open(a.out, 'wb').write(out)
    print(f'{len(icons)} icons of {W}x{H} (the table is at {at:#x}), one palette index (0 to 63) a byte -> {a.out} ({len(out)} bytes)')
    if a.sheet:
        from PIL import Image
        words = struct.unpack('>32H', data[PALETTE_AT:PALETTE_AT + 64])
        rgb = [tuple(((w >> s) & 15) * 17 for s in (8, 4, 0)) for w in words]
        rgb += [tuple(c // 2 for c in p) for p in rgb]
        im = Image.new('RGB', (7 * (W + 2), 2 * (H + 2)), (48, 0, 48))
        for n in range(14):
            for y in range(H):
                for x in range(W):
                    im.putpixel((n % 7 * (W + 2) + 1 + x, n // 7 * (H + 2) + 1 + y), rgb[out[n * W * H + y * W + x]])
        im.resize((im.width * 5, im.height * 5), Image.NEAREST).save(a.sheet)


if __name__ == '__main__':
    main()
