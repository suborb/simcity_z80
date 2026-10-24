#!/usr/bin/env python3
"""Make the map pictures of the 3 bit (8 colour) targets from the Atari ST game's art.

  tools/st_tiles_3bpp.py assets/st_tiles.bin --planes FILE [--numbering ours|cpc]
  tools/st_tiles_3bpp.py assets/st_tiles.bin --mini FILE [--numbering ours|cpc]
  tools/st_tiles_3bpp.py assets/st_tiles.bin --sam FILE [--numbering ours|cpc]
  tools/st_tiles_3bpp.py assets/st_tiles.bin --sheet FILE.png [--numbering ours|cpc] [--original]

The same files, in the same formats, as tools/extract_cpc_tiles.py makes from the CPC art (and so the same Makefile rules
and the same game): --planes the pictures baked into 8 colours, 24 bytes each (three planes, blue, red and green, of
eight rows), --mini the quarter size pictures for the mini maps, 5 bytes each.  The table is the one tools/extract_st_tiles.py
makes (the game's palette, then 32 byte pictures in the Micropolis numbering).

The ST art has the Micropolis numbering and ours does not, so each of our pictures is taken from a Micropolis tile.  That mapping
(TILE, st_piece, st_picture_ours, st_picture_cpc) is the useful part and is not specific to the ST: it gives the Micropolis tile
number for each of our pictures, so any set of Micropolis-numbered tiles can be converted by loading its pictures (pixels(), to8()
and planes() below are the ST's palette and format).  It was worked out by comparing the shapes of our tiles (the CPC art, which
draws the engine's own tiles) with the ST's:

  the engine's 94 map tiles   TILE below.  Roads, rails and wires come in the same eleven shapes in both games, in different
                              orders (SHAPES), and the bridges and crossings are the ones the engine's flag table says.
  the large pieces            blocks of tiles: a service building, power plant, port, airport, stadium; and the growth
                              levels of the residential, commercial and industrial zones.  The ST game has 16 residential,
                              20 commercial and 8 industrial levels where the CPC game has 8, 10 and 8, and we have 4, 4
                              and 4: the CPC's levels take every other ST level (the later of each pair, so the largest
                              building is the last), and ours take the CPC's as extract_cpc_tiles.py does.

  --numbering ours  the engine's own 345 pictures (94 tiles and 251 pieces); the default
              cpc   the CPC's 471, as the engine with FINE_ZONE_LEVELS (see PORTING.md)

The ST game's 16 colours become the machine's 8 by COLOUR (a table: a colour, or a pair that is dithered, one pixel in
two), which is the one place to change the look.  The art belongs to the game (see PORTING.md).

  --zxn DIR    the pictures for the ZX Spectrum Next's Layer 2 (256x192, a byte a pixel, the palette entry of each): head.bin (the 16
                palette entries as the Next's two bytes each, the 8 attribute colours' entries, the tool icons: --icons, as for --sam),
                atlas0.bin and atlas1.bin (the pictures, 64 bytes each: 256 of them in the first 16 KB bank, the rest in the second)
  --sam FILE    the pictures for the SAM Coupe's mode 4 (256x192, 16 colours, 4 bits a pixel, the left pixel in the high nibble):
                the palette (16 bytes, the nearest of the SAM's 128 colours to each of the game's), the palette entry nearest each of the
                eight attribute colours (8 bytes: bit 0 blue, 1 red, 2 green), the icons (--icons) if there are any, and then 32 bytes a picture
  --colours P   the colour preset (PRESETS: meadow, earth, sand, night)
  --sheet FILE  a contact sheet (needs Pillow): the pictures as made, or --original in the game's own colours
"""
import argparse
import os
import struct
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from extract_cpc_tiles import mini, TILES, PIECE0, zx_piece   # noqa: E402  (the quarter size pictures are made the same way)

PIC = 32
OURS = TILES + 251                                      # the engine's pictures
CPC_COUNT = 471

# The engine's 94 map tiles: the Micropolis tile for each.
#
# A path (road, rail, power line) is eleven tiles of one type in both games, in different orders:
#   ours      H, V, ES, SW, NE, NW, ESW, NEW, NSW, NES, cross      (E east, S south, ...: the sides the path leaves by)
#   Micropolis H, V, NE, ES, SW, NW, NEW, NES, ESW, NSW, cross
SHAPES = (0, 1, 3, 4, 2, 5, 8, 6, 9, 7, 10)         # ours -> Micropolis, as an offset in the eleven

