#!/usr/bin/env python3
"""Extract the map pictures of the Amiga SimCity (the 1 Meg version, 1.2.2) from its graphics file.

  tools/extract_amiga_1meg_tiles.py "Classic Graphics.SimData" [--out assets/amiga_1meg_tiles.bin] [--sheet FILE.png]

The 1 Meg game has its art in files of the format tools/unpack_amiga.py unpacks (the disks of its alternative graphics sets have them
packed; the game disk's `Classic Graphics.SimData` is already unpacked, and this unpacks a file that is not).  The file is a resource
file: the game's messages, the names and the scenarios' texts, then a palette of 32 words ($0RGB, four bits a component) at $1FB1, and from
$1FF1 on the pictures, which are 8x8 and have six bitplanes (the Amiga's Extra Half-Brite mode: the sixth plane halves the colour,
so there are 64 colours of the 32), 48 bytes a picture: the eight bytes of plane 0, then those of planes 1 to 5.  The first 960 are
the map tiles, in the Micropolis numbering (tools/st_tiles_3bpp.py maps the engine's pictures to it); the rest are other pieces.

The output is the palette (32 words, 64 bytes) and the 960 pictures as they are in the file: 64 + 960 * 48 bytes.  The art belongs
to the game (see PORTING.md): keep the disk image out of the repository.

  --sheet FILE  a contact sheet of the 960 map tiles in the game's colours (needs Pillow), 32 to a row, 4x
"""
import argparse
import os
import struct
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from unpack_amiga import unpack      # noqa: E402

PALETTE_AT = 0x1fb1
TILES_AT = 0x1ff1
PIC = 48
COUNT = 960


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('file')
    ap.add_argument('--out', default='assets/amiga_1meg_tiles.bin')
    ap.add_argument('--sheet')
    a = ap.parse_args()
    data = open(a.file, 'rb').read()
    if data[:4] in (b'GSET', b'CLAS'):                # packed (the graphics sets' disks)
        data = unpack(data)[2]
    if data[:4] != b'\xff\xab\xcd\xff':
        sys.exit(f'{a.file}: not an Amiga SimCity graphics file')
    palette = data[PALETTE_AT:PALETTE_AT + 64]
    words = struct.unpack('>32H', palette)
    if any(w > 0xfff for w in words):
        sys.exit(f'{a.file}: the palette is not where it should be')
    tiles = data[TILES_AT:TILES_AT + COUNT * PIC]
    if len(tiles) != COUNT * PIC:
        sys.exit(f'{a.file}: too short')
    open(a.out, 'wb').write(palette + tiles)
    print(f'a palette of 32 colours and {COUNT} pictures of 6 bitplanes -> {a.out} ({64 + COUNT * PIC} bytes)')
    if a.sheet:
        from PIL import Image
        rgb = [tuple(((w >> s) & 15) * 17 for s in (8, 4, 0)) for w in words]
        rgb += [tuple(c // 2 for c in p) for p in rgb]
        im = Image.new('RGB', (32 * 8, COUNT // 32 * 8))
        for n in range(COUNT):
            o = n * PIC
            for y in range(8):
                for x in range(8):
                    v = sum(((tiles[o + p * 8 + y] >> (7 - x)) & 1) << p for p in range(6))
                    im.putpixel((n % 32 * 8 + x, n // 32 * 8 + y), rgb[v])
        im.resize((im.width * 4, im.height * 4), Image.NEAREST).save(a.sheet)


if __name__ == '__main__':
    main()
