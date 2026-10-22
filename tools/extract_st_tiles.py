#!/usr/bin/env python3
"""Extract the map pictures of the Atari ST SimCity (Maxis, 1989) from a Hatari memory snapshot or an unpacked program.

  tools/extract_st_tiles.py SNAPSHOT.sav [--out assets/st_tiles.bin] [--sheet sheet.png]
  tools/extract_st_tiles.py assets/st_tiles.bin --sheet sheet.png                     (from the extracted table)

The ST game runs in low resolution (320x200, 16 colours of 3 bits a channel).  Its map is 32x20 cells of 8x8 pixels,
and it is the classic Micropolis numbering: the 8x8 picture of map tile N (0 bare ground, 2..20 water, 21..36 trees,
37 forest, 44 rubble, 56 fire, 64 roads, 208 power lines, 224 rail, 240 the empty residential zone and so on) is
picture N of one table, so the art is a straight lookup by the Micropolis tile number.

The table is in the program's data, straight after the game's 16 colour palette (16 words, $0RGB):

  palette  16 words = 32 bytes
  tiles    32 bytes each: eight rows of four bytes, the four bitplanes of the row (plane 0 first), bit 7 the left pixel

so a pixel's colour is (p0 bit) | (p1 bit) << 1 | (p2 bit) << 2 | (p3 bit) << 3, an index into the palette.
The program is a JAM or Automation packed executable on the disks; a snapshot of the running game has it unpacked.

The output is the palette and the tables as they are in the game: 32 + COUNT * 32 bytes.  The art belongs to the game
(see PORTING.md): keep the snapshot and the disk image out of the repository.

  --sheet FILE  a contact sheet (needs Pillow): the tiles in the game's colours, 32 to a row, 3x, with a tile number
                on each row (needs no snapshot, only the table)
"""
import argparse
import gzip
import os
import struct
import sys

# the palette the game sets for the map: black, blue, green, cyan, red, magenta, brown, grey, dark grey, light blue,
# light green, light cyan, light red, light magenta, yellow, white (ground is brown with purple spots)
PALETTE = bytes.fromhex('0000 0005 0050 0055 0500 0505 0431 0555 0222 0227 0272 0277 0722 0727 0772 0777'.replace(' ', ''))
COUNT = 1024            # tiles taken after the palette: the 960 of the Micropolis numbering, then the game's other pictures
PIC = 32


def load(path):
    data = open(path, 'rb').read()
    if data[:2] == b'\x1f\x8b':
        data = gzip.decompress(data)
    return data


def find_table(data):
    """The offset of the palette that the tile table follows."""
    at = data.find(PALETTE)
    while at >= 0:
        # the table's pictures follow; the first is bare ground, brown with a purple spot: a few pixels of colour 5
        first = data[at + 32:at + 64]
        if len(first) == 32 and any(first[r * 4 + 2] for r in range(8)) and not any(first[r * 4 + 3] for r in range(8)):
            return at
        at = data.find(PALETTE, at + 1)
    return -1


def pixels(pic):
    """The 8x8 colour indexes of a 32 byte picture, rows of eight."""
    rows = []
    for r in range(8):
        p = pic[r * 4:r * 4 + 4]
        rows.append([sum(((p[k] >> (7 - x)) & 1) << k for k in range(4)) for x in range(8)])
    return rows


def rgb(palette):
    out = []
    for i in range(16):
        w = (palette[i * 2] << 8) | palette[i * 2 + 1]
        out.append((((w >> 8) & 7) * 255 // 7, ((w >> 4) & 7) * 255 // 7, (w & 7) * 255 // 7))
    return out


def sheet(table, name, scale=3, cols=32):
    from PIL import Image
    pal = rgb(table[:32])
    pics = (len(table) - 32) // PIC
    rows = (pics + cols - 1) // cols
    cell = 8 * scale + 1
    im = Image.new('RGB', (cols * cell, rows * cell), (40, 40, 40))
    px = im.load()
    for n in range(pics):
        pic = pixels(table[32 + n * PIC:32 + (n + 1) * PIC])
        for y in range(8):
            for x in range(8):
                c = pal[pic[y][x]]
                for sy in range(scale):
                    for sx in range(scale):
                        px[(n % cols) * cell + x * scale + sx, (n // cols) * cell + y * scale + sy] = c
    im.save(name)


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('source', help='a Hatari snapshot (.sav), an unpacked program, or an extracted table')
    ap.add_argument('--out', help='write the palette and the tile table here')
    ap.add_argument('--sheet', help='write a contact sheet of the pictures')
    args = ap.parse_args()

    data = load(args.source)
    if len(data) == 32 + COUNT * PIC and data[:32] == PALETTE:
        table = data
    else:
        at = find_table(data)
        if at < 0:
            sys.exit('no ST SimCity tile table in %s' % args.source)
        table = data[at:at + 32 + COUNT * PIC]
        if len(table) != 32 + COUNT * PIC:
            sys.exit('the table is cut short')
    if args.out:
        open(args.out, 'wb').write(table)
        print('%s: palette and %d pictures, %d bytes' % (args.out, COUNT, len(table)))
    if args.sheet:
        sheet(table, args.sheet)
        print(args.sheet)


if __name__ == '__main__':
    main()
