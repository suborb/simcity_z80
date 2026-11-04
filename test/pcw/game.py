#!/usr/bin/env python3
"""The PCW game itself, build/pcw/simcity.com, run headless under z88dk-ticks on the Lua PCW model (test/pcw/pcw_test.lua): a stub of the BDOS gives it the keys of a script
and the time of day, and the screen is read back through the roller RAM.  Checks the frame delay measures a 50 Hz frame, the city and the mini map are on the screen, a
scrolled view is what a full redraw of the same view gives, and a pass of the main loop is within its budget.

  test/pcw/game.py [--png DIR]       (the screens as PNG files in DIR)
"""
import os
import statistics
import subprocess
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, '..', '..'))
sys.path.insert(0, HERE)
import screen  # noqa: E402  (test/pcw/screen.py: the screen read back through the roller RAM)

TITLE_CYCLES = (72000, 88000)       # a frame of the title screen's wait, measured by plat_idle against the clock: 4 MHz / 50 Hz
PASS_BUDGET = 300000                # the median pass of an idle city (about 75 ms at 4 MHz)

# the keys: p moves the cursor right, to the edge of the view, where the map scrolls
KEYS = ''.join('3 p\n' for _ in range(30))


def run(tmp):
    script = '30 1\n300 snap city\n' + KEYS + '60 snap scrolled\n2 m\n80 snap mini\n2 x\n80 snap back\n2 m\n2 m\n80 snap mini2\n'
    open(os.path.join(tmp, 'script.txt'), 'w').write(script)
    open(os.path.join(tmp, 'pcw_test.lua'), 'w').write(open(os.path.join(HERE, 'pcw_test.lua')).read())
    open(os.path.join(tmp, 'bdos.asm'), 'w').write(open(os.path.join(HERE, 'bdos.asm')).read())
    subprocess.run(['z88dk-z80asm', '-b', 'bdos.asm'], cwd=tmp, capture_output=True)
    com = os.path.join(ROOT, 'build', 'pcw', 'simcity.com')
    return subprocess.run(['z88dk-ticks', '-b', 'lua', '-lua', 'pcw_test.lua', '-pc', '100', '-end', 'F5F0', '-counter', '4000000000', com],
                          cwd=tmp, capture_output=True, text=True)


def lit(lines, x0, x1, y0, y1):
    n = 0
    for y in range(y0, y1):
        for x in range(x0, x1):
            if lines[y][x >> 3] & (0x80 >> (x & 7)):
                n += 1
    return n / float((x1 - x0) * (y1 - y0))


def main():
    png = sys.argv[sys.argv.index('--png') + 1] if '--png' in sys.argv else None
    ok = True
    with tempfile.TemporaryDirectory() as tmp:
        r = run(tmp)
        if 'Unsupported' in r.stdout + r.stderr or not os.path.exists(os.path.join(tmp, 'screen_back.bin')):
            print('FAIL  running the game under ticks:', (r.stdout + r.stderr)[-400:])
            return 1
        shots = {n: screen.lines(open(os.path.join(tmp, f'screen_{n}.bin'), 'rb').read()) for n in ('city', 'scrolled', 'mini', 'back', 'mini2')}
        if png:
            os.makedirs(png, exist_ok=True)
            for n in shots:
                screen.image(open(os.path.join(tmp, f'screen_{n}.bin'), 'rb').read()).save(os.path.join(png, n + '.png'))
        polls = [int(x) for x in open(os.path.join(tmp, 'polls.txt'))]
    d = [b - a for a, b in zip(polls, polls[1:])]
    title = statistics.median(d[1:25])
    good = TITLE_CYCLES[0] <= title <= TITLE_CYCLES[1]
    print(('PASS' if good else 'FAIL') + f'  the frame delay measures a 50 Hz frame against the clock: {int(title):,} cycles a title frame')
    ok &= good
    # the city: the panel's rows (0..47 lines) have text and icons, the map below is lit and not solid
    c = shots['city']
    panel, mapped = lit(c, 40, 680, 0, 48), lit(c, 40, 680, 56, 256)
    good = 0.05 < panel < 0.5 and 0.1 < mapped < 0.99
    print(('PASS' if good else 'FAIL') + f'  the city: the panel is {panel:.0%} lit, the map {mapped:.0%}')
    ok &= good
    # a scrolled city is not the first view, and a full redraw of the same view (after the mini map and back) is the same picture
    changed = sum(1 for y in range(56, 256) for b in range(90) if shots['scrolled'][y][b] != c[y][b])
    differ = sum(1 for y in range(56, 256) for b in range(90) if shots['back'][y][b] != shots['scrolled'][y][b])
    total = 200 * 90
    good = changed > total * 0.05 and differ < total * 0.01
    print(('PASS' if good else 'FAIL') + f'  scrolling: the view moved ({changed / total:.0%} of the map bytes changed), and a full redraw of it after a mini map differs in {differ / total:.2%} (the cursor)')
    ok &= good
    # the mini map: a picture of 384x192 at the left (not empty, not solid), the sidebar's text to the right of it
    m = shots['mini']
    pic, side = lit(m, 40, 424, 0, 192), lit(m, 424, 680, 0, 256)
    good = 0.1 < pic < 0.95 and 0.01 < side < 0.4
    print(('PASS' if good else 'FAIL') + f'  the mini map: the picture is {pic:.0%} lit, the sidebar {side:.0%}')
    ok &= good
    m2 = shots['mini2']
    good = sum(1 for y in range(0, 192) for b in range(5, 53) if m2[y][b] != m[y][b]) > 0
    print(('PASS' if good else 'FAIL') + '  the next mini map is another picture')
    ok &= good
    cyc = statistics.median(d[60:300]) if len(d) > 300 else statistics.median(d)
    good = cyc < PASS_BUDGET
    print(('PASS' if good else 'FAIL') + f'  a pass of the main loop: median {int(cyc):,} cycles (budget {PASS_BUDGET:,})')
    ok &= good
    return 0 if ok else 1


if __name__ == '__main__':
    sys.exit(main())
