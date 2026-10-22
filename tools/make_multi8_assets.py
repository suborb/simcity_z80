#!/usr/bin/env python3
"""The Multi8's copy of the tool icons: assets/icons_spec.bin.

The Multi8 draws a cell in eight colours from three planes, in the same bit order as a Spectrum attribute
(bit 0 blue, bit 1 red, bit 2 green; ink in bits 0-2, paper in bits 3-5), so the game's attribute bytes are used
as they are and only the icons need pulling out of assets/udgs.bin: 14 x 4 cells of 8 bytes, then the 56 attribute
bytes of the cells (bright is dropped: the Multi8 has no such thing).

  usage: tools/make_multi8_assets.py    (from the repository root)
"""
import os

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..'))


def main():
    udgs = open(os.path.join(ROOT, 'assets', 'udgs.bin'), 'rb').read()
    icons = udgs[:14 * 4 * 8] + bytes(a & 0x3F for a in udgs[3240:3240 + 14 * 4])
    open(os.path.join(ROOT, 'assets', 'icons_spec.bin'), 'wb').write(icons)
    print('assets/icons_spec.bin:', len(icons), 'bytes')


if __name__ == '__main__':
    main()