TILE = {0: 2,           # water
        1: 9, 3: 16, 4: 19, 5: 7,       # the shore: water in the north west, north east, south east, south west
        2: 0,           # dirt
        6: 37,          # trees
        18: 64, 19: 65,                 # road bridges, horizontal and vertical
        31: 224, 32: 225,               # rail bridges
        44: 209, 45: 208,               # power line bridges (the ST pictures: 208 is the vertical one)
        46: 237, 47: 238,               # a rail across a road: the rails horizontal, vertical
        48: 78, 49: 77,                 # a road with a power line across it: the road vertical, horizontal
        50: 221, 51: 222,               # a rail with a power line across it: the rails horizontal, vertical
        52: 146, 53: 162, 54: 147, 55: 163,     # the busy road, horizontal and vertical, two frames each
        56: 41, 57: 40,                 # parks: with paths, and with the fountain
        58: 44,                         # rubble
        59: 827,                        # the lightning bolt: no power
        68: 48,                         # flood
        69: 56, 70: 58, 71: 60, 72: 62, 90: 57, 91: 59,     # fire and explosions
        87: 79, 88: 95,                 # a raised bridge (the water under it)
        89: 52,                         # radiation
        92: 2, 93: 2}                   # (more water)
for k in range(11):
    TILE[7 + k] = 66 + SHAPES[k]
    TILE[20 + k] = 226 + SHAPES[k]
    TILE[33 + k] = 210 + SHAPES[k]
for k, n in enumerate((249, 250, 251, 252, 254, 256, 258, 260)):        # the houses on an empty lot: eight of the twelve
    TILE[60 + k] = n
for k, n in enumerate((240, 241, 242, 245, 248, 247, 246, 243)):        # the ring of an empty zone, clockwise from the top left
    TILE[73 + k] = n
for k, n in enumerate((244, 427, 616)):                                 # its middle: R, C and I
    TILE[81 + k] = n
    TILE[84 + k] = n
assert sorted(TILE) == list(range(TILES)), sorted(set(range(TILES)) - set(TILE))

# The large pieces (our numbering of the pieces 0..250): the first of the Micropolis tiles of each block, row by row.
BLOCKS = ((0, 9, 770),        # police station
          (9, 9, 761),        # fire station
          (18, 9, 405),       # church
          (27, 9, 414),       # hospital
          (36, 16, 779),      # stadium
          (52, 16, 745),      # coal power plant
          (68, 16, 811),      # nuclear power plant
          (84, 16, 693),      # seaport
          (100, 36, 709))     # airport
RES0, COM0, IND0 = 261, 432, 621                    # the first building of each kind of zone
BLANK = 454                                         # a plain dark grey tile, for what the engine does not use (our pieces 244..250)


