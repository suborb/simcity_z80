#!/usr/bin/env python3
"""Make the map pictures of the 3 bit (8 colour) targets from Micropolis-numbered game art.

  tools/st_tiles_3bpp.py assets/st_tiles.bin --planes FILE [--numbering ours|cpc]
  tools/st_tiles_3bpp.py assets/st_tiles.bin --mini FILE [--numbering ours|cpc]
  tools/st_tiles_3bpp.py assets/st_tiles.bin --sam FILE [--numbering ours|cpc]
  tools/st_tiles_3bpp.py assets/st_tiles.bin --sheet FILE.png [--numbering ours|cpc] [--original]

The same files, in the same formats, as tools/extract_cpc_tiles.py makes from the CPC art (and so the same Makefile rules
and the same game): --planes the pictures baked into 8 colours, 24 bytes each (three planes, blue, red and green, of
eight rows), --mini the quarter size pictures for the mini maps, 5 bytes each.  The table is the one tools/extract_st_tiles.py
makes (the game's palette, then 32 byte pictures in the Micropolis numbering).

The ST and Amiga art have the Micropolis numbering and ours does not, so each of our pictures is taken from a Micropolis tile.  That mapping
(TILE, st_piece, st_picture_ours, st_picture_cpc) is the useful part and is not specific to the ST: it gives the Micropolis tile
number for each of our pictures, so any set of Micropolis-numbered tiles can be converted by loading its pictures (pixels(), to8()
and planes() below are the ST and Amiga planar format).  It was worked out by comparing the shapes of our tiles (the CPC art, which
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

The game's 16 colours become the machine's 8 by COLOUR (a table: a colour, or a pair that is dithered, one pixel in
two), which is the one place to change the look.  The art belongs to the game (see PORTING.md).

  --layout row|plane
                how a 32 byte picture is stored: `row`, the ST's (eight rows, each of the four bitplane bytes of the row) or `plane`, the Amiga's
                (the eight bytes of bitplane 0, then those of plane 1, 2 and 3: assets/amiga_tiles.bin is SimCity 512K's SimData2 as it is
                on the disk).  Inferred from the palette when omitted: a 4-bit palette is the Amiga's.
  --palette-bits N
                the bits in each source palette component: 3 for the ST ($0RGB, the default) or 4 for the Amiga.  It is inferred from
                the palette when omitted, and may be stated explicitly for a 4-bit palette whose entries happen all to be 0..7.
  --zxn DIR    the pictures for the ZX Spectrum Next's Layer 2 (256x192, a byte a pixel, the palette entry of each): head.bin (the 208
                palette entries as the Next's two bytes each: the ST's 16 for the interface, the art's 64, the art's inverted, the Amiga's 64 for the
                tool icons; the 8 attribute colours' entries; the 64 greys of a dimmed icon's colours) and icons.bin (the 14 Amiga tool icons, --amiga-icons, 22x20 a byte a pixel),
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


def palette_levels(palette, bits):
    """The source palette as 3-bit RGB tuples, for the SAM and Next palettes."""
    top = (1 << bits) - 1
    return [tuple((((w >> shift) & top) * 7 + top // 2) // top for shift in (8, 4, 0)) for w in palette]


def sam_palette(palette, bits):
    """The nearest SAM palette byte (0..127) to each source colour."""
    out = bytearray()
    for want in palette_levels(palette, bits):
        out.append(min(range(128), key=lambda c: (sum((a - b) ** 2 for a, b in zip(sam_level(c), want)), c)))
    return bytes(out)


def attr_colours(palette, bits):
    """The palette entry nearest each of the eight colours of a Spectrum attribute (bit 0 blue, 1 red, 2 green)."""
    out = bytearray()
    colours = palette_levels(palette, bits)
    for c in range(8):
        want = ((c >> 1) & 1, (c >> 2) & 1, c & 1)
        low = 0 if c == 0 else 1                # the channels that are off are a little on: the bright entries (light red, light
        out.append(min(range(16), key=lambda i: (sum((a - (7 if b else low)) ** 2 for a, b in zip(   # green...) are the ones wanted
            colours[i], want)), i)))
    return bytes(out)


def pixels6(pic):
    """The 8x8 colour indexes (0..63) of a 48 byte picture of the Amiga 1 Meg game: six bitplanes, the eight bytes of each one after another."""
    return [[sum((((pic[p * 8 + r] >> (7 - x)) & 1) << p) for p in range(6)) for x in range(8)] for r in range(8)]


AMIGA_1MEG = 64 + 960 * 48          # the size of assets/amiga_1meg_tiles.bin (tools/extract_amiga_1meg_tiles.py)


def zxn_palette(levels):
    """The Next's 9-bit palette (RRRGGGBB, then the low bit of blue) of colours given as 3-bit (r, g, b) levels."""
    out = bytearray()
    for r, g, b in levels:
        out += bytes(((r << 5) | (g << 2) | (b >> 1), b & 1))
    return bytes(out)


