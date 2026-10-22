#!/usr/bin/env python3
"""Convert the Spectrum's 14 tool icons to the Z88's character cells.

An icon is 16x16 pixels, four of the Spectrum's 8x8 pictures at the start of assets/udgs.bin (top left,
top right, bottom left, bottom right) in a checkered frame.  The Z88's text cells are 6x8, so the
frame is dropped and the 12x12 picture inside is cut into 2x2 cells: columns 2..7 and 8..13 of the icon,
and rows 2..13 placed in the middle of the 16 rows of the two cell rows.

Writes assets/z88_icons.bin: 14 icons x 4 cells (top left, top right, bottom left, bottom right) x 8 rows,
a row being the six pixels in bits 5 (left) to 0 (right).  platform/console/plat_console.c defines
the OZ user defined characters from it (1,138,'=',code,rows with bit 7 set).

  usage: tools/make_z88_icons.py    (from the repository root)
"""
import os

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..'))
UDGS = open(os.path.join(ROOT, 'assets', 'udgs.bin'), 'rb').read()


def pixel(icon, x, y):
    """Pixel (x, y), 0..15, of icon 0..13 as the Spectrum draws it."""
    cell = icon * 4 + (y >> 3) * 2 + (x >> 3)
    return (UDGS[cell * 8 + (y & 7)] >> (7 - (x & 7))) & 1


def cell_rows(icon, cx, cy):
    """The 8 rows of cell (cx, cy), each 6 pixels."""
    rows = []
    for r in range(8):
        y = cy * 8 + r - 0                      # row of the 16 row icon area
        row = 0
        if 2 <= y <= 13:
            for p in range(6):
                x = 2 + cx * 6 + p              # columns 2..7 and 8..13
                row = (row << 1) | pixel(icon, x, y)
        rows.append(row)
    return rows


def main():
    out = bytearray()
    for icon in range(14):
        for cy in range(2):
            for cx in range(2):
                out += bytes(cell_rows(icon, cx, cy))
    open(os.path.join(ROOT, 'assets', 'z88_icons.bin'), 'wb').write(out)
    print('assets/z88_icons.bin:', len(out), 'bytes')


if __name__ == '__main__':
    main()
