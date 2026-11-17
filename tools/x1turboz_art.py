#!/usr/bin/env python3
"""Make the X1turboZ 64-colour atlas and put it on a bootable D88 image."""

import argparse
from pathlib import Path
import struct
import sys

sys.path.insert(0, str(Path(__file__).resolve().parent))
from st_tiles_3bpp import (CPC_COUNT, WATER_SHIFT, animation, near_identical,
                           pixels6, shift_water, st_picture_cpc)  # noqa: E402

ROOT = Path(__file__).resolve().parents[1]
SECTOR_BYTES = 256
SECTORS_PER_TRACK = 16


def make_art(outdir):
    raw = (ROOT / "assets/amiga_1meg_tiles.bin").read_bytes()
    assert len(raw) == 64 + 960 * 48 and CPC_COUNT == 471
    pics = raw[64:]
    pictures = [st_picture_cpc(i) for i in range(CPC_COUNT)]
    extra, amap, entries = animation(pictures)
    if near_identical(pics, 48, pixels6):
        extra = [WATER_SHIFT if n == 4 else n for n in extra]

    def tile(n):
        if n == WATER_SHIFT:
            rows = shift_water(pixels6(pics[2 * 48:3 * 48]))
            return bytes(sum(((row[x] >> p) & 1) << (7 - x) for x in range(8))
                         for p in range(6) for row in rows)
        return pics[n * 48:(n + 1) * 48]

    atlas = bytearray(b"".join(tile(n) for n in pictures + extra))
    icons = (ROOT / "assets/amiga_1meg_icons.bin").read_bytes()
    assert len(icons) == 14 * 22 * 20
    # Keep the X1's existing 14-across toolbar.  Scale each 22x20 Amiga
    # button to its 16x16 slot, split into four 8x8 graphics cells.
    for dim in (False, True):
        for icon in range(14):
            pixels = icons[icon * 440:(icon + 1) * 440]
            for cy in range(2):
                for cx in range(2):
                    for p in range(6):
                        for y in range(8):
                            sy = ((cy * 8 + y) * 20) // 16
                            bits = 0
                            for x in range(8):
                                dx = cx * 8 + x
                                sx = (dx * 22) // 16
                                colour = pixels[sy * 22 + sx]
                                if dim and ((dx ^ (cy * 8 + y)) & 1):
                                    colour = 0
                                bits |= ((colour >> p) & 1) << (7 - x)
                            atlas.append(bits)
    assert len(atlas) <= 8 * SECTORS_PER_TRACK * SECTOR_BYTES
    (outdir / "animmap.bin").parent.mkdir(parents=True, exist_ok=True)
    (outdir / "animmap.bin").write_bytes(amap)
    (outdir / "animtab.bin").write_bytes(b"".join(struct.pack("<HB", first, count - 1) for first, count in entries))
    words = struct.unpack(">32H", raw[:64])
    palette = list(words) + [((w >> 9 & 7) << 8) | ((w >> 5 & 7) << 4) | (w >> 1 & 7) for w in words]
    def pair_swap(i):
        return ((i & 0x15) << 1) | ((i & 0x2a) >> 1)

    # UI pixels use one bit from each Turbo Z two-bit component pair.
    ui_source = (0, 1, 4, 5, 16, 17, 20, 21)
    ui_hw = {pair_swap(i) for i in ui_source}
    rgb_levels = [((w >> 8) & 15, (w >> 4) & 15, w & 15) for w in palette]
    safe_source = [i for i in range(64) if pair_swap(i) not in ui_hw]
    remap = list(range(64))
    for i in range(64):
        if pair_swap(i) in ui_hw:
            remap[i] = min(safe_source, key=lambda j: sum((a-b) ** 2 for a,b in zip(rgb_levels[i], rgb_levels[j])))

    def remap_tile(data):
        rows = pixels6(data)
        return bytes(sum(((remap[row[x]] >> p) & 1) << (7-x) for x in range(8))
                     for p in range(6) for row in rows)

    atlas = bytearray(b"".join(remap_tile(atlas[i:i+48]) for i in range(0, len(atlas), 48)))
    rgb = bytearray(64 * 3)
    for i, word in enumerate(palette):
        at = pair_swap(i) * 3
        rgb[at:at+3] = bytes(((word >> 8) & 15, (word >> 4) & 15, word & 15))
    ui_rgb = ((0,0,0),(0,0,15),(0,15,0),(0,15,15),
              (15,0,0),(15,0,15),(15,15,0),(15,15,15))
    for i, colour in zip(ui_source, ui_rgb):
        at = pair_swap(i) * 3
        rgb[at:at+3] = bytes(colour)
    outdir.mkdir(parents=True, exist_ok=True)
    (outdir / "atlas.bin").write_bytes(atlas)
    (outdir / "palette.bin").write_bytes(rgb)
    return atlas


if __name__ == "__main__":
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--outdir", type=Path, default=ROOT / "build/x1turboz")
    args = ap.parse_args()
    data = make_art(args.outdir)
    print(f"{len(data)} atlas bytes (471 tiles, 76 animation frames, 112 icon cells); palette 192 bytes")
