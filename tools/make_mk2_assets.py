#!/usr/bin/env python3
"""The PC-6001mkII's copy of the game's colour tables.

The 320x200 mode has four colours at a time, a set chosen with port $C0, and a pixel is a pen 0..3 (bit of plane 0 + 2 * bit of plane 1).  The build uses set 4
($C0 = 4: pen 0 green, 1 yellow, 2 blue, 3 red; the PC-6001's own colours).  A cell is a picture of one bit a pixel and an ink pen and a paper pen, kept as one byte:
ink in bits 0-1, paper in bits 2-3.  The Spectrum's attribute bytes (bits 0-2 ink, 3-5 paper, bit 6 bright) in the tile and zone tables of the art are converted here, so
the placer (target/pc6001mk2/plat_pc6001mk2.asm) stores what view_fetch gives it.

The land is yellow, the water blue, a residential zone green, a commercial one blue and an industrial one yellow, as in the original, with red for the rest.

Writes assets/map_art_mk2.bin (assets/map_art.bin with the attribute tables of engine/art.asm converted); with --png FILE, a picture of the tiles for a look.
  usage: tools/make_mk2_assets.py [--png FILE]    (from the repository root)
"""
import os, sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..'))
G, Y, B, R = 0, 1, 2, 3                         # the pens of set 4
RGB = {G: (0x00, 0xFF, 0x00), Y: (0xFF, 0xFF, 0x00), B: (0x00, 0x00, 0xFF), R: (0xFF, 0x00, 0x00)}

# By attribute byte: (ink, paper).  Colours 0 black, 1 blue, 2 red, 3 magenta, 4 green, 5 cyan, 6 yellow, 7 white (GRB bit order as the Spectrum's, bit 6 bright)
OVERRIDE = {
    0x31: (B, Y), 0x30: (B, Y), 0x39: (B, G), 0x32: (R, Y), 0x3A: (R, Y), 0x06: (Y, B), 0x04: (G, B), 0x0E: (Y, B), 0x01: (B, B), 0x38: (B, G),
    0x28: (Y, B), 0x07: (Y, B), 0x00: (B, B),
    0x68: (Y, B), 0x78: (Y, R), 0x70: (B, Y), 0x60: (Y, G), 0x71: (B, Y), 0x79: (Y, R), 0x4F: (Y, B), 0x4C: (G, B), 0x44: (G, B), 0x7A: (R, Y),
}
INK = [B, B, R, R, G, Y, Y, Y]
PAPER = [B, B, R, R, G, B, Y, G]

def pens(attr):
    if attr in OVERRIDE:
        return OVERRIDE[attr]
    ink, paper = INK[attr & 7], PAPER[(attr >> 3) & 7]
    if ink == paper:
        ink = Y if paper == B else B
    return ink, paper

def convert(attr):
    ink, paper = pens(attr)
    return ink | (paper << 2)

def main():
    art = bytearray(open(os.path.join(ROOT, 'assets', 'map_art.bin'), 'rb').read())
    # engine/art.asm: the attribute tables are at +2760 (94 tiles) and +2854 (251 large-zone pieces)
    for i in range(2760, 2854 + 251):
        art[i] = convert(art[i])
    open(os.path.join(ROOT, 'assets', 'map_art_mk2.bin'), 'wb').write(art)
    print('assets/map_art_mk2.bin:', len(art), 'bytes')
    # the tool icons: assets/icons_spec.bin (14 x 4 cells of 8 bytes, then the cells' Spectrum attributes) with the attributes converted
    ic = bytearray(open(os.path.join(ROOT, 'assets', 'icons_spec.bin'), 'rb').read())
    for i in range(448, 504):
        ic[i] = convert(ic[i] & 0x7F)
    open(os.path.join(ROOT, 'assets', 'icons_mk2.bin'), 'wb').write(ic)
    print('assets/icons_mk2.bin:', len(ic), 'bytes')
    if '--png' in sys.argv:
        from PIL import Image
        png = sys.argv[sys.argv.index('--png') + 1]
        n = 94 + 251
        cols = 32
        img = Image.new('RGB', (cols * 9 * 3, ((n + cols - 1) // cols) * 9 * 3), (60, 60, 60))
        for t in range(n):
            a = art[t * 8:t * 8 + 8] if t < 94 else art[752 + (t - 94) * 8:752 + (t - 94) * 8 + 8]
            c = art[2760 + t]
            ink, paper = c & 3, (c >> 2) & 3
            for y in range(8):
                for x in range(8):
                    rgb = RGB[ink if a[y] & (0x80 >> x) else paper]
                    for dy in range(3):
                        for dx in range(3):
                            img.putpixel((((t % cols) * 9 + x) * 3 + dx, ((t // cols) * 9 + y) * 3 + dy), rgb)
        img.save(png)

if __name__ == '__main__':
    main()
