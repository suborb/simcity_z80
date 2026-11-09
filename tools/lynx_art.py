#!/usr/bin/env python3
"""Makes the Camputers Lynx's art image: the 16 KB of the alternate green plane, which the display does not show.  The program's own RAM cannot
spare the pictures, so they live in the plane (CPU addresses $C000-$FFFF when the video RAM is read) and target/lynx/plat_lynx.asm copies what it
needs out with a stub that runs from the plane too (VCOPY: LDIR, then back to reading the RAM).

  offset 0       the map's pictures: 24 bytes each, a plane (blue, red, green) of eight rows after another (build/common/tiles_640x200_3bpp.bin)
  after those    the font (96 glyphs of 8 bytes, from the space)
  after those    the tool icons (assets/cpc_icons.bin: 14 icons of four cells of 16 bytes)
  $3C04          the stub: LDIR; LD A,$08; OUT ($82),A (VCOPY is at CPU address $FC00: a LD A,$0E; OUT ($82),A in the RAM there switches to reading the
                 video RAM, the next instruction is fetched from here, and the OUT that goes back is followed by a RET in the RAM at $FC0A)

usage: lynx_art.py tiles.bin font.bin icons.bin out.bin
"""
import sys

def main():
    tiles, font, icons = (open(f, 'rb').read() for f in sys.argv[1:4])
    img = bytearray(16384)
    pos = 0
    for blob in (tiles, font, icons):
        img[pos:pos + len(blob)] = blob
        pos += len(blob)
    assert pos <= 0x3C00, 'the art is too big for the plane'
    img[0x3C04:0x3C0A] = bytes([0xED, 0xB0, 0x3E, 0x08, 0xD3, 0x82])
    open(sys.argv[4], 'wb').write(img)
    print('tiles %d bytes at 0, font at %d, icons at %d, ends at %d' % (len(tiles), len(tiles), len(tiles) + len(font), pos))

main()
