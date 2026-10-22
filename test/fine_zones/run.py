#!/usr/bin/env python3
"""FINE_ZONE_LEVELS: the engine built with a picture for every growth level (as the CPC game has), not the
Spectrum's four.

Residential, commercial and industrial zones are drawn from blocks of nine pieces (a marker cell, then a group and a
piece in the cells after it); the group (piece / 8) of a block's first piece is also the zone's type, which
D_zone_handler_config turns into a handler and its parameters.  So the test checks, on the engine built with
-DFINE_ZONE_LEVELS and run for some years in the golden test's scenarios:
  * the table has an entry for the group of every block, and no other group is used by a built-up zone;
  * every zone cell drawn by the engine holds a piece the picture tables (assets: 94 + 377 pieces in the CPC
    layout) have, and the zone is of the type its pieces say;
  * commercial and industrial growth is written in the new numbering (the scenarios' cities do not live long enough to
    reach the deepest levels; run with --default to see the Spectrum's numbers instead).

  usage: test/fine_zones/run.py [--ticks N]
"""
import argparse
import importlib.util
import os
import re
import shutil
import sys
import tempfile
from collections import Counter

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
spec = importlib.util.spec_from_file_location('golden', os.path.join(ROOT, 'test', 'golden', 'run.py'))
g = importlib.util.module_from_spec(spec)
spec.loader.exec_module(g)

# block bases and number of levels: residential, commercial, industrial (see engine/simulation.asm)
BLOCKS = {'res': (136, 8), 'com': (208, 10), 'ind': (298, 8)}
LAST_PIECE = 376 + 0           # pieces 0..376: 245 of the Spectrum's, then 126 more
FIXED_GROUPS = {0, 1, 2, 3, 4, 6, 8, 10, 12}       # police, fire, church, hospital, stadium, coal, nuclear, port, airport


def block_groups():
    out = {}
    for kind, (base, n) in BLOCKS.items():
        out[kind] = [(base + 9 * i) >> 3 for i in range(n)]
    return out


