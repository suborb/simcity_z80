#!/usr/bin/env python3
"""Extract the 14 tool icons of the Amstrad CPC SimCity from a snapshot of the running game.

  tools/extract_cpc_icons.py SNAPSHOT.sna [--out assets/cpc_icons.bin] [--sheet sheet.png] [--palette NAME]

The icons are in the game's data just below the map pictures' table (tools/extract_cpc_tiles.py): 14 records of 64 bytes
from $9846, in the order of the game's tools (bulldozer, road, power lines, rail, park, residential, commercial, industrial,
police, fire, stadium, power station, seaport, airport).  An icon is 16x16 pixels, four cells of 16 bytes (two bytes a row, in
mode 1's interleaved pixel format) in the order top left, top right, bottom left, bottom right.  The four pens are the game's:
0 the button's grey face, 1 black, 2 red, 3 white (the bevel's light edge).

The output is 14 icons of four cells, each cell 8 rows of two bytes (896 bytes): the pixels that have blue (and green: the
colours are black, red, cyan and white, which have both or neither) and the pixels that have red, a pixel to a bit with the
leftmost in bit 7.  The Multi 8's and the PC-8801's planes are then those two bytes: blue, red, green = first, second, first.
The art belongs to the game: assets/cpc_icons.bin is kept out of the repository, like the tiles.
"""
import argparse
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import extract_cpc_tiles as tiles

ICONS = 14
BASE = 0x9846
RECORD = 64

# the pens as the Multi 8 and the PC-8801 have colours (bit 0 blue, 1 red, 2 green): 0 black, 2 red, 5 cyan, 7 white: the only ones
# with blue and green together, so that two planes are enough (the face cyan, the light edge white)
PENS = (5, 0, 2, 7)


def icon_pixels(ram, n):
    """The 16 x 16 pens of icon n."""
    base = BASE + n * RECORD
    rows = [[], [], [], []]
    cells = [tiles.pixels(bytes(ram[base + k * 16:base + k * 16 + 16])) for k in range(4)]
    out = []
    for half in (0, 2):
        for y in range(8):
            out.append(cells[half][y] + cells[half + 1][y])
    return out


def planes(pix):
    """The icon's four cells: for each, 8 rows of (the pixels with blue and green, the pixels with red)."""
    out = bytearray()
    for cy in (0, 8):
        for cx in (0, 8):
            for y in range(8):
                bg = red = 0
                for x in range(8):
                    c = PENS[pix[cy + y][cx + x]]
                    bg = bg << 1 | (c & 1)
                    red = red << 1 | (c >> 1 & 1)
                out += bytes((bg, red))
    return bytes(out)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('snapshot')
    ap.add_argument('--out', default=os.path.join(tiles.ROOT, 'assets', 'cpc_icons.bin'))
    ap.add_argument('--sheet', help='a picture of the icons in each of the palettes (needs Pillow)')
    args = ap.parse_args()

    d, ram, table = tiles.load(args.snapshot)
    data = b''.join(planes(icon_pixels(ram, n)) for n in range(ICONS))
    open(args.out, 'wb').write(data)
    print(f'{ICONS} icons, {len(data)} bytes -> {args.out}')
    if args.sheet:
        from PIL import Image
        rgb = [(0, 0, 0), (0, 0, 255), (255, 0, 0), (255, 0, 255), (0, 255, 0), (0, 255, 255), (255, 255, 0), (255, 255, 255)]
        sc = 4
        im = Image.new('RGB', (ICONS * 18 * sc, 18 * sc), (0, 0, 0))
        for n in range(ICONS):
            for cell in range(4):
                for y in range(8):
                    bg, red = data[n * 64 + cell * 16 + y * 2:n * 64 + cell * 16 + y * 2 + 2]
                    for x in range(8):
                        c = (bg >> (7 - x) & 1) * 5 | (red >> (7 - x) & 1) * 2
                        for dy in range(sc):
                            for dx in range(sc):
                                im.putpixel((n * 18 * sc + ((cell & 1) * 8 + x) * sc + dx, (((cell >> 1) * 8) + y) * sc + dy), rgb[c])
        im.save(args.sheet)
        print('sheet ->', args.sheet)


if __name__ == '__main__':
    main()
