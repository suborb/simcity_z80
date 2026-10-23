#!/usr/bin/env python3
"""Extract the 14 tool icons of the Atari ST SimCity (Maxis, 1989) from a Hatari memory snapshot.

  tools/extract_st_icons.py SNAPSHOT.sav [--out assets/st_icons.bin] [--sheet sheet.png]

The icons are in the program's data as four plane bitmaps 32 pixels wide (eight bytes a 16 pixel group: the four planes' words,
as the ST screen has them), 288 bytes apart (18 rows: the picture is the first 14, the rest is other data), in the order of the
game's tools: bulldozer, road, power lines, rail, park, residential, commercial, industrial, police, fire, stadium, power
station, seaport, airport.  The picture is 24 pixels wide and 14 rows tall: a grey button with a bevel (white above and to the
left, black below and to the right) and the symbol in it.  The colours are the game's 16 (the same palette as the map's).

The output is 14 icons of 14 rows of 12 bytes: two pixels a byte, the left one in the high nibble, a palette index each (the SAM's
own pixel format and the same indexes as assets/st_tiles.bin's palette).  The art belongs to the game: keep the snapshot out of the
repository.
"""
import argparse
import gzip
import struct
import sys

ICONS = 14
W, H = 24, 14
STRIDE = 288                                    # bytes from one icon to the next
# the first two rows of the first icon (the bulldozer): white bevel, grey button
SIGNATURE = bytes.fromhex('fffffffffffffffffe00fe00fe00fe00fe1fffffffffc000fc00fc00fc000000')
PALETTE = bytes.fromhex('0000 0005 0050 0055 0500 0505 0431 0555 0222 0227 0272 0277 0722 0727 0772 0777'.replace(' ', ''))


def load(path):
    data = open(path, 'rb').read()
    return gzip.decompress(data) if data[:2] == b'\x1f\x8b' else data


def pixels(data, at):
    """The 24 x 14 palette indexes of the icon whose first row is at `at`."""
    rows = []
    for y in range(H):
        row = []
        for g in range(2):
            planes = struct.unpack('>4H', data[at + y * 16 + g * 8:at + y * 16 + g * 8 + 8])
            for b in range(16):
                row.append(sum(((planes[p] >> (15 - b)) & 1) << p for p in range(4)))
        rows.append(row[:W])
    return rows


def pack(rows):
    return bytes((r[x] << 4) | r[x + 1] for r in rows for x in range(0, W, 2))


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('snapshot')
    ap.add_argument('--out', default='assets/st_icons.bin')
    ap.add_argument('--sheet')
    a = ap.parse_args()
    data = load(a.snapshot)
    # (the first two rows' second group is the same bytes on every row: the signature is 32 bytes, two rows)
    at = data.find(SIGNATURE)
    while at >= 0 and data.find(SIGNATURE, at + 1) >= 0 and at < 0x6cee:
        at = data.find(SIGNATURE, at + 1)
    if at < 0:
        sys.exit('the icons were not found in ' + a.snapshot)
    icons = [pixels(data, at + k * STRIDE) for k in range(ICONS)]
    for icon in icons:                      # the selected tool's button has a yellow frame (colour 14) over the bevel's edge: put the bevel back
        if icon[0][1] == 14 and icon is not icons[0]:
            for y in range(H):
                for x in range(W):
                    if (y in (0, H - 1) or x in (0, 1, W - 2, W - 1)) and icon[y][x] == 14:
                        icon[y][x] = icons[0][y][x]
    open(a.out, 'wb').write(b''.join(pack(i) for i in icons))
    print(f'{ICONS} icons of {W}x{H} -> {a.out} ({ICONS * H * W // 2} bytes), found at {at:#x}')
    if a.sheet:
        from PIL import Image
        rgb = [(((w >> 8) & 7) * 255 // 7, ((w >> 4) & 7) * 255 // 7, (w & 7) * 255 // 7)
               for w in (struct.unpack('>H', PALETTE[i * 2:i * 2 + 2])[0] for i in range(16))]
        sheet = Image.new('RGB', (7 * (W + 4), 2 * (H + 4)), (40, 0, 40))
        for k, icon in enumerate(icons):
            im = Image.new('RGB', (W, H))
            im.putdata([rgb[v] for row in icon for v in row])
            sheet.paste(im, ((k % 7) * (W + 4) + 2, (k // 7) * (H + 4) + 2))
        sheet.resize((sheet.width * 4, sheet.height * 4), Image.NEAREST).save(a.sheet)


if __name__ == '__main__':
    main()
