#!/usr/bin/env python3
"""Extract the Amiga 1.2.2 scenario maps and descriptions from the 1 Meg disk.

    tools/extract_amiga_adf.py simclassics_scc_1meg.adf --outdir build/amiga_1meg_adf
    tools/extract_amiga_scenarios.py build/amiga_1meg_adf          (writes assets/amiga_scenarios)

What it writes, for each scenario, is what tools/convert_amiga_scenarios.py reads: NAME.map (the 120x100 map words) and NAME.json (the title, year, event and
description).  Those are committed with the other art assets (assets/amiga_scenarios), so the disk image itself is needed only to extract them again (make
amiga-scenarios).  --debug-images also writes NAME.city (the whole data fork) and NAME.png (a rendered 960x800 preview, which needs --tiles), neither of
which anything uses.

The source directory is the output of tools/extract_amiga_adf.py. Each scenario
is a MacBinary CITY file with a 27,120-byte data fork: a 3,120-byte city header
and histories followed by 120x100 big-endian Micropolis map words in column-major
order (`x * 100 + y`). Description
strings are in Classic Graphics.SimData.
"""
import argparse
import json
import os
import re
import sys

WIDTH, HEIGHT = 120, 100
HEADER = 3120
MAP_BYTES = WIDTH * HEIGHT * 2
MACBINARY_HEADER = 128


def macbinary_data(path):
    raw = open(path, 'rb').read()
    if len(raw) < MACBINARY_HEADER or raw[0] != 0:
        raise ValueError(f'{path}: not a MacBinary file')
    name_len = raw[1]
    if not 1 <= name_len <= 63:
        raise ValueError(f'{path}: invalid MacBinary filename')
    name = raw[2:2 + name_len].decode('mac_roman')
    if raw[65:69] != b'CITY' or raw[69:73] != b'MCRP':
        raise ValueError(f'{path}: not an Amiga SimCity CITY file')
    size = int.from_bytes(raw[83:87], 'big')
    fork = raw[MACBINARY_HEADER:MACBINARY_HEADER + size]
    if len(fork) != size or size != HEADER + MAP_BYTES:
        raise ValueError(f'{path}: expected a {HEADER + MAP_BYTES}-byte city data fork, got {size}')
    return name, fork


def scenario_texts(path):
    data = open(path, 'rb').read()
    records = []
    current = None
    for raw in data[:0x1fb1].split(b'\0'):
        if raw.startswith(b'\x07') and len(raw) > 2:
            if current:
                records.append(current)
            current = {'label': raw[2:].decode('latin1').strip(), 'lines': []}
        elif current and raw and any(c >= 32 for c in raw):
            line = raw.decode('latin1').strip()
            if line:
                current['lines'].append(line)
    if current:
        records.append(current)

    out = {}
    for record in records:
        lines = record['lines']
        title_at = next((i for i, s in enumerate(lines) if re.search(r'\s{2,}(?:19|20)\d{2}$', s)), None)
        if title_at is None or title_at + 1 >= len(lines):
            continue
        title_line = lines[title_at]
        m = re.match(r'(.+?)\s{2,}((?:19|20)\d{2})$', title_line)
        if not m:
            continue
        title, year = m.group(1).strip(), int(m.group(2))
        key = re.sub(r'[^a-z0-9]', '', title.lower())
        out[key] = {
            'title': title,
            'year': year,
            'event': lines[title_at + 1],
            'description_lines': lines[title_at + 2:],
            'description': ' '.join(lines[title_at + 2:]),
        }
    return out


def render_map(fork, tiles, path):
    from PIL import Image
    words = [int.from_bytes(fork[i:i + 2], 'big') & 0x3ff
             for i in range(HEADER, HEADER + MAP_BYTES, 2)]
    preview = Image.new('RGB', (WIDTH * 8, HEIGHT * 8))
    for x in range(WIDTH):
        for y in range(HEIGHT):
            tile = words[x * HEIGHT + y]
            sx, sy = (tile % 32) * 8, (tile // 32) * 8
            preview.paste(tiles.crop((sx, sy, sx + 8, sy + 8)), (x * 8, y * 8))
    preview.save(path)


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('extracted_disk', help='directory written by extract_amiga_adf.py')
    ap.add_argument('--outdir', default='assets/amiga_scenarios')
    ap.add_argument('--debug-images', action='store_true', help='also write NAME.city and a rendered NAME.png (for looking at; nothing reads them)')
    ap.add_argument('--tiles', default='assets/amiga_1meg_classic_tiles_8x8.png')
    args = ap.parse_args()
    scenario_dir = os.path.join(args.extracted_disk, 'Scenarios')
    graphics = os.path.join(args.extracted_disk, 'Classic Graphics.SimData')
    if not os.path.isdir(scenario_dir) or not os.path.isfile(graphics):
        sys.exit(f'{args.extracted_disk}: expected Scenarios/ and Classic Graphics.SimData')
    try:
        tiles = None
        if args.debug_images:
            from PIL import Image
            tiles = Image.open(args.tiles).convert('RGB')
            if tiles.size != (256, 240):
                raise ValueError(f'{args.tiles}: expected a 256x240 sheet of 8x8 tiles')
        texts = scenario_texts(graphics)
        os.makedirs(args.outdir, exist_ok=True)
        count = 0
        for filename in sorted(os.listdir(scenario_dir)):
            source = os.path.join(scenario_dir, filename)
            if not os.path.isfile(source) or filename.endswith('.info'):
                continue
            name, fork = macbinary_data(source)
            key = re.sub(r'[^a-z0-9]', '', name.lower())
            # The Amiga disk's MacBinary header misspells the filename; its in-game title and description are correct.
            if key == 'riodejanerio':
                key = 'riodejaneiro'
            if key not in texts:
                raise ValueError(f'{filename}: no matching scenario description in graphics resource')
            stem = re.sub(r'[^A-Za-z0-9]+', '_', name).strip('_')
            map_path = os.path.join(args.outdir, stem + '.map')
            text_path = os.path.join(args.outdir, stem + '.json')
            with open(map_path, 'wb') as f:
                f.write(fork[HEADER:])
            with open(text_path, 'w') as f:
                json.dump(texts[key], f, indent=2, ensure_ascii=False)
                f.write('\n')
            if args.debug_images:
                with open(os.path.join(args.outdir, stem + '.city'), 'wb') as f:
                    f.write(fork)
                render_map(fork, tiles, os.path.join(args.outdir, stem + '.png'))
            print(f'{name:16} {texts[key]["year"]}: 120x100 map and text extracted')
            count += 1
        print(f'{count} scenarios written to {args.outdir}')
    except (OSError, ValueError) as e:
        sys.exit(str(e))


if __name__ == '__main__':
    main()
