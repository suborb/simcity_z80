#!/usr/bin/env python3
"""Makes the Toshiba Pasopia 7's art image: what plat_init stores in the video RAM beyond the 8000 bytes of each plane the screen shows (the window offset $2000 on).  The program's
own RAM cannot spare the pictures, and a cell is drawn by copying 8 bytes a plane from there (target/pasopia7/plat_pasopia7.asm).

  blue block    the map's pictures, 8 bytes each (the blue plane's rows of build/common/tiles_640x200_3bpp.bin: 24 bytes a picture, blue, red, green), then the font (96 glyphs of 8 bytes, from
                the space) and the tool icons (assets/cpc_icons.bin: 14 icons of four cells of 16 bytes)
  red block     the pictures' red rows, 8 bytes each
  green block   the pictures' green rows
(plat_init copies the font into the red and green planes too, so that white text is one copy of 8 bytes into all three planes: the planes read ANDed are the glyph)

usage: pasopia7_art.py tiles.bin font.bin icons.bin out.bin
"""
import sys

def main():
    tiles, font, icons = (open(f, 'rb').read() for f in sys.argv[1:4])
    assert len(tiles) % 24 == 0
    n = len(tiles) // 24
    blue = b''.join(tiles[24 * i:24 * i + 8] for i in range(n))
    red = b''.join(tiles[24 * i + 8:24 * i + 16] for i in range(n))
    green = b''.join(tiles[24 * i + 16:24 * i + 24] for i in range(n))
    b = blue + font + icons
    assert len(b) <= 8384, 'the art is too big for the spare area'
    open(sys.argv[4], 'wb').write(b + red + green)
    print('%d pictures: blue block %d bytes (the font at %d, the icons at %d), red and green %d each' % (n, len(b), len(blue), len(blue) + len(font), len(red)))

main()
