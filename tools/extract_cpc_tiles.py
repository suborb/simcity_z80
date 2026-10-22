#!/usr/bin/env python3
"""Extract the map pictures of the Amstrad CPC SimCity from a snapshot of the running game.

  tools/extract_cpc_tiles.py SNAPSHOT.sna [--out assets/cpc_tiles.bin] [--sheet sheet.png] [--palette cpc|class]
  tools/extract_cpc_tiles.py assets/cpc_tiles.bin --planes FILE [--numbering ours|cpc]    (from the table, no snapshot)

The CPC game runs in mode 1 (four pens) and draws 8x8 pictures of 16 bytes, two bytes a row, in the mode's interleaved
pixel format (pixel i of a byte: bit 7-i is its low bit, bit 3-i its high bit).  They are in one table, 471 of them,
at $9BC6: the engine's 94 map tiles, then its large zone pieces in the CPC game's numbering (see PORTING.md: the CPC
keeps a picture for every growth level where the Spectrum game folds them: 8 residential, 10 commercial and 8
industrial blocks of nine pieces, so the table has 377 pieces where ours has 251).

From a snapshot the output is the raw table (471 * 16 bytes); the table can be given instead of the snapshot for
everything but --preview.  The art belongs to the CPC game (see PORTING.md).

  --sheet   a contact sheet (needs Pillow): every picture, coloured as --palette says
  --planes  FILE: the pictures baked into the Multi 8's colours: three planes (blue, red, green: the Spectrum's bit
            order) of eight bytes (a pixel row each, bit 7 on the left) for every picture, 24 bytes a picture
  --numbering ours  the engine's own 345 pictures (94 tiles and 251 pieces), each drawn from the CPC picture that
                    stands in for it (REPRESENTATIVE); the default, as the engine without FINE_ZONE_LEVELS
              cpc   the CPC's 471, as the engine with FINE_ZONE_LEVELS (see PORTING.md)
  --preview FILE: the city on the snapshot's screen, the game's own colours beside the palettes (needs Pillow)
  --palette cpc    the pens as the game's own (muted) colours
            class  a palette for each kind of picture (CLASS_PALETTES), which is what --planes uses too

The game's four pens in its map pictures are a grey ground (pen 0), black lines and shadow (pen 1), red accents
(pen 2) and white highlights (pen 3).
"""
import argparse
import os
import sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..'))
TABLE = 0x9BC6                 # first picture
TILES = 94                     # the engine's map tiles
PIECE0 = TILES                 # picture number of piece 0
PIECES = 377
COUNT = TILES + PIECES         # 471
RAM = 0x100                    # the snapshot's RAM starts here (SNA header)

# the Spectrum's pieces in the same blocks (engine/simulation.asm): residential 136.., commercial 172.., industrial 208..
CLASS = [0, 0, 1, 1, 1, 2, 2, 3, 3, 3]          # D_density_class_table: commercial level -> block


