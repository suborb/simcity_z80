#!/usr/bin/env python3
"""Makes the Sony SMC-777's picture atlas from the three plane pictures (build/common/tiles_640x200_3bpp.bin, 24 bytes a picture: blue, red and
green planes of eight lines each, the leftmost pixel in bit 7).  The SMC-777's 320x200 mode has a nibble a pixel, the left pixel in the high
nibble, so a picture is 8 lines of 4 bytes (32 bytes), written to the screen in reverse order a line (target/smc777/plat_smc777.asm: OUTI
decrements B first).  The colour in the nibble is the machine's digital one: blue 1, green 2, red 4.

usage: smc777_tiles.py planes.bin out.bin
"""
import sys

def nibble(b, r, g, x):
    m = 0x80 >> x
    return (1 if b & m else 0) | (4 if r & m else 0) | (2 if g & m else 0)

def main():
    src = open(sys.argv[1], 'rb').read()
    assert len(src) % 24 == 0
    out = bytearray()
    for p in range(len(src) // 24):
        pic = src[p * 24:(p + 1) * 24]
        for y in range(8):
            b, r, g = pic[y], pic[8 + y], pic[16 + y]
            line = [(nibble(b, r, g, 2 * i) << 4) | nibble(b, r, g, 2 * i + 1) for i in range(4)]
            out += bytes(reversed(line))
    open(sys.argv[2], 'wb').write(out)
    print('%d pictures, %d bytes' % (len(src) // 24, len(out)))

main()
