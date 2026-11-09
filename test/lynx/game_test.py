#!/usr/bin/env python3
"""The game itself (build/lynx/simcity.bin, the program of the boot disc) headless under z88dk-ticks on z88dk's Lynx 128K model (lib/ticks/memory/lynx.lua): it is started at $0000 as the
bootstrap leaves it, loads its art from build/lynx/simcity.ldf with the model's WD1793, draws the title screen (frames come from -int 120000), takes a key (LYNX_KEYS) and makes a city.
The screens are the model's pixels (LYNX_SNAP: lynx-snap-N.ppm); snap/lynx-title.png and (with --full) snap/lynx-game.png are written for looking at.
The default run is the title screen (a few seconds); --full also starts a game: 1 for the easy level at 25 million cycles, the screen at 250 million (about 25 s).
"""
import os, subprocess, sys, tempfile

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
CFG = os.environ.get('ZCCCFG', os.path.expanduser('~/z88dk/lib/config'))
MODEL = os.path.join(CFG, '..', 'ticks', 'memory', 'lynx.lua')
PROG = os.path.join(ROOT, 'build/lynx/simcity.bin')
DISC = os.path.join(ROOT, 'build/lynx/simcity.ldf')


def run(snaps, counter, keys=''):
    tmp = tempfile.mkdtemp()
    r = subprocess.run(['z88dk-ticks', '-b', 'lua', '-lua', MODEL, '-int', '120000', '-pc', '0', '-counter', str(counter), '-output', os.path.join(tmp, 'mem.out'), PROG],
                       capture_output=True, text=True, cwd=tmp, env=dict(os.environ, ZCCCFG=CFG, LYNX_DISC=DISC, LYNX_OUTDIR=tmp, LYNX_SNAP=snaps, LYNX_KEYS=keys))
    out = []
    for n in range(1, len(snaps.split(',')) + 1):
        d = open(os.path.join(tmp, 'lynx-snap-%d.ppm' % n), 'rb').read()
        out.append(d[len(b'P6\n512 252\n255\n'):])
    return out


def pixels(d):
    return [tuple(d[i:i + 3]) for i in range(0, len(d), 3)]


def save(d, name):
    try:
        from PIL import Image
        os.makedirs(os.path.join(ROOT, 'snap'), exist_ok=True)
        Image.frombytes('RGB', (512, 252), d).save(os.path.join(ROOT, 'snap', name))
    except ImportError:
        pass


def main():
    bad = 0

    def check(n, c, x=''):
        nonlocal bad
        print(('ok   ' if c else 'FAIL ') + n + ('' if c else '  ' + str(x)))
        bad += not c

    (title,) = run('20000000', 21000000)
    save(title, 'lynx-title.png')
    px = pixels(title)
    white = sum(1 for p in px if p == (255, 255, 255))
    check('the title screen: text in white (%d pixels), nothing but black and white' % white, 500 < white < 3000 and set(px) <= {(0, 0, 0), (255, 255, 255)}, set(px))
    rows = [y for y in range(252) if any(px[y * 512 + x] != (0, 0, 0) for x in range(512))]
    check('the title screen: the banner row, the level prompt and three choices (rows used: %s)' % (rows[:3] + ['...'] + rows[-2:]), rows and rows[0] < 8 and 60 < rows[-1] < 100, rows[:5])
    if '--full' in sys.argv:
        (game,) = run('250000000', 251000000, '25000000:1:1,26500000:1:0')
        save(game, 'lynx-game.png')
        px = pixels(game)
        colours = set(px)
        check('the game: all the screen\'s colours show (%d of them)' % len(colours), len(colours) >= 6, colours)
        top = set(px[y * 512 + x] for y in range(0, 28) for x in range(512))
        check('the game: the status panel and the tool icons are coloured (%d colours in the top rows)' % len(top), len(top) >= 5, top)
        grass = sum(1 for p in px[40 * 512:] if p == (0, 255, 0))
        check('the game: a map of grass (%d green pixels below the panel)' % grass, grass > 20000, grass)
    print('FAILED' if bad else 'all ok')
    return 1 if bad else 0


if __name__ == '__main__':
    sys.exit(main())
