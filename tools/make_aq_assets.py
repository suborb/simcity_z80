#!/usr/bin/env python3
"""The Aquarius+'s copies of the game's colour tables.

The Spectrum describes a cell's colours as an attribute byte (bits 0-2 ink, 3-5 paper, bit 6 bright).  The
Aquarius+ keeps a colour byte for each 8x8 cell of its bitmap: ink in the high nibble and paper in the low, as
numbers into its 16 colour palette (the default one, set by z88dk's set_default_palette: 0 black, 1 red,
2 green, 3 yellow, 4 blue, 5 magenta, 6 cyan, 7 white, 8 light grey, 9 teal, 10 purple, 11 dark blue,
12 pale yellow, 13 light green, 14 brick, 15 dark grey).  Converting at build time means the placer
(target/aqplus/plat_aqplus.asm) stores the byte it is given and the game does no conversion while drawing.

Writes
  assets/map_art_aq.bin   assets/map_art.bin with the attribute tables (see engine/art.asm) converted
  assets/icons.bin        the 14 tool icons: 14 x 4 cells of 8 bytes, then the 56 colour bytes of the cells

  usage: tools/make_aq_assets.py    (from the repository root)
"""
import os

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..'))

# The palette entry for each Spectrum colour 0..7 (GRB bit order), without and with BRIGHT.
PALETTE = [0, 11, 14, 10, 13, 9, 3, 8,
           0, 4, 1, 5, 2, 6, 3, 7]


def colour_byte(attr):
    bright = 8 if attr & 0x40 else 0
    return (PALETTE[(attr & 7) | bright] << 4) | PALETTE[((attr >> 3) & 7) | bright]


def main():
    art = bytearray(open(os.path.join(ROOT, 'assets', 'map_art.bin'), 'rb').read())
    # engine/art.asm: the attribute tables are at +2760 (94 tiles) and +2854 (251 large-zone pieces)
    for i in range(2760, 2854 + 251):
        art[i] = colour_byte(art[i])
    open(os.path.join(ROOT, 'assets', 'map_art_aq.bin'), 'wb').write(art)
    print('assets/map_art_aq.bin:', len(art), 'bytes')

    udgs = open(os.path.join(ROOT, 'assets', 'udgs.bin'), 'rb').read()
    # the menu icons are the first 56 cells of udgs.bin; their attributes are at +3240 (the game's udgs + 3240)
    icons = udgs[:14 * 4 * 8] + bytes(colour_byte(a & 0x7F) for a in udgs[3240:3240 + 14 * 4])
    open(os.path.join(ROOT, 'assets', 'icons.bin'), 'wb').write(icons)
    print('assets/icons.bin:', len(icons), 'bytes')


if __name__ == '__main__':
    main()