# The Next's Layer 2 palette: entries 0 to 15 are the Atari ST's colours, which the game's text, charts and mini maps use (whatever art the
# map has); 16 to 79 the art's own colours, which the map's pictures use; 80 to 143 the same colours inverted (the cursor); 144 to 159 the
# Amiga's colours for the tool icons.
ZXN_TILE_COLOURS = 64        # room for the 1 Meg art's 64 (32 and their halves); a 16 colour set uses the first 16
ZXN_TILE_BASE = 16
ZXN_INVERSE_BASE = ZXN_TILE_BASE + ZXN_TILE_COLOURS
ZXN_ICON_BASE = ZXN_INVERSE_BASE + ZXN_TILE_COLOURS     # the Amiga's colours (the icons' own file's: 16 or 64), for the tool icons (whatever the map's art is)

# The Amiga's 14 tool icons (tools/extract_amiga_icons.py or extract_amiga_1meg_icons.py: 22x20, a palette index a byte, in the engine's order).
ICON_W, ICON_H = 22, 20


def zxn_icon_palette(icons_path):
    """The palette of an icon file: the 3-bit levels of its 64 colours (the sibling file `..._tiles.bin` has the palette: the 512K's 16 words or the 1 Meg's 32 with
    their halves), and the grey each colour becomes when the icon is dimmed (an absolute Layer 2 palette index: the ST's dark grey, 8, or light grey, 7)."""
    path = os.path.join(os.path.dirname(icons_path), os.path.basename(icons_path).replace('icons', 'tiles'))
    raw = open(path, 'rb').read(64)
    if os.path.getsize(path) == AMIGA_1MEG:
        words = list(struct.unpack('>32H', raw))
        words += [((w >> 9 & 7) << 8) | ((w >> 5 & 7) << 4) | (w >> 1 & 7) for w in words]
    else:
        words = list(struct.unpack('>16H', raw[:32]))
    levels = palette_levels(words, 4)
    levels += [(0, 0, 0)] * (64 - len(levels))
    dim = bytes(8 if (30 * r + 59 * g + 11 * b) // 100 <= 2 else 7 for r, g, b in levels)
    return levels, dim


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


def sheet(path, table, palette, bits, pictures, original, scale=5):
    from PIL import Image
    cols = 32
    rows = (len(pictures) + cols - 1) // cols
    im = Image.new('RGB', (cols * 9 * scale, rows * 9 * scale), (30, 30, 40))
    top = (1 << bits) - 1
    rgb = [(((w >> 8) & top) * 255 // top, ((w >> 4) & top) * 255 // top, (w & top) * 255 // top) for w in palette]
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
    ap.add_argument('--amiga-icons', help='with --zxn: the tool icons (tools/extract_amiga_icons.py), with their palette, the first 32 bytes of amiga_tiles.bin beside them')
    ap.add_argument('--icons', help='with --sam: the tool icons (tools/extract_st_icons.py), put after the palette')
    ap.add_argument('--original', action='store_true')
    ap.add_argument('--palette-bits', choices=(3, 4), type=int,
                    help='bits per $0RGB component (default: infer 3 or 4 from the palette)')
    ap.add_argument('--layout', choices=('row', 'plane'), help='how a picture is stored: the ST\'s rows of plane bytes, or the Amiga\'s planes (default: by the palette)')
    ap.add_argument('--colours', choices=sorted(PRESETS), default='meadow')
    ap.add_argument('--numbering', choices=('ours', 'cpc'), default='ours')
    a = ap.parse_args()
    global COLOUR
    COLOUR = PRESETS[a.colours]
    depth6 = os.path.getsize(a.table) == AMIGA_1MEG
    if depth6:                                  # the Amiga 1 Meg game's art: 32 colours and their halves, 6 bitplanes: only the Next's atlas is made from it
        if not a.zxn or a.planes or a.mini or a.sam or a.sheet:
            sys.exit(f'{a.table}: the 1 Meg art has 64 colours: it makes only --zxn')
        raw = open(a.table, 'rb').read()
        words = struct.unpack('>32H', raw[:64])
        palette = list(words) + [((w >> 9 & 7) << 8) | ((w >> 5 & 7) << 4) | (w >> 1 & 7) for w in words]   # (the halves, in 4 bits: a bit less)
        table = raw[64:]
        PICSIZE = 48
    else:
        palette, table = load(a.table)
        PICSIZE = PIC
    bits = a.palette_bits or (4 if any(((w >> shift) & 15) > 7 for w in palette for shift in (8, 4, 0)) else 3)
    if not depth6 and (a.layout or ('plane' if bits == 4 else 'row')) == 'plane':      # the Amiga's: make each picture the ST's rows of plane bytes
        table = b''.join(bytes(table[n + p * 8 + r] for r in range(8) for p in range(4)) for n in range(0, len(table) - PIC + 1, PIC))
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
        data = sam_palette(palette, bits) + attr_colours(palette, bits) + icons + b''.join(sam_picture(pixels(table[n * PIC:n * PIC + PIC])) for n in pictures)
        open(a.sam, 'wb').write(data)
        print(f'{len(pictures)} pictures, {len(icons)} bytes of icons, a 16 byte palette, 8 attribute colours and {len(pictures) * 32} bytes of mode 4 pictures -> {a.sam}')
    if a.zxn:
        os.makedirs(a.zxn, exist_ok=True)
        if not a.amiga_icons:
            sys.exit('--zxn needs --amiga-icons')
        icons = open(a.amiga_icons, 'rb').read()
        if len(icons) != 14 * ICON_W * ICON_H:
            sys.exit(f'{a.amiga_icons}: {len(icons)} bytes, not the 14 icons of {ICON_W}x{ICON_H}')
        icon_levels, dim = zxn_icon_palette(a.amiga_icons)
        from extract_st_tiles import PALETTE as ST_PALETTE
        ui = list(struct.unpack('>16H', ST_PALETTE))
        art = palette_levels(palette, bits)
        art += [(0, 0, 0)] * (ZXN_TILE_COLOURS - len(art))
        pixel = pixels6 if depth6 else pixels
        pics = b''.join(bytes(ZXN_TILE_BASE + v for row in pixel(table[n * PICSIZE:n * PICSIZE + PICSIZE]) for v in row) for n in pictures)
        levels = palette_levels(ui, 3) + art + [(7 - r, 7 - g, 7 - b) for r, g, b in art] + icon_levels
        open(os.path.join(a.zxn, 'head.bin'), 'wb').write(zxn_palette(levels) + attr_colours(ui, 3) + dim)
        open(os.path.join(a.zxn, 'icons.bin'), 'wb').write(icons)
        open(os.path.join(a.zxn, 'atlas0.bin'), 'wb').write(pics[:16384])
        open(os.path.join(a.zxn, 'atlas1.bin'), 'wb').write(pics[16384:].ljust(8192, b'\0'))
        print(f'{len(pictures)} pictures of 64 bytes ({len(pics)} bytes), the palette, and the 14 icons -> {a.zxn}/')
    if a.sheet:
        sheet(a.sheet, table, palette, bits, pictures, a.original)


if __name__ == '__main__':
    main()
