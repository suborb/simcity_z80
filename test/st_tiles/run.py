#!/usr/bin/env python3
"""tools/st_tiles_3bpp.py: the Atari ST art for the 3 bit targets.

Checks that every picture of both numberings is made from a real Micropolis tile, that the files have the sizes the game
expects, and, against the CPC art (which draws the same tiles another way), that the road tiles come from the ST tile whose shape
is closest.  Needs assets/st_tiles.bin and assets/cpc_tiles.bin (the art belongs to the games and is not in the repository); the
test is skipped without them.

  usage: test/st_tiles/run.py
"""
import os
import subprocess
import sys
import tempfile

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
sys.path.insert(0, os.path.join(ROOT, 'tools'))
ST = os.path.join(ROOT, 'assets/st_tiles.bin')
CPC = os.path.join(ROOT, 'assets/cpc_tiles.bin')


def main():
    if not (os.path.exists(ST) and os.path.exists(CPC)):
        print('SKIP  the Atari ST tile conversion (needs assets/st_tiles.bin and assets/cpc_tiles.bin)')
        return 0
    import extract_cpc_tiles as c
    import st_tiles_3bpp as t
    palette, table = t.load(ST)
    cpc = open(CPC, 'rb').read()
    ok = True

    ours = [t.st_picture_ours(i) for i in range(t.OURS)]
    fine = [t.st_picture_cpc(i) for i in range(t.CPC_COUNT)]
    good = all(0 <= n < 960 for n in ours + fine)
    print(('PASS' if good else 'FAIL') + f'  all {len(ours)} pictures of the engine\'s numbering and {len(fine)} of the CPC\'s are made from a Micropolis tile (0..959)')
    ok &= good

    # the same engine tile is the same ST picture in both numberings, and the zone blocks of the two agree where they should
    same = all(ours[i] == fine[i] for i in range(c.TILES))
    print(('PASS' if same else 'FAIL') + '  the 94 map tiles are the same in both numberings')
    ok &= same
    blocks = all(ours[c.TILES + p] == fine[c.cpc_picture(c.TILES + p)] for p in range(251))
    print(('PASS' if blocks else 'FAIL') + '  each of our pieces is the ST picture of the CPC picture it stands in for (the growth levels taken every other one)')
    ok &= blocks

    with tempfile.TemporaryDirectory() as tmp:
        for numbering, count in (('ours', t.OURS), ('cpc', t.CPC_COUNT)):
            p, m = os.path.join(tmp, 'p.bin'), os.path.join(tmp, 'm.bin')
            subprocess.run([sys.executable, os.path.join(ROOT, 'tools/st_tiles_3bpp.py'), ST, '--planes', p, '--mini', m, '--numbering', numbering],
                           check=True, capture_output=True)
            sizes = os.path.getsize(p) == count * 24 and os.path.getsize(m) == count * 5
            print(('PASS' if sizes else 'FAIL') + f'  --numbering {numbering}: {count} baked pictures of 24 bytes and as many mini map pictures of 5')
            ok &= sizes

    def mask_cpc(i):
        return [[1 if p else 0 for p in row] for row in c.pixels(cpc[i * 16:i * 16 + 16])]

    def mask_st(n):
        return [[0 if p in (5, 6) else 1 for p in row] for row in t.pixels(table[n * 32:n * 32 + 32])]

    def dist(a, b):
        return sum(abs(a[y][x] - b[y][x]) for y in range(8) for x in range(8))

    bad = []
    for i in range(7, 18):                      # the eleven road tiles: the closest in shape of the ST's eleven
        d = sorted((dist(mask_cpc(i), mask_st(n)), n) for n in range(66, 77))
        if d[0][1] != t.TILE[i] or d[1][0] - d[0][0] < 6:           # (the right one, and clearly)
            bad.append((i, t.TILE[i], d[:2]))
    print(('PASS' if not bad else 'FAIL') + '  each road tile (7..17) is the ST road tile of the same shape' + (f'  {bad}' if bad else ''))
    ok &= not bad
    return 0 if ok else 1


if __name__ == '__main__':
    sys.exit(main())
