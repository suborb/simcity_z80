#!/usr/bin/env python3
"""The FP-1100's pictures file: the map's 345 pictures (24 bytes: blue, red and green plane of 8 lines) and then the 112 cells of the tool icons, each byte turned about
(the leftmost pixel is bit 0 on this machine).  Cell k of the icons is picture 345 + k: k = (icon * 4 + row * 2 + col) + 56 for the dimmed ones (the tools there is no money
for).  The colours are those of target/common/plat_icons.c (face_colour, the dimming checker); keep them the same.

  tools/fp1100_art.py TILES.bin cpc_icons.bin OUT.bin
"""
import sys

FACE = [6, 5, 5, 5, 4, 4, 5, 6, 3, 3, 6, 6, 5, 5]
SECTORS = 43


def rev(b):
    return int('{:08b}'.format(b)[::-1], 2)


def cell(icons, i, r, c, dim):
    src = icons[(i * 4 + r * 2 + c) * 16:][:16]
    fb, fr, fg = [0xFF if FACE[i] >> k & 1 else 0 for k in range(3)]
    planes = [[0] * 8 for _ in range(3)]
    for y in range(8):
        bg, red = src[y * 2], src[y * 2 + 1]
        face, white = bg & ~red & 0xFF, bg & red
        m = (0xAA if y & 1 else 0x55) if dim else 0xFF
        planes[0][y] = (white | (face & fb)) & m
        planes[1][y] = (red | (face & fr)) & m
        planes[2][y] = (white | (face & fg)) & m
    return bytes(rev(b) for p in planes for b in p)


def main():
    tiles, icons, out = sys.argv[1:]
    d = open(tiles, 'rb').read()
    icons = open(icons, 'rb').read()
    assert len(d) == 345 * 24, len(d)
    assert len(icons) == 14 * 4 * 16, len(icons)
    art = bytes(rev(b) for b in d)
    for dim in (0, 1):
        for i in range(14):
            for r in range(2):
                for c in range(2):
                    art += cell(icons, i, r, c, dim)
    assert len(art) == (345 + 112) * 24
    open(out, 'wb').write(art.ljust(SECTORS * 256, b'\0'))


main()
