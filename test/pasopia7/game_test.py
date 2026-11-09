#!/usr/bin/env python3
"""The game itself (build/pasopia7/simcity, the program of the boot disk) headless under z88dk-ticks on z88dk's Pasopia 7 model (lib/ticks/memory/pasopia7.lua): it is started at $0000 as the
bootstrap leaves it, loads its art from build/pasopia7/simcity.dsk with the model's uPD765, draws the title screen (the time is the CTC's), takes a key (PASOPIA_KEYS) and makes a city.
The screens are the model's pixels (PASOPIA_SNAP: pasopia-snap-N.ppm); snap/pasopia7-title.png and (with --full) snap/pasopia7-game.png are written for looking at.
The default run is the title screen (a few seconds); --full also starts a game: 1 for the easy level at 25 million cycles, the screen at 250 million (about 25 s).
"""
import os, subprocess, sys, tempfile

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
CFG = os.environ.get('ZCCCFG', os.path.expanduser('~/z88dk/lib/config'))
MODEL = os.path.join(CFG, '..', 'ticks', 'memory', 'pasopia7.lua')
PROG = os.path.join(ROOT, 'build/pasopia7/simcity')
DISC = os.path.join(ROOT, 'build/pasopia7/simcity.dsk')


def run(snaps, counter, keys=''):
    tmp = tempfile.mkdtemp()
    r = subprocess.run(['z88dk-ticks', '-b', 'lua', '-lua', MODEL, '-pc', '0', '-counter', str(counter), '-output', os.path.join(tmp, 'mem.out'), PROG],
                       capture_output=True, text=True, cwd=tmp, env=dict(os.environ, ZCCCFG=CFG, PASOPIA_DISC=DISC, PASOPIA_OUTDIR=tmp, PASOPIA_SNAP=snaps, PASOPIA_KEYS=keys))
    out = []
    for n in range(1, len(snaps.split(',')) + 1):
        d = open(os.path.join(tmp, 'pasopia-snap-%d.ppm' % n), 'rb').read()
        out.append(d[len(b'P6\n320 200\n255\n'):])
    return out


def pixels(d):
    return [tuple(d[i:i + 3]) for i in range(0, len(d), 3)]


def save(d, name):
    try:
        from PIL import Image
        os.makedirs(os.path.join(ROOT, 'snap'), exist_ok=True)
        Image.frombytes('RGB', (320, 200), d).save(os.path.join(ROOT, 'snap', name))
    except ImportError:
        pass


def main():
    bad = 0

    def check(n, c, x=''):
        nonlocal bad
        print(('ok   ' if c else 'FAIL ') + n + ('' if c else '  ' + str(x)))
        bad += not c

    (title,) = run('20000000', 21000000)
    save(title, 'pasopia7-title.png')
    px = pixels(title)
    white = sum(1 for p in px if p == (255, 255, 255))
    check('the title screen: text in white (%d pixels), nothing but black and white' % white, 300 < white < 3000 and set(px) <= {(0, 0, 0), (255, 255, 255)}, set(px))
    rows = [y for y in range(200) if any(px[y * 320 + x] != (0, 0, 0) for x in range(320))]
    check('the title screen: the banner row, the level prompt and three choices (rows used: %s)' % (rows[:3] + ['...'] + rows[-2:]), rows and rows[0] < 8 and 40 < rows[-1] < 100, rows[:5])
    if '--full' in sys.argv:
        (game,) = run('250000000', 251000000, '25000000:1:1,26500000:1:0')
        save(game, 'pasopia7-game.png')
        px = pixels(game)
        colours = set(px)
        check('the game: all the screen\'s colours show (%d of them)' % len(colours), len(colours) >= 6, colours)
        top = set(px[y * 320 + x] for y in range(0, 28) for x in range(320))
        check('the game: the status panel and the tool icons are coloured (%d colours in the top rows)' % len(top), len(top) >= 5, top)
        grass = sum(1 for p in px[40 * 320:] if p == (0, 255, 0))
        check('the game: a map of grass (%d green pixels below the panel)' % grass, grass > 15000, grass)
    print('FAILED' if bad else 'all ok')
    return 1 if bad else 0


if __name__ == '__main__':
    sys.exit(main())
