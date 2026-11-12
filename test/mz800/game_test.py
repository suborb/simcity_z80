#!/usr/bin/env python3
"""The game (build/mz800/simcity.d88) booted by the real IPL ROM on the ticks MZ-800 model, with scripted keys (the model's keyboard matrix is Takeda's): the title screen, a new city,
the popup menu (BREAK is Esc), and the evaluation screen from it.  The screens are the model's pixels (MZ800_SNAP); snap/mz800-*.png are written for looking at (about 20 s).
"""
import os, subprocess, sys, tempfile
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import ipl_boot

ROOT = ipl_boot.ROOT
DISC = os.path.join(ROOT, 'build/mz800/simcity.d88')


def key(at, name, hold=400000):
    return '%d:%s:1,%d:%s:0' % (at, name, at + hold, name)


def run(snaps, cycles, keys):
    tmp, r = ipl_boot.boot(DISC, cycles, ','.join(map(str, snaps)), {'MZ800_KEYS': ','.join(keys)})
    out = []
    for n in range(1, len(snaps) + 1):
        w, px = ipl_boot.ppm(os.path.join(tmp, 'mz800-snap-%d.ppm' % n))
        out.append(px)
    return out


def ipl_boot_snap(tmp, n):
    return ipl_boot.ppm(os.path.join(tmp, 'mz800-snap-%d.ppm' % n))[1]


def pixels(px):
    return [tuple(px[i:i + 3]) for i in range(0, len(px), 3)]


def save(px, name):
    try:
        from PIL import Image
        os.makedirs(os.path.join(ROOT, 'snap'), exist_ok=True)
        Image.frombytes('RGB', (320, 200), px).save(os.path.join(ROOT, 'snap', name))
    except ImportError:
        pass


def main():
    bad = 0

    def check(n, c, x=''):
        nonlocal bad
        print(('ok   ' if c else 'FAIL ') + n + ('' if c else '  ' + str(x)))
        bad += not c

    keys = [key(30000000, '1'), key(95000000, 'escape'), key(110000000, 'down'), key(114000000, 'return')]
    title, city, menu, evaluation = run([28000000, 92000000, 108000000, 140000000], 142000000, keys)
    for px, name in ((title, 'title'), (city, 'city'), (menu, 'menu'), (evaluation, 'evaluation')):
        save(px, 'mz800-%s.png' % name)
    BLUE, YELLOW, GREEN, RED = (0, 0, 255), (255, 255, 0), (0, 255, 0), (255, 0, 0)
    # (the pens are the bright colours of the IGRB colours: see mz_mode_bitmap)
    p = pixels(title)
    cols = set(p)
    check('title: yellow text on blue, nothing else (%d colours)' % len(cols), cols == {BLUE, YELLOW}, cols)
    check('title: the banner row has text, the rest of the screen below the choices is blank', any(q == YELLOW for q in p[:320 * 8]) and all(q == BLUE for q in p[320 * 80:]))
    p = pixels(city)
    cols = set(p)
    check('city: all four pens appear (%d colours)' % len(cols), len(cols) == 4, cols)
    check('city: the status panel (top 8 rows of cells) and the map below it', any(q == RED for q in p[:320 * 24]) and sum(q == YELLOW for q in p[320 * 100:]) > 5000)
    p = pixels(menu)
    check('menu: a popup box (a blue interior with a frame) over the city', sum(q == BLUE for q in p[320 * 80:320 * 160]) > 3000 and p[320 * 100 + 160] in (BLUE, YELLOW))
    check('menu differs from the city', menu != city)
    p = pixels(evaluation)
    check('evaluation: a text page on blue', sum(q == BLUE for q in p) > 40000 and sum(q == YELLOW for q in p) > 500, set(p))
    # save and load: a city saved to a slot (37 sectors from logical sector 256: cylinder 8, head 1), then loaded from the list
    M = 1000000
    keys = [key(30 * M, '1'), key(90 * M, 's'), key(98 * M, 'return'), key(106 * M, 't'), key(110 * M, 's'), key(114 * M, 't'), key(120 * M, 'return'),
            key(130 * M, 'space'), key(138 * M, 'l'), key(150 * M, 'return')]
    tmp, r = ipl_boot.boot(DISC, 175 * M, ','.join(str(x * M) for x in (128, 148, 170)), {'MZ800_KEYS': ','.join(keys)})
    log = open(os.path.join(tmp, 'fdc_log.txt')).read().splitlines()
    wrote = [l.split(' ', 1)[1] for l in log if ' wrote ' in l]
    # the slot's sectors: 36 of the map, then the header, each at every other ID from the first track of the slot (logical sector 256 + 16: cylinder 8, head 0 (track 17), ID 1 on); then the directory (sector 256)
    check('save: 38 sectors written (the map, the header, the directory), the directory last', len(wrote) == 38 and wrote[-1] == 'wrote c=8 h=1 r=1', wrote[:2] + wrote[-2:])
    check('save: the slot uses every other sector (odd IDs only)', all(int(w.split('r=')[1]) % 2 == 1 for w in wrote), wrote[:4])
    out = open(os.path.join(tmp, 'disk_out.txt')).read().splitlines()
    dirsec = bytes.fromhex(out[[i for i, l in enumerate(out) if l.startswith('8 1 1 ')][0]].split()[3])
    check('save: the directory has the name "tst" and the mark', dirsec[:3] == b'tst' and dirsec[244:248] == b'SCD1', dirsec[:12])
    check('no controller errors', not any('ERROR' in l for l in log), [l for l in log if 'ERROR' in l][:3])
    reads = [l for l in log if 'read sector' in l and 'track register 8' in l or 'track register 9' in l]
    check('load: the directory and the slot are read back (%d reads on the slot\'s cylinders)' % len(reads), len(reads) >= 38)
    px = pixels(ipl_boot_snap(tmp, 3))
    check('the city is on screen after the load', len(set(px)) == 4)
    return bad


if __name__ == '__main__':
    sys.exit(1 if main() else 0)
