#!/usr/bin/env python3
"""Convert extracted Amiga scenarios to the ZXN engine's 120x100 map format.

The Amiga saves 16-bit Micropolis tile words in column-major order.  The engine
stores one byte per map cell and encodes multi-cell zones as a marker, group and
piece per row.  This writes fixed-size records (engine map, 1-pixel-per-cell
colour preview, metadata) and 16 KB banks for the NEX linker.

    python3 tools/convert_amiga_scenarios.py build/amiga_scenarios build/zxn
"""
import argparse
import glob
import json
import os
import struct
import sys

from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from st_tiles_3bpp import ANIMATED, TILE, st_piece  # noqa: E402

W, H = 120, 100
MAP_BYTES = W * H
PREVIEW_BYTES = MAP_BYTES
POWER_BYTES = (W // 8) * H
TRAFFIC_BYTES = (W // 2) * (H // 2)
META_BYTES = 1024
POWER_AT = MAP_BYTES + PREVIEW_BYTES
TRAFFIC_AT = POWER_AT + POWER_BYTES
META_AT = TRAFFIC_AT + TRAFFIC_BYTES
RECORD_BYTES = META_AT + META_BYTES
BANK_BYTES = 16 * 1024
FIRST_BANK = 23

# Engine zone-piece offsets and their footprints: police, fire, church,
# hospital, stadium, coal, nuclear, seaport, airport, then R/C/I buildings.
ZONE_SHAPES = [(0, 3), (9, 3), (18, 3), (27, 3), (36, 4), (52, 4),
               (68, 4), (84, 4), (100, 6)]
ZONE_CANDIDATES = [(st_piece(p), p, width) for p, width in ZONE_SHAPES]
# The Amiga's stadium block is 795..810. The engine uses the same stadium
# piece as the other tile sets, but the Amiga scenario map numbers it 16 tiles
# later than st_piece()'s source art block.
ZONE_CANDIDATES.append((795, 36, 4))

# Micropolis saves every R/C/I growth stage, while this engine has four art
# stages per kind.  Recognize all source stages and render the nearest stage
# the engine supports instead of turning those buildings into rubble.
for first, count, source0, piece0, stages in (
        (261, 16, 261, 136, (3, 7, 11, 15)),
        (432, 20, 432, 172, (3, 7, 11, 17)),
        (621, 8, 621, 208, (1, 3, 5, 7))):
    for level in range(count):
        stage = min(range(4), key=lambda i: abs(level - stages[i]))
        ZONE_CANDIDATES.append((source0 + level * 9, piece0 + stage * 9, 3))

# Micropolis shoreline and road/path variants without direct TILE entries.
# Water animation tiles 3 and 4 are both canonical engine water (tile 0), not
# shoreline variants.  The other low IDs are assigned to the nearest supported
# dirt, water or shore picture.
SOURCE_ALIASES = {
    1: 2, 3: 0, 4: 0, 5: 4, 6: 5, 8: 5, 10: 1, 11: 0,
    12: 1, 13: 3, 14: 0, 15: 3, 17: 3, 18: 3, 20: 4,
    140: 17, 141: 49,
    144: 18, 145: 19,
    157: 49, 158: 48, 159: 0, 160: 18, 161: 19,
    175: 0, 176: 18, 177: 19,
    189: 49, 190: 48, 191: 0, 192: 18, 193: 19,
    194: 7, 195: 8, 207: 0,
    # The Amiga saves alternate road art in separate tile ranges. These use
    # the same Micropolis path order as 66..76, except 148..156 etc. omit the
    # straight roads.  Preserve topology using the engine's 7..17 codes.
    148: 11, 149: 9, 150: 10, 151: 12, 152: 14, 153: 16,
    154: 13, 155: 15, 156: 17,
    164: 11, 165: 9, 166: 10, 167: 12, 168: 14, 169: 16,
    170: 13, 171: 15, 172: 17,
    180: 11, 181: 9, 182: 10, 183: 12, 184: 14, 185: 16,
    186: 13, 187: 15, 188: 17,
    196: 11, 197: 9, 198: 10, 199: 12, 200: 14, 201: 16,
    202: 13, 203: 15, 204: 17,
    # Alternate busy-road frames and bridge/water pictures.
    178: 7, 179: 8,
    80: 18, 81: 19, 82: 7, 83: 8, 84: 11, 85: 9, 86: 10, 87: 12,
    88: 14, 89: 16, 90: 13, 91: 15, 92: 17, 93: 49, 94: 48,
    # These four pictures are the wide raised-bridge end caps, not four
    # independent vertical bridge cells. Their map placement is inferred from
    # the paired cap pattern below.
    948: 0, 949: 0, 950: 0, 951: 0,
}
# The Amiga tile sheet has three alternate 16-tile path blocks at 96, 112 and
# 128. Each repeats the road bridges, eleven road shapes, road/power crossings,
# and water tile. These are map paths, not rubble or zone fragments.
ALT_PATH_CODES = (18, 19, 7, 8, 11, 9, 10, 12, 14, 16, 13, 15, 17, 49, 48, 0)
for first in (96, 112, 128):
    for offset, code in enumerate(ALT_PATH_CODES):
        SOURCE_ALIASES[first + offset] = code
BUSY_ROAD_TILES = {146: 7, 162: 7, 147: 8, 163: 8,
                   178: 7, 179: 8, 194: 7, 195: 8}

# Empty commercial and industrial lots use the same 3x3 ring artwork as an
# empty residential lot, with a different centre tile.  Convert their outer
# eight cells through the engine's residential ring art table.
# Source tiles are row-major.  The engine's ring art is laid out as:
#   49 4A 4B
#   50 -- 4C
#   4F 4E 4D
EMPTY_ZONE_RING_CODES = (73, 74, 75, 80, None, 76, 79, 78, 77)
for first in (423, 612):
    for offset, code in enumerate(EMPTY_ZONE_RING_CODES):
        if code is not None:
            SOURCE_ALIASES[first + offset] = code

# Save files can contain the currently displayed frame in the map itself.
# Convert those frame IDs back to their static tile/piece before matching zones.
ANIMATION_BASE = {}
for base, frames in ANIMATED.items():
    if isinstance(frames, tuple):
        first, count = frames
        frames = range(first, first + count)
    for frame in frames:
        ANIMATION_BASE[frame] = base
# Stadium game frames replace two cells in the Amiga's 795..810 stadium block
# (the source uses 932 for cell 801 and 940 for cell 805).
for frame in range(932, 948):
    ANIMATION_BASE[frame] = 795 + frame - 932
ANIMATION_BASE[932] = 801
ANIMATION_BASE[940] = 805
# The Amiga's animatedTiles table also substitutes a few industrial zone
# pieces with frame IDs that are not in the subset animated by our renderer.
# Reverse those substitutions so a saved frame still matches its 3x3 zone.
for base, first, count in ((621, 852, 8), (641, 884, 4), (644, 888, 4),
                           (676, 900, 4), (677, 904, 4)):
    for frame in range(first, first + count):
        ANIMATION_BASE[frame] = base


def ascii_text(value):
    return value.encode('ascii', 'replace')


def make_meta(info):
    title = ascii_text(info['title'])[:23]
    event = ascii_text(info['event'])[:31]
    desc = ascii_text(info['description'])[:META_BYTES - 64]
    out = bytearray(META_BYTES)
    struct.pack_into('<HBBH', out, 0, info['year'], len(title), len(event), len(desc))
    out[8:8 + len(title)] = title
    out[32:32 + len(event)] = event
    out[64:64 + len(desc)] = desc
    return bytes(out)


def image_palette(path):
    """Return the 64 Amiga colours as RGB values, in the ZXN art order."""
    raw = open(path, 'rb').read()
    if len(raw) < 64:
        raise ValueError(f'{path}: missing Amiga palette')
    words = struct.unpack('>32H', raw[:64])
    words += tuple(((w >> 9 & 7) << 8) | ((w >> 5 & 7) << 4) | (w >> 1 & 7)
                   for w in words)
    return [tuple(((w >> shift) & 15) * 17 for shift in (8, 4, 0)) for w in words]


def preview_pixels(map_path, tiles_path, palette):
    """The scenario's mini preview: a colour (16 + the Amiga palette's index) for each of the 120x100 tiles, that of the pixel at the middle of the tile's own picture
    (4, 4) in the 1 Meg art (assets/amiga_1meg_tiles.bin: a 64 byte palette, then 48 bytes of 6 bitplanes of 8 rows for each tile)."""
    tiles = open(tiles_path, 'rb').read()
    raw = open(map_path, 'rb').read()
    rgb_of = {}
    lookup = {}
    out = bytearray(MAP_BYTES)
    for y in range(H):
        for x in range(W):
            tile = int.from_bytes(raw[(x * H + y) * 2:(x * H + y) * 2 + 2], 'big') & 0x3ff
            if tile not in rgb_of:
                at = 64 + 48 * tile
                if at + 48 <= len(tiles):
                    index = sum(((tiles[at + plane * 8 + 4] >> 3) & 1) << plane for plane in range(6))
                    rgb_of[tile] = palette[index]
                else:
                    rgb_of[tile] = (0, 0, 0)            # (no such picture: the 960 pictures are all there are)
            rgb = rgb_of[tile]
            p = lookup.get(rgb)
            if p is None:
                p = min(range(64), key=lambda i: sum((rgb[k] - palette[i][k]) ** 2 for k in range(3)))
                lookup[rgb] = p
            out[y * W + x] = 16 + p
    return bytes(out)


def encode_zone(dst, x, y, piece, width, powered):
    for dy in range(width):
        row = y + dy
        left = row * W + x
        marker = 0x80 | (0x10 if powered else 0) | width
        if dy == 0:
            marker |= 0x20
        dst[left] = marker
        dst[left + 1] = 0xC0 | ((piece + dy * width) >> 3 & 63)
        dst[left + 2] = 0xC0 | ((piece + dy * width) & 7)
        for dx in range(3, width):
            dst[left + dx] = 0xC0


def infer_raised_bridges(tile_ids):
    """Return logical bridge spines and decorative overhangs from Amiga art.

    The Amiga stores a two-cell-wide cap at each end of a raised bridge, but
    the road itself is one cell wide.  948/949 and 950/951 bracket the span;
    tile 65 at the lower end confirms the bridge orientation.  Rebuild the
    single vertical road through the water and discard the right-hand art
    overhang, which has no logical road cell in the engine map.
    """
    spine = set()
    overhang = set()
    for y in range(H - 5):
        for x in range(W - 1):
            if (tile_ids[y][x] == 948 and tile_ids[y][x + 1] == 949 and
                    tile_ids[y + 4][x] == 950 and tile_ids[y + 4][x + 1] == 951 and
                    tile_ids[y + 5][x] == 65):
                spine.update((x, yy) for yy in range(y, y + 5))
                overhang.update(((x + 1, y), (x + 1, y + 4)))
    return spine, overhang


def convert_map(path, tiles_png):
    raw = open(path, 'rb').read()
    if len(raw) != MAP_BYTES * 2:
        raise ValueError(f'{path}: expected {MAP_BYTES * 2} map bytes')
    # The extractor emits big-endian Micropolis words, stored column-major.
    src = [[int.from_bytes(raw[(x * H + y) * 2:(x * H + y) * 2 + 2], 'big')
            for x in range(W)] for y in range(H)]
    tile_ids = [[ANIMATION_BASE.get(v & 0x3FF, v & 0x3FF) for v in row] for row in src]
    raised_bridge_spine, raised_bridge_overhang = infer_raised_bridges(tile_ids)
    base_source = {}
    for code, source in TILE.items():
        # Several engine pictures share Micropolis tile 2.  Keep the first
        # (TILE_WATER) code; the later 92/93 pictures are art aliases, not map
        # water codes for the simulation.
        base_source.setdefault(source, code)
    # Preserve raised-bridge underlay art (79 horizontal, 95 vertical) as
    # dedicated engine water tiles (87/88). A detected vertical bridge span
    # below overrides its underlay cells with the logical road bridge.
    # Busy-road pictures in a saved city are only a snapshot. The engine
    # animates ordinary horizontal/vertical roads from live traffic density.
    # Convert all static busy-road variants back to those ordinary roads.
    base_source.update({146: 7, 162: 7, 147: 8, 163: 8})
    # The three compact R/C/I zone centres have powered and unpowered forms.
    for source, kind in ((244, 0), (427, 1), (616, 2)):
        base_source.pop(source, None)

    source_piece = {}
    for p in range(244):
        t = st_piece(p)
        if t != 454 and t not in source_piece:
            source_piece[t] = p

    # Match complete source art blocks before translating individual tiles.
    # A scenario's intact buildings use the same Micropolis rows as the engine
    # picture table; encode_zone stores those rows in the engine's compact form.
    matched = [[False] * W for _ in range(H)]
    out = bytearray([2]) * MAP_BYTES
    power = bytearray(POWER_BYTES)
    traffic = bytearray(TRAFFIC_BYTES)

    # The source stores a busy-road picture, not the traffic density that made
    # it busy. Seed the corresponding 2x2 density cell so live road animation
    # starts with the same congestion after loading the scenario.
    for y in range(H):
        for x in range(W):
            if tile_ids[y][x] in BUSY_ROAD_TILES:
                i = (y >> 1) * (W // 2) + (x >> 1)
                traffic[i] = max(traffic[i], 180)

    def mark_powered_rect(x, y, width):
        for yy in range(max(0, y), min(H, y + width)):
            row = yy * (W // 8)
            for xx in range(max(0, x), min(W, x + width)):
                power[row + (xx >> 3)] |= 0x80 >> (xx & 7)

    buildings = 0
    compact_centres = []
    for y in range(H):
        for x in range(W):
            if matched[y][x]:
                continue
            for source_base, piece, width in ZONE_CANDIDATES:
                if x + width > W or y + width > H:
                    continue
                good = True
                for dy in range(width):
                    for dx in range(width):
                        if tile_ids[y + dy][x + dx] != source_base + dy * width + dx:
                            good = False
                            break
                    if not good:
                        break
                if not good:
                    continue
                # Retain the Amiga's saved power state for ordinary zones.  The
                # simulation discovers coal and nuclear stations by scanning
                # for their powered top marker ($B4), so those must seed a new
                # power map even when the Amiga's saved-grid flag is clear.
                # Micropolis stores the powered state on a zone's centre
                # tile, not its top-left art tile.  The centre is the source
                # tile whose high bit carries the saved power flag.
                # The Amiga stores the power flag on the lower-left tile of
                # the central 2x2 for even-sized zones (and the single centre
                # tile for odd sizes).
                # Most even-sized source zones store their saved power flag
                # on the lower-left tile of the central 2x2. The 6x6 airport
                # is an exception: Micropolis stores it at offset (1, 1).
                centre_offset = 1 if piece == 100 else (width - 1) // 2
                centre = src[y + centre_offset][x + centre_offset]
                powered = bool(centre & 0x8000) or 52 <= piece < 84
                encode_zone(out, x, y, piece, width, powered)
                if powered:
                    mark_powered_rect(x, y, width)
                for dy in range(width):
                    for dx in range(width):
                        matched[y + dy][x + dx] = True
                buildings += 1
                break

    # For ordinary terrain/path tiles use the engine's exact tile mapping.
    # A few Amiga variants do not have a direct engine equivalent; map them to
    # their closest supported terrain class. Disaster damage is applied by the
    # engine, so source rubble and incomplete developed fragments start as dirt.
    for y in range(H):
        for x in range(W):
            if matched[y][x]:
                continue
            t = tile_ids[y][x]
            if (x, y) in raised_bridge_spine:
                code = 19
            elif (x, y) in raised_bridge_overhang:
                code = 0
            elif t in base_source:
                code = base_source[t]
            elif t in SOURCE_ALIASES:
                code = SOURCE_ALIASES[t]
            elif t in (244, 427, 616):
                k = (244, 427, 616).index(t)
                code = 81 + k if src[y][x] & 0x8000 else 84 + k
                powered = bool(src[y][x] & 0x8000)
                compact_centres.append((x, y, k, powered))
                if powered:
                    mark_powered_rect(x - 1, y - 1, 3)
            elif 0 <= t <= 20:
                code = 0 if t == 2 else (1 + (t - 4) % 5 if t >= 4 else 0)
            elif 21 <= t <= 43:
                code = 6
            elif 249 <= t <= 260:
                # The engine has eight house tiles; the four extra Amiga house
                # variants use the nearest stage in that sequence.
                code = 60 + min(7, max(0, (t - 249 + 1) // 2))
            elif t in source_piece or 261 <= t <= 827 or t >= 828:
                code = 2
            else:
                code = 2
            out[y * W + x] = code
    # Compact zone centres represent 3x3 footprints. Preserve the zone marker
    # and clear any route tile that overlaps its footprint to suitable ground.
    for cx, cy, kind, powered in compact_centres:
        ground = 63 if kind == 0 else 2
        for yy in range(max(0, cy - 1), min(H, cy + 2)):
            for xx in range(max(0, cx - 1), min(W, cx + 2)):
                t = tile_ids[yy][xx]
                if 64 <= t <= 95 or 208 <= t <= 238:
                    out[yy * W + xx] = ground
    return bytes(out), buildings, bytes(power), bytes(traffic)


def build_banks(records, outdir):
    data = b''.join(records)
    os.makedirs(outdir, exist_ok=True)
    paths = []
    for i, start in enumerate(range(0, len(data), BANK_BYTES)):
        path = os.path.join(outdir, f'scenarios_{i:02}.bin')
        with open(path, 'wb') as f:
            chunk = data[start:start + BANK_BYTES]
            f.write(chunk.ljust(BANK_BYTES, b'\0'))
        paths.append(path)
    asm = os.path.join(outdir, 'scenarios.asm')
    with open(asm, 'w') as f:
        f.write('; Generated scenario data; each NEX bank is 16 KB.\n')
        for i, path in enumerate(paths):
            f.write(f'        SECTION BANK_{FIRST_BANK + i}\n')
            f.write(f'        BINARY "{path}"\n\n')
    return asm


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('scenario_dir')
    ap.add_argument('outdir')
    ap.add_argument('--tiles', default='assets/amiga_1meg_tiles.bin')
    args = ap.parse_args()
    if not os.path.isfile(args.tiles):
        sys.exit(f'{args.tiles}: missing Amiga 1 Meg tile palette')
    palette = image_palette(args.tiles)
    records = []
    files = sorted(glob.glob(os.path.join(args.scenario_dir, '*.map')))
    if not files:
        sys.exit(f'{args.scenario_dir}: no extracted .map files')
    for path in files:
        stem = os.path.splitext(os.path.basename(path))[0]
        json_path = os.path.join(args.scenario_dir, stem + '.json')
        if not os.path.isfile(json_path):
            sys.exit(f'{stem}: expected its .json extracted scenario text beside the .map')
        info = json.load(open(json_path, encoding='utf-8'))
        converted, buildings, power, traffic = convert_map(path, None)
        preview = preview_pixels(path, args.tiles, palette)
        records.append(converted + preview + power + traffic + make_meta(info))
        print(f'{info["title"]:16} {info["year"]}: converted map, {buildings} intact zones, preview and scenario text')
    expected = 8
    if len(records) > expected:
        raise ValueError(f'expected at most {expected} scenarios, got {len(records)}')
    while len(records) < expected:
        records.append(bytes(RECORD_BYTES))
    asm = build_banks(records, args.outdir)
    print(f'{len(records)} scenario slots ({RECORD_BYTES} bytes each) -> {asm}')


if __name__ == '__main__':
    main()