def config_keys(src):
    """The zone types of the FINE_ZONE_LEVELS half of D_zone_handler_config, with their handler and level."""
    text = open(src, encoding='latin-1').read()
    part = text.split('IFDEF   FINE_ZONE_LEVELS')[1].split('ELSE')[0]
    return [tuple(int(v.strip().lstrip('$'), 16) for v in m.group(1).split(',')) for m in
            re.finditer(r'defb\s+(\$[0-9a-fA-F]+,\$[0-9a-fA-F]+,\$[0-9a-fA-F]+,\$[0-9a-fA-F]+)', part)]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--ticks', type=int, default=450)
    ap.add_argument('--default', action='store_true', help='build without the flag (to compare: the Spectrum numbering)')
    args = ap.parse_args()
    ok = True

    groups = block_groups()
    entries = config_keys(os.path.join(ROOT, 'engine', 'simulation.asm'))
    want = {}
    for kind, handler in (('res', 9), ('com', 10), ('ind', 11)):
        want[kind] = [(k, handler, i) for i, k in enumerate(groups[kind])]
    got = {kind: [(k, h, lvl) for k, h, lvl, _ in entries if h == handler] for kind, handler in (('res', 9), ('com', 10), ('ind', 11))}
    for kind in BLOCKS:
        same = got[kind] == want[kind]
        print(('PASS' if same else 'FAIL') + f'  {kind}: D_zone_handler_config has one entry for each of the {BLOCKS[kind][1]} blocks, keyed by the group of its first piece')
        if not same:
            print('       want', [(hex(k), h, i) for k, h, i in want[kind]]); print('       got ', [(hex(k), h, i) for k, h, i in got[kind]])
        ok &= same
    allkeys = [k for kind in BLOCKS for k, _, _ in want[kind]]
    unique = len(set(allkeys)) == len(allkeys) and not set(allkeys) & FIXED_GROUPS
    print(('PASS' if unique else 'FAIL') + '  the groups are all different, and none is one of the fixed zones\'')
    ok &= unique

    tmp = tempfile.mkdtemp(prefix='simcity_fine_')
    try:
        files = g.build(tmp)
        zx_bin, zx_map, po_bin, po_map = files
        g.run([g.Z80ASM, '-Iengine', '-DPORTABLE'] + ([] if args.default else ['-DFINE_ZONE_LEVELS']) + ['-DSIM_STACK_FILL', '-b', '-m',
               'target/test/test_platform.asm'], cwd=tmp)
        zx_syms, po_syms = g.parse_map(zx_map), g.parse_map(po_map)
        zxb, pob = open(zx_bin, 'rb').read(), open(po_bin, 'rb').read()
        # the three places the block is chosen, as the CPC game has them (its code at $37A0, $3837 and $38CE):
        #   residential  cp 8; jp/jr nc; [no srl a]; ld bc,(iter); ld de,136; jp write_zone_print_entries
        #   commercial   dec a; [no class table]; ld bc,(iter); ld de,208; jp write_zone_print_entries
        #   industrial   dec a; [no srl a]; ld bc,(iter); ld de,298; call write_zone_print_entries
        sites = {
            'residential': (rb'\xfe\x08[\x30\xd2].{1,2}\xed\x4b..\x11\x88\x00\xc3', rb'\xfe\x08[\x30\xd2].{1,2}\xcb\x3f\xed\x4b..\x11\x88\x00\xc3'),
            'commercial': (rb'\x3d\xed\x4b..\x11\xd0\x00\xc3', rb'\x3d\x4f\x06\x00\x21..\x09\x7e\xed\x4b..\x11\xac\x00\xc3'),
            'industrial': (rb'\x3d\xed\x4b..\x11\x2a\x01\xcd', rb'\x3d\xcb\x3f\xed\x4b..\x11\xd0\x00\xcd'),
        }
        for kind, (fine, coarse) in sites.items():
            has_fine = len(re.findall(fine, pob, re.S)) == 1
            has_coarse = bool(re.search(coarse, pob, re.S))
            print(('PASS' if has_fine and not has_coarse else 'FAIL') + f'  {kind}: the block is chosen as the CPC game does it' + ('' if has_fine else ' (not found)') + ('' if not has_coarse else ' (the Spectrum\'s code is still there)'))
            ok &= has_fine and not has_coarse
        used = Counter()
        pieces_bad = []
        for name in ('town', 'big'):
            city = g.City(zxb, zx_syms)
            g.SCENARIOS[name](city)

            def patch(img):
                img[po_syms['test_coop']] = 0
                img[po_syms['test_ticks']] = args.ticks & 255
                img[po_syms['test_ticks'] + 1] = args.ticks >> 8
            img = g.make_image(pob, 0x100, po_syms, city, patch)
            path = os.path.join(tmp, f'{name}_fine.img')
            open(path, 'wb').write(img)
            dump = g.tick(path, 0x100, po_syms['test_done'], os.path.join(tmp, f'{name}_fine.out'))
            lm = po_syms['levelmap']
            cells = dump[lm:lm + g.MAP_W * g.MAP_W]
            pop = int.from_bytes(dump[po_syms['V_CityPop']:po_syms['V_CityPop'] + 3], 'little')
            for i, c in enumerate(cells):
                if c & 0xE0 == 0xA0 or (c & 0xC0 == 0x80 and c & 0x20):       # a marker with bit 5: the top row of a big zone
                    grp, pc = cells[i + 1] & 63, cells[i + 2] & 7
                    piece = grp * 8 + pc
                    if grp in FIXED_GROUPS:
                        continue
                    used[grp] += 1
                    if piece > LAST_PIECE:
                        pieces_bad.append((name, i, piece))
            print(f'      {name}: {args.ticks} ticks, CityPop={pop}')
    finally:
        shutil.rmtree(tmp, ignore_errors=True)

    valid = set(allkeys)
    stray = {k: n for k, n in used.items() if k not in valid}
    print(('PASS' if not stray else 'FAIL') + f'  every built-up zone has a type from the table (groups seen: {sorted(used)})'
          + (f' - unknown groups {stray}' if stray else ''))
    ok &= not stray
    print(('PASS' if not pieces_bad else 'FAIL') + '  every piece is one the picture tables have')
    ok &= not pieces_bad
    # The scenarios' cities do not live long enough to reach the deeper levels (and residential does not build big
    # zones in them), but commercial and industrial zones must be using the new numbering: with the Spectrum's
    # (--default) they are groups 21 and 22 and 26.
    seen = {kind: sorted(k for k in used if k in groups[kind]) for kind in BLOCKS}
    new_numbers = bool(seen['com']) and bool(seen['ind'])
    print(('PASS' if new_numbers else 'FAIL') + f'  commercial and industrial zones are written with the new groups ({ {k: [hex(x) for x in v] for k, v in seen.items()} })')
    ok &= new_numbers
    return 0 if ok else 1


if __name__ == '__main__':
    sys.exit(main())