def st_piece(p):
    """The Micropolis tile for our piece p (0..250)."""
    for first, n, base in BLOCKS:
        if first <= p < first + n:
            return base + p - first
    if p < 172:                                     # residential: our four blocks, from the CPC's eight (1, 3, 5, 7) ...
        return RES0 + 9 * (4 * ((p - 136) // 9) + 3) + (p - 136) % 9        # ... and so the ST's 3, 7, 11, 15 of sixteen
    if p < 208:                                     # commercial: the CPC's blocks 1, 3, 5, 8 of ten, so the ST's 3, 7, 11, 17 of twenty
        return COM0 + 9 * (2 * (1, 3, 5, 8)[(p - 172) // 9] + 1) + (p - 172) % 9
    if p < 244:                                     # industrial: the CPC's blocks 1, 3, 5, 7 of eight; the ST has eight
        return IND0 + 9 * (2 * ((p - 208) // 9) + 1) + (p - 208) % 9
    return BLANK


def st_picture_ours(i):
    """The Micropolis tile for our picture i (0..344)."""
    return TILE[i] if i < TILES else st_piece(i - PIECE0)


def st_picture_cpc(i):
    """The Micropolis tile for the CPC picture i (0..470): the engine's tiles, then its 377 pieces."""
    if i < TILES:
        return TILE[i]
    q = i - PIECE0
    if q < 136:
        return st_piece(q)
    if q < 208:                                     # residential: eight levels of the CPC, of the ST's sixteen
        return RES0 + 9 * (2 * ((q - 136) // 9) + 1) + (q - 136) % 9
    if q < 298:                                     # commercial: ten of twenty
        return COM0 + 9 * (2 * ((q - 208) // 9) + 1) + (q - 208) % 9
    if q < 370:                                     # industrial: eight of eight
        return IND0 + 9 * ((q - 298) // 9) + (q - 298) % 9
    return st_piece(q - 126)                        # the seven after them


# ---- colours ----------------------------------------------------------------------------------------------------------------
# the machine's colours: 0 black, 1 blue, 2 red, 3 magenta, 4 green, 5 cyan, 6 yellow, 7 white
# the game's: 0 black, 1 blue, 2 green, 3 cyan, 4 red, 5 magenta, 6 brown, 7 grey, 8 dark grey, 9 light blue, 10 light green,
# 11 light cyan, 12 light red, 13 light magenta, 14 yellow, 15 white
# a number is a colour; a pair (a, b) is dithered, a on the pixels where x + y is even and b on the others.  The colours that
# have no match in the machine's are the brown of the ground and the three greys (dark grey, grey, white): GROUND says what
# the ground becomes, and a preset (PRESETS) the rest.
def colours(ground, spot=None, grey=7, dark=0, white=7, tree=(4, 4), water=(1, 1)):
    """A table (see above): the ground and its spots, the greys and white, the dark green and light green of the trees, the light
    blue and dark blue of the water.  The grey of a road and the white of its markings must differ, so one of them moves."""
    c = [0, 1, 4, 5, 2, 3, ground, grey, dark, 1, 4, 5, 2, 3, 6, white]
    c[5] = ground if spot is None else spot
    c[2], c[10] = tree
    c[9], c[1] = water
    return c


# a dither with black makes a darker version of a colour
TREES = ((4, 0), 4)                                         # dark green is green and black in a checker, light green is green
WATER = (1, (1, 0))                                         # light blue is blue, dark blue blue and black in a checker
PRESETS = {
    'meadow': colours(4, 0, white=6, tree=TREES, water=WATER),      # green ground with black tufts; white is yellow (lane markings)
    'earth': colours((0, 2), 2, white=6, tree=TREES, water=WATER),  # red and black in a checker: brown
    'sand': colours(6, 2, white=7, grey=(0, 7), tree=TREES, water=WATER),   # yellow ground, grey as a checker (yellow is taken)
    'night': colours(0, 3, dark=1),                         # black ground, blue for the dark greys
}
COLOUR = PRESETS['meadow']


def pixels(pic):
    """The 8x8 colour indexes (0..15) of a 32 byte picture."""
    return [[sum((((pic[r * 4 + p] >> (7 - x)) & 1) << p) for p in range(4)) for x in range(8)] for r in range(8)]


def to8(px, colour=None):
    """The picture's pixels in the machine's 8 colours (rows of eight)."""
    colour = colour or COLOUR
    out = []
    for y, row in enumerate(px):
        r = []
        for x, p in enumerate(row):
            c = colour[p]
            r.append(c if isinstance(c, int) else c[(x + y) & 1])
        out.append(r)
    return out


def planes(rows):
    """The 24 bytes of a baked picture: blue, red, green plane, eight pixel rows each."""
    out = bytearray()
    for p in range(3):
        for row in rows:
            b = 0
            for x, c in enumerate(row):
                b |= ((c >> p) & 1) << (7 - x)
            out.append(b)
    return bytes(out)


# ---- the SAM Coupe ----------------------------------------------------------------------------------------------------------
def sam_level(c):
    """The (red, green, blue) levels 0..7 of a SAM palette byte: each channel is its own two bits (the high one worth 4, the low
    one 2) and the bright bit, bit 3, which all three share (worth 1)."""
    bright = (c >> 3) & 1
    return (((c >> 5) & 1) * 4 + ((c >> 1) & 1) * 2 + bright,
            ((c >> 6) & 1) * 4 + ((c >> 2) & 1) * 2 + bright,
            ((c >> 4) & 1) * 4 + (c & 1) * 2 + bright)


def sam_palette(palette):
    """The nearest SAM palette byte (0..127) to each of the game's colours ($0RGB, 3 bits a channel)."""
    out = bytearray()
    for w in palette:
        want = ((w >> 8) & 7, (w >> 4) & 7, w & 7)
        out.append(min(range(128), key=lambda c: (sum((a - b) ** 2 for a, b in zip(sam_level(c), want)), c)))
    return bytes(out)


def attr_colours(palette):
    """The palette entry nearest each of the eight colours of a Spectrum attribute (bit 0 blue, 1 red, 2 green)."""
    out = bytearray()
    for c in range(8):
        want = ((c >> 1) & 1, (c >> 2) & 1, c & 1)
        low = 0 if c == 0 else 1                # the channels that are off are a little on: the bright entries (light red, light
        out.append(min(range(16), key=lambda i: (sum((a - (7 if b else low)) ** 2 for a, b in zip(   # green...) are the ones wanted
            ((palette[i] >> 8) & 7, (palette[i] >> 4) & 7, palette[i] & 7), want)), i)))
    return bytes(out)


def zxn_palette(palette):
    """The Next's 9 bit colours (RRRGGGBB, then the low bit of blue) of the game's colours ($0RGB, 3 bits a channel)."""
    out = bytearray()
    for w in palette:
        r, g, b = (w >> 8) & 7, (w >> 4) & 7, w & 7
        out += bytes(((r << 5) | (g << 2) | (b >> 1), b & 1))
    return bytes(out)


def sam_picture(px):
    """A picture in mode 4: eight rows of four bytes, two pixels to a byte, the left one in the high nibble."""
    return bytes((row[x] << 4) | row[x + 1] for row in px for x in range(0, 8, 2))



def load(path):
    d = open(path, 'rb').read()
    if len(d) < 32 + 960 * PIC:
        sys.exit(f'{path}: not the table of tools/extract_st_tiles.py')
    palette = [struct.unpack('>H', d[k * 2:k * 2 + 2])[0] for k in range(16)]
    return palette, d[32:]


SPEC = [(0, 0, 0), (0, 0, 205), (205, 0, 0), (205, 0, 205), (0, 205, 0), (0, 205, 205), (205, 205, 0), (255, 255, 255)]


def sheet(path, table, palette, pictures, original, scale=5):
    from PIL import Image
    cols = 32
    rows = (len(pictures) + cols - 1) // cols
    im = Image.new('RGB', (cols * 9 * scale, rows * 9 * scale), (30, 30, 40))
    rgb = [(((w >> 8) & 7) * 255 // 7, ((w >> 4) & 7) * 255 // 7, (w & 7) * 255 // 7) for w in palette]
    for k, n in enumerate(pictures):
        px = pixels(table[n * PIC:n * PIC + PIC])
        px8 = to8(px)
        for y in range(8):
            for x in range(8):
                col = rgb[px[y][x]] if original else SPEC[px8[y][x]]
                for dy in range(scale):
                    for dx in range(scale):
                        im.putpixel(((k % cols) * 9 * scale + x * scale + dx, (k // cols) * 9 * scale + y * scale + dy), col)
    im.save(path)


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('table')
    ap.add_argument('--planes')
    ap.add_argument('--mini')
    ap.add_argument('--sheet')
    ap.add_argument('--sam')
    ap.add_argument('--zxn')
    ap.add_argument('--icons', help='with --sam: the tool icons (tools/extract_st_icons.py), put after the palette')
    ap.add_argument('--original', action='store_true')
    ap.add_argument('--colours', choices=sorted(PRESETS), default='meadow')
    ap.add_argument('--numbering', choices=('ours', 'cpc'), default='ours')
    a = ap.parse_args()
    global COLOUR
    COLOUR = PRESETS[a.colours]
    palette, table = load(a.table)
    if a.numbering == 'ours':
        pictures = [st_picture_ours(i) for i in range(OURS)]
    else:
        pictures = [st_picture_cpc(i) for i in range(CPC_COUNT)]
    baked = [planes(to8(pixels(table[n * PIC:n * PIC + PIC]))) for n in pictures]
    if a.planes:
        open(a.planes, 'wb').write(b''.join(baked))
        print(f'{len(baked)} pictures, {len(baked) * 24} bytes of baked pictures -> {a.planes}')
    if a.mini:
        open(a.mini, 'wb').write(b''.join(mini(b) for b in baked))
        print(f'{len(baked)} pictures, {len(baked) * 5} bytes of mini map pictures -> {a.mini}')
    if a.sam:
        icons = open(a.icons, 'rb').read() if a.icons else b''
        data = sam_palette(palette) + attr_colours(palette) + icons + b''.join(sam_picture(pixels(table[n * PIC:n * PIC + PIC])) for n in pictures)
        open(a.sam, 'wb').write(data)
        print(f'{len(pictures)} pictures, {len(icons)} bytes of icons, a 16 byte palette, 8 attribute colours and {len(pictures) * 32} bytes of mode 4 pictures -> {a.sam}')
    if a.zxn:
        import os
        os.makedirs(a.zxn, exist_ok=True)
        icons = open(a.icons, 'rb').read() if a.icons else b''
        pics = b''.join(bytes(v for row in pixels(table[n * PIC:n * PIC + PIC]) for v in row) for n in pictures)
        open(os.path.join(a.zxn, 'head.bin'), 'wb').write(zxn_palette(palette) + attr_colours(palette) + icons)
        open(os.path.join(a.zxn, 'atlas0.bin'), 'wb').write(pics[:16384])
        open(os.path.join(a.zxn, 'atlas1.bin'), 'wb').write(pics[16384:].ljust(8192, b'\0'))
        print(f'{len(pictures)} pictures of 64 bytes ({len(pics)} bytes), the palette and {len(icons)} bytes of icons -> {a.zxn}/')
    if a.sheet:
        sheet(a.sheet, table, palette, pictures, a.original)


if __name__ == '__main__':
    main()