def zx_piece(q):
    """The Spectrum piece (0..250) the CPC piece q stands in for: the growth levels the Spectrum folds together."""
    if q < 136:
        return q
    if q < 208:                                     # residential: eight blocks to our four
        return 136 + 9 * (((q - 136) // 9) >> 1) + (q - 136) % 9
    if q < 298:                                     # commercial: ten blocks to our four
        return 172 + 9 * CLASS[(q - 208) // 9] + (q - 208) % 9
    if q < 370:                                     # industrial: eight blocks to our four
        return 208 + 9 * (((q - 298) // 9) >> 1) + (q - 298) % 9
    return q - 126                                  # the seven pieces after them


def zx_picture(i):
    """The Spectrum picture number (0..344: tiles, then pieces) that CPC picture i stands in for."""
    return i if i < TILES else TILES + min(zx_piece(i - PIECE0), 250)


# The CPC picture that stands in for one of ours (the inverse of zx_picture): of the growth levels the Spectrum game
# folds into one block the CPC has several, and the one chosen is
RES_BLOCK = lambda a: 2 * a + 1                 # residential, of eight
COM_BLOCK = (1, 3, 5, 8)                        # commercial, of ten (the level of the density classes' middle)
IND_BLOCK = lambda a: 2 * a + 1                 # industrial, of eight
OURS = TILES + 251                              # the engine's pictures


def cpc_picture(i):
    """The CPC picture (0..470) that our picture i (0..344) is drawn from."""
    if i < TILES:
        return i
    p = i - TILES                               # our piece
    if p < 136:
        q = p
    elif p < 172:
        q = 136 + 9 * RES_BLOCK((p - 136) // 9) + (p - 136) % 9
    elif p < 208:
        q = 208 + 9 * COM_BLOCK[(p - 172) // 9] + (p - 172) % 9
    elif p < 244:
        q = 298 + 9 * IND_BLOCK((p - 208) // 9) + (p - 208) % 9
    else:
        q = p + 126
    return TILES + q


def load(path):
    """(snapshot header or None, RAM or None, the table of pictures) from a snapshot or from the table itself."""
    d = open(path, 'rb').read()
    if d[:8] == b'MV - SNA':
        ram = d[RAM:RAM + 65536]
        if len(ram) < 65536:
            sys.exit(f'{path}: the snapshot has less than 64 KB of RAM')
        return d, ram, ram[TABLE:TABLE + COUNT * 16]
    if len(d) != COUNT * 16:
        sys.exit(f'{path}: neither a CPC snapshot nor a table of {COUNT} pictures ({COUNT * 16} bytes)')
    return None, None, d


def pixels(tile):
    """The 8x8 pens of a 16 byte picture, rows of eight."""
    out = []
    for r in range(8):
        row = []
        for bx in range(2):
            b = tile[r * 2 + bx]
            for k in range(4):
                row.append(((b >> (7 - k)) & 1) | (((b >> (3 - k)) & 1) << 1))
        out.append(row)
    return out


# hardware colour -> RGB, for the game's own palette
HW = [(128, 128, 128), (128, 128, 128), (0, 255, 128), (255, 255, 128), (0, 0, 128), (255, 0, 128), (0, 128, 128),
      (255, 128, 128), (255, 0, 128), (255, 255, 128), (255, 255, 0), (255, 255, 255), (255, 0, 0), (255, 0, 255),
      (255, 128, 0), (255, 128, 255), (0, 0, 128), (0, 255, 128), (0, 255, 0), (0, 255, 255), (0, 0, 0), (0, 0, 255),
      (0, 128, 0), (0, 128, 255), (128, 0, 0), (128, 255, 128), (128, 255, 0), (128, 255, 255), (128, 0, 0),
      (128, 0, 255), (128, 128, 0), (128, 128, 255)]
SPEC = [(0, 0, 0), (0, 0, 205), (205, 0, 0), (205, 0, 205), (0, 205, 0), (0, 205, 205), (205, 205, 0), (205, 205, 205)]


# What kind of picture each one is, for its palette.  The tiles are the engine's 94 map tiles (the CPC art shows what
# they are); the pieces are in blocks (the placement tables in engine/tools_e.asm and the zone growth in
# engine/simulation.asm: see PORTING.md).
def picture_class(i):
    if i < TILES:
        if i in (0, 68, 92, 93):
            return 'water'
        if i in (1, 3, 4, 5):
            return 'shore'
        if i == 6:
            return 'trees'
        if i in (69, 70, 71, 72, 90, 91):
            return 'fire'
        if i in range(7, 20) or i in (31, 32) or i in range(52, 56):
            return 'road'
        if i in range(20, 31):
            return 'rail'
        if i in range(33, 44):
            return 'power'
        if i in range(44, 52):
            return 'power crossing'
        return 'land'                       # dirt, parks, the empty zones and their letters, rubble, radiation
    q = i - PIECE0
    for name, end in (('police', 9), ('fire station', 18), ('church', 27), ('hospital', 36), ('stadium', 52), ('coal', 68),
                      ('nuclear', 84), ('port', 100), ('airport', 136), ('residential', 208), ('commercial', 298),
                      ('industrial', 370)):
        if q < end:
            return name
    return 'land'


# pen 0..3 -> a colour of the Multi 8 (0 black, 1 blue, 2 red, 3 magenta, 4 green, 5 cyan, 6 yellow, 7 white)
CLASS_PALETTES = {
    # the ground is green and the lines are black; the pens that change are the accent (pen 2) and the highlight (pen 3)
    'land':        (4, 0, 2, 7),
    'water':       (5, 1, 7, 7),
    'shore':       (4, 1, 2, 7),
    'trees':       (4, 0, 0, 7),        # dark foliage, white blossom
    'fire':        (0, 0, 2, 6),        # flames on black
    'road':        (4, 0, 6, 7),        # yellow edge lines, white centre line
    'rail':        (4, 0, 2, 7),
    'power':       (4, 0, 2, 0),        # black lines (and red dots) over the ground
    'power crossing': (4, 0, 2, 7),     # white where they cross roads
    'residential': (4, 0, 2, 7),        # red roofs
    'commercial':  (4, 0, 1, 7),        # blue
    'industrial':  (4, 0, 6, 7),        # yellow
    'police':      (4, 0, 1, 7),        # blue
    'fire station': (4, 0, 2, 7),       # red
    'church':      (4, 0, 6, 7),        # yellow
    'hospital':    (4, 0, 5, 7),        # cyan
    'stadium':     (4, 0, 2, 7),        # red track and pitch (one pen)
    'coal':        (4, 0, 2, 7),
    'nuclear':     (4, 0, 6, 7),        # yellow, for the radiation
    'port':        (4, 0, 1, 7),        # blue, for the sea
    'airport':     (4, 0, 5, 7),        # cyan
}
# single pictures that want their own (number: palette)
PICTURE_PALETTES = {
    56: (4, 0, 6, 7), 57: (4, 0, 6, 7),                                     # parks: yellow flowers
    81: (4, 2, 2, 7), 84: (4, 2, 2, 7),                                     # the empty zones' letters: R red,
    82: (4, 1, 1, 7), 85: (4, 1, 1, 7),                                     # C blue
    83: (4, 6, 6, 7), 86: (4, 6, 6, 7),                                     # I yellow
}


def palette_of(i):
    return PICTURE_PALETTES.get(i) or CLASS_PALETTES[picture_class(i)]


def planes(tile, pal):
    """The 24 bytes of a baked picture: blue, red, green plane, eight pixel rows each."""
    px = pixels(tile)
    out = bytearray()
    for p in range(3):
        for row in px:
            b = 0
            for x, pen in enumerate(row):
                b |= ((pal[pen] >> p) & 1) << (7 - x)
            out.append(b)
    return bytes(out)


def preview(d, ram, table, name, scale=3):
    """The snapshot's screen (the CPC's: 32 columns at $C000, 80 bytes a character row) twice: as it is, and with each
    cell that is one of the table's pictures recoloured by palette_of()."""
    from PIL import Image
    index = {}
    for i in range(COUNT):
        index.setdefault(bytes(table[i * 16:i * 16 + 16]), i)
    game = [HW[d[0x2F + p] & 31] for p in range(4)]
    w, rows = 32, 24
    im = Image.new('RGB', (w * 8 * scale * 2 + 10, rows * 8 * scale), (30, 30, 40))
    for cy in range(rows):
        for cx in range(w):
            tile = bytes(ram[0xC000 + ((cy * 8 + r) & 7) * 0x800 + ((cy * 8 + r) >> 3) * 80 + cx * 2 + k]
                         for r in range(8) for k in range(2))
            i = index.get(tile)
            px = pixels(tile)
            for half, pal in ((0, game), (1, game if i is None else [SPEC[c] for c in palette_of(i)])):
                for y in range(8):
                    for x in range(8):
                        for dy in range(scale):
                            for dx in range(scale):
                                im.putpixel((half * (w * 8 * scale + 10) + cx * 8 * scale + x * scale + dx,
                                             cy * 8 * scale + y * scale + dy), pal[px[y][x]])
    im.save(name)
    print('preview ->', name)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('source', help='a CPC snapshot (.sna) or the table (assets/cpc_tiles.bin)')
    ap.add_argument('--out', default=os.path.join(ROOT, 'assets', 'cpc_tiles.bin'), help='where a snapshot\'s table goes')
    ap.add_argument('--sheet')
    ap.add_argument('--palette', choices=('cpc', 'class'), default='class')
    ap.add_argument('--preview', help='a picture of the snapshot\'s map: its own colours beside ours')
    ap.add_argument('--planes', help='write the pictures as three Multi 8 colour planes (24 bytes each)')
    ap.add_argument('--numbering', choices=('ours', 'cpc'), default='ours')
    args = ap.parse_args()

    d, ram, table = load(args.source)
    if any(table[(COUNT - 1) * 16:]):
        print('warning: the last picture is not blank - the table may be longer than expected')
    if d is not None:
        open(args.out, 'wb').write(table)
        print(f'{COUNT} pictures, {len(table)} bytes -> {args.out}')

    if args.preview:
        if d is None:
            sys.exit('--preview needs a snapshot')
        preview(d, ram, table, args.preview)

    if args.planes:
        if args.numbering == 'cpc':
            src = range(COUNT)
        else:
            src = [cpc_picture(i) for i in range(OURS)]
        out = b''.join(planes(table[j * 16:j * 16 + 16], palette_of(j)) for j in src)
        open(args.planes, 'wb').write(out)
        print(f'{len(src)} pictures, {len(out)} bytes of planes -> {args.planes}')

    if args.sheet:
        from PIL import Image
        game_pens = [HW[d[0x2F + p] & 31] for p in range(4)] if d is not None else HW[:4]
        cols, S = 24, 4
        rows = (COUNT + cols - 1) // cols
        im = Image.new('RGB', (cols * 9 * S, rows * 9 * S), (50, 50, 60))
        for i in range(COUNT):
            px = pixels(table[i * 16:i * 16 + 16])
            pal = game_pens if args.palette == 'cpc' else [SPEC[c] for c in palette_of(i)]
            for y in range(8):
                for x in range(8):
                    c = pal[px[y][x]]
                    for dy in range(S):
                        for dx in range(S):
                            im.putpixel(((i % cols) * 9 * S + x * S + dx, (i // cols) * 9 * S + y * S + dy), c)
        im.save(args.sheet)
        print('sheet ->', args.sheet)


if __name__ == '__main__':
    main()
