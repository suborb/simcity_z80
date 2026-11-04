"""Renders a screen dump of test/pcw/pcw_test.lua (screen_<name>.bin: the 32 KB of banks 1 and 2 as the CPU sees them at $4000-$BFFF) as the PCW shows it."""
import sys

def lines(dump):
    """The 256 lines of the screen as 90 bytes each, from the roller RAM."""
    out = []
    base = 0xB600 - 0x4000
    for y in range(256):
        w = dump[base + 2 * y] | (dump[base + 2 * y + 1] << 8)
        a = (((w << 1) & 0xFFF0) | (w & 7)) - 0x4000
        out.append([dump[(a + 8 * c) & 0x7FFF] for c in range(90)])
    return out


def image(dump):
    from PIL import Image
    ls = lines(dump)
    im = Image.new('L', (720, 256), 0)
    px = im.load()
    for y, row in enumerate(ls):
        for c, b in enumerate(row):
            for k in range(8):
                if b & (0x80 >> k):
                    px[c * 8 + k, y] = 255
    return im.resize((720, 512), Image.NEAREST)


if __name__ == '__main__':
    image(open(sys.argv[1], 'rb').read()).save(sys.argv[2])
