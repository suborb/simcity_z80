#!/usr/bin/env python3
"""Extract the 14 SimCity 512K Amiga tool icons from its executable.

  tools/extract_amiga_icons.py SimCity [--out assets/amiga_icons.bin] [--sheet icons.png]

The Amiga program is a Hunk executable.  Its toolbar has 16 22x20 images, each
stored twice: grey normally, green when selected.  The last two button positions
are Map and Graph, so this writes the 14 construction tools in the engine's order
(bulldozer, road, power line, rail, park, residential, commercial, industrial, police, fire, stadium, power station, seaport, airport),
using their normal state.

The output is 14 * 22 * 20 = 6160 bytes.  Each byte is an index in SimCity 512K's
16-colour palette (the first 16 words of assets/amiga_tiles.bin); it is not yet
the 24x14, nibble-packed icon format of the ST/SAM/Next UI.

The game files are its art, not ours: keep the original executable outside the
repository.
"""
import argparse
import struct
import sys


HUNK_HEADER = 0x3F3
HUNK_CODE = 0x3E9
HUNK_DATA = 0x3EA
HUNK_BSS = 0x3EB
HUNK_RELOC32 = 0x3EC
HUNK_END = 0x3F2
HUNK_TAG = 0x3FFFFFFF
W, H, DEPTH = 22, 20, 4
RECORD = 20
BUTTONS = 16
IMAGES = BUTTONS * 2
# The Amiga toolbar is two columns from the bottom upwards: Map and Graph are
# images 0 and 1, and the 14 construction tools are 2..15.  The toolbar's own order is bulldozer, road, rail, power line, park, residential,
# commercial, industrial, fire, police, power station, stadium, airport, seaport (images 15, 14, 12, 13, 11, 10, 9, 8, 7, 6, 5, 4, 3, 2); the
# engine's is the same but power line before rail, police before fire, stadium before power station and seaport before airport.  This is the
# engine's: the image of each tool, in the engine's order.
TOOLS = (15, 14, 13, 12, 11, 10, 9, 8, 6, 7, 4, 5, 2, 3)


def word(data, pos):
    return struct.unpack_from('>I', data, pos)[0]


def hunks(data):
    """Return each initialized Hunk and its relocations (offset -> target Hunk)."""
    pos = 0
    if word(data, pos) != HUNK_HEADER:
        raise ValueError('not an Amiga Hunk executable')
    pos += 4
    names = word(data, pos)
    pos += 4
    for _ in range(names):
        pos += 4 * (word(data, pos) + 1)
    count, first, last = struct.unpack_from('>III', data, pos)
    pos += 12 + count * 4
    if first != 0 or last + 1 != count:
        raise ValueError('an unsupported Hunk range')
    result = []
    for _ in range(count):
        tag = word(data, pos) & HUNK_TAG
        pos += 4
        if tag not in (HUNK_CODE, HUNK_DATA, HUNK_BSS):
            raise ValueError(f'expected a Hunk, got {tag:#x}')
        size = word(data, pos) * 4
        pos += 4
        block = data[pos:pos + size] if tag != HUNK_BSS else b''
        if tag != HUNK_BSS:
            pos += size
        reloc = {}
        while True:
            tag = word(data, pos) & HUNK_TAG
            pos += 4
            if tag == HUNK_END:
                break
            if tag != HUNK_RELOC32:
                raise ValueError(f'unsupported Hunk record {tag:#x}')
            while (number := word(data, pos)):
                pos += 4
                target = word(data, pos)
                pos += 4
                for offset in struct.unpack_from('>' + 'I' * number, data, pos):
                    reloc[offset] = target
                pos += number * 4
            pos += 4
        result.append((block, reloc))
    return result


def toolbar(hs):
    """Find the 16 normal/selected pairs of 22x20 Image records and their data Hunk."""
    for hunk, (block, reloc) in enumerate(hs):
        for first in range(0, len(block) - RECORD * IMAGES + 1, 2):
            entries = []
            for n in range(IMAGES):
                at = first + n * RECORD
                if block[at:at + 6] != bytes((0, W, 0, H, 0, DEPTH)):
                    break
                pointer = word(block, at + 6)
                pick = block[at + 10]
                if pick != (7 if n % 2 == 0 else 5) or block[at + 11] != 0:
                    break
                target = reloc.get(at + 6)
                if target is None or target >= len(hs):
                    break
                entries.append((pointer, pick, target))
            if len(entries) == IMAGES and len({entry[2] for entry in entries}) == 1:
                return entries, hs[entries[0][2]][0]
    raise ValueError('the 16 pairs of Amiga toolbar images were not found')


def pixels(data, pointer, pick):
    """One Amiga Image in normal state: a palette index byte per 22x20 pixel."""
    rowbytes = ((W + 15) // 16) * 2
    planes = [p for p in range(DEPTH) if pick & (1 << p)]
    size = rowbytes * H * len(planes)
    if pointer + size > len(data):
        raise ValueError('toolbar image points beyond its Hunk')
    return bytes(sum(((data[pointer + k * rowbytes * H + y * rowbytes + x // 8] >> (7 - (x & 7))) & 1) << p
                     for k, p in enumerate(planes))
                 for y in range(H) for x in range(W))


def write_sheet(path, icons):
    from PIL import Image
    palette = (0x000, 0xDDD, 0x888, 0x666, 0x333, 0x0B0, 0x080, 0xFD0,
               0xD42, 0xA00, 0x753, 0x632, 0x38D, 0x35D, 0x12C, 0xCCC)
    rgb = [tuple(((colour >> shift) & 15) * 17 for shift in (8, 4, 0)) for colour in palette]
    cols = 7
    image = Image.new('RGB', (cols * (W + 2), 2 * (H + 2)), (48, 0, 48))
    for n, icon in enumerate(icons):
        left, top = n % cols * (W + 2) + 1, n // cols * (H + 2) + 1
        for y in range(H):
            for x in range(W):
                image.putpixel((left + x, top + y), rgb[icon[y * W + x]])
    image.resize((image.width * 4, image.height * 4), Image.Resampling.NEAREST).save(path)


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('executable')
    parser.add_argument('--out', default='assets/amiga_icons.bin')
    parser.add_argument('--sheet')
    args = parser.parse_args()
    entries, data = toolbar(hunks(open(args.executable, 'rb').read()))
    icons = [pixels(data, entries[n * 2][0], entries[n * 2][1]) for n in TOOLS]
    open(args.out, 'wb').write(b''.join(icons))
    print(f'{len(icons)} icons of {W}x{H}, one palette index byte a pixel -> {args.out} ({len(icons) * W * H} bytes)')
    if args.sheet:
        write_sheet(args.sheet, icons)


if __name__ == '__main__':
    main()
