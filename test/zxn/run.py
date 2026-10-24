#!/usr/bin/env python3
"""The ZX Spectrum Next build under JNext (headless): the level screen, a city, the cursor and a road, the popup menu, a mini map, the
budget and evaluation screens, scrolling by the DMA, a city saved and loaded back, and the sound.  Needs JNext, Pillow and make, Pillow, and JNext:

    JNEXT=/Applications/jnext.app/Contents/MacOS/jnext python3 test/zxn/run.py

The game's screen is 256x192 pixels of Layer 2, which JNext's screenshot shows at 2x from (64, 64).  Keys are given as (frame, key) pairs
for JNext's --delayed-keypress-frames; the SD card is a copy of JNext's own (a city saved goes to the copy, never to the original)."""
import os
import shutil
import subprocess
import sys
import tempfile
import wave
import struct

from PIL import Image, ImageChops

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
# The test build has a fixed entropy, so that the same keys make the same city (the shipping build's seed is the refresh register while the level is
# chosen), and the game paces itself by the 50 Hz interrupt, so the number of frames before the level key is pressed is what makes a city: START is the
# frame that makes one with the sea in the north half and land to the south, and the cursor starts at the coast: LAND moves it three cells down, to land.
NEX = os.path.join(ROOT, 'build', 'zxntest', 'simcity.nex')
START = 69
LAND = [(700, 'down'), (740, 'down'), (780, 'down')]
JNEXT = os.environ.get('JNEXT')
SD = os.path.expanduser('~/.jnext/sdcard/cspect-next-1gb-fixed.img')
TMP = tempfile.mkdtemp(prefix='next_test_')
results = []


def check(name, ok, detail=''):
    results.append(ok)
    print(('PASS  ' if ok else 'FAIL  ') + name + ('' if ok else '  ' + detail))


def run(keys, frame, sd=None, wav=None):
    """Run the game, press keys, and return the screenshot (a 256x192 image) at the frame."""
    shot = os.path.join(TMP, 'shot.png')
    if os.path.exists(shot):
        os.remove(shot)
    cmd = [JNEXT, '--headless', '--load', NEX, '--delayed-screenshot', shot, '--delayed-screenshot-frames', str(frame),
           '--delayed-automatic-exit-frames', str(frame + 10)]
    if sd:
        cmd += ['--sd-card', sd]
    if wav:
        cmd += ['--wav-record', wav]
    for f, k in keys:
        cmd += ['--delayed-keypress-frames', str(f), k]
    subprocess.run(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, check=False, timeout=300)
    im = Image.open(shot).convert('RGB')
    return im.crop((64, 64, 576, 448)).resize((256, 192), Image.NEAREST)


def colours(im, box):
    return im.crop(box).getcolors(100000)


def count(im, box, rgb):
    return sum(n for n, c in colours(im, box) if c == rgb)


def distinct(im, box):
    return len(colours(im, box))


def lit(im, box):
    """pixels in the box that are not black"""
    return sum(n for n, c in colours(im, box) if c != (0, 0, 0))


def differs(a, b, box):
    return a.crop(box).tobytes() != b.crop(box).tobytes()


def main():
    if not JNEXT or not os.path.exists(JNEXT):
        print('skipped: set JNEXT to the jnext executable')
        return 0
    made = subprocess.run(['make', '-s', 'ZXN=build/zxntest/simcity.nex', 'ZXN_ENTROPY=target/zxn/entropy_test.asm', 'ZXN_FLAGS=-Ca-DZXN_TEST_ENTROPY=4660',
                           'build/zxntest/simcity.nex'], cwd=ROOT, capture_output=True, text=True)
    if made.returncode != 0 or not os.path.exists(NEX):
        print('FAIL  the test build: ' + made.stdout[-400:] + made.stderr[-400:])
        return 1
    sd = os.path.join(TMP, 'sd.img')
    if subprocess.run(['cp', '-c', SD, sd], stderr=subprocess.DEVNULL).returncode != 0:
        shutil.copyfile(SD, sd)

    # the level screen
    im = run([], 300)
    check('the level screen is text on black', lit(im, (0, 0, 256, 64)) > 400 and distinct(im, (0, 80, 256, 192)) == 1, f'{lit(im, (0, 0, 256, 64))}')

    # a city: the panel above, ground and trees in the map, the demand bars, the tool icons in two rows
    S = (START, '1')
    city = run([S], 700)
    check('the panel, the icons and the map', lit(city, (0, 0, 256, 48)) > 1500 and distinct(city, (0, 56, 256, 192)) >= 4,
          f'{lit(city, (0, 0, 256, 48))} {distinct(city, (0, 56, 256, 192))}')
    # the Amiga's buttons: two rows of seven 22x20 pictures in colour on grey bevels, and a yellow frame round the tool in use (the road)
    icons = colours(city, (0, 8, 161, 48))
    check('the tool icons are drawn: many colours and the yellow frame of the tool in use', len(icons) >= 12 and sum(n for n, c in icons if c[0] > 150 and c[2] < 150) > 60,
          str(sorted(icons, reverse=True)[:6]))

    # the cursor moves a cell with caps shift and 5 to 8 (JNext's arrows), then roads
    built = run([S] + LAND + [(820, 'right'), (860, 'right'), (900, 'space'), (940, 'right'), (980, 'space')], 1200)
    check('the cursor moves and a road is built', differs(city, built, (0, 56, 256, 192)))
    check('the funds are spent', differs(city, built, (72, 0, 120, 8)))

    # scrolling: the view moved by the DMA (plat_scroll moves the map's pixels, and the game draws the cells that come into view) is the picture a
    # full redraw makes (opening a mini map and going back): the cursor's blinking cell is the only difference
    moves = [S] + [(700 + 40 * i, k) for i, k in enumerate(['caps+p'] * 4 + ['caps+a'] * 3 + ['caps+o'] * 2 + ['caps+q'] * 2 + ['p', 'a', 'o', 'q'])]
    end = moves[-1][0]
    scrolled = run(moves, end + 300)
    redrawn = run(moves + [(end + 60, 'm'), (end + 140, 'x')], end + 400)
    diff = ImageChops.difference(scrolled, redrawn).convert('L').point(lambda v: 255 if v else 0)
    n = sum(1 for v in diff.tobytes() if v)
    check('the map scrolled by the DMA is the picture a full redraw makes', n <= 64 and differs(city, scrolled, (0, 56, 256, 192)), f'{n} pixels differ, in {diff.getbbox()}')

    # the popup menu: ESC (caps shift and 1: EDIT)
    menu = run([S, (700, 'caps+1')], 900)
    check('the popup menu has its frame over the map', differs(city, menu, (16, 80, 240, 168)) and lit(menu, (16, 90, 240, 100)) > 100)

    # the mini map: the whole city, 192 pixels wide, with a colour key
    mini = run([S, (700, 'm')], 900)
    check('the mini map fills 192x192 and has its key', distinct(mini, (0, 0, 192, 192)) >= 2 and lit(mini, (192, 0, 256, 192)) > 300)

    # the budget and the evaluation
    budget = run([S, (700, 'b')], 900)
    check('the budget screen', lit(budget, (0, 0, 256, 192)) > 1500 and distinct(budget, (0, 0, 256, 192)) >= 5)
    ev = run([S, (700, 'v')], 900)
    check('the evaluation screen', lit(ev, (0, 0, 256, 192)) > 1000)

    # a city saved and loaded back: build a road, save it as `ab`, build two more, load it: the funds are as they were when it was saved
    first = [S] + LAND + [(820, 'space'), (860, 's'), (920, 'a'), (980, 'b'), (1040, 'enter')]
    saved = run(first, 1140, sd=sd)
    check('the city is saved', lit(saved, (16, 70, 240, 110)) > 200)
    back = run(first + [(1120, 'space'), (1180, 'right'), (1220, 'space'), (1260, 'right'), (1300, 'space'),
                        (1360, 'l'), (1420, 'a'), (1480, 'b'), (1560, 'enter')], 1900, sd=sd)
    # (the funds' first digits, "$1999": 19990 or a little less; with two more roads and no load they would be "$1997")
    check('the city is loaded back: the funds are as they were saved', not differs(saved, back, (72, 0, 112, 8)))

    # the sound: a road built plays the effect
    wavf = os.path.join(TMP, 's.wav')
    run([S] + LAND + [(820, 'space'), (880, 'right'), (920, 'space')], 1100, wav=wavf)
    peak = 0
    if os.path.exists(wavf):
        w = wave.open(wavf)
        d = w.readframes(w.getnframes())
        peak = max(abs(x) for x in struct.unpack('<%dh' % (len(d) // 2), d))
    check('the sound of a building is heard', peak > 200, str(peak))

    shutil.rmtree(TMP, ignore_errors=True)
    print('%d of %d passed' % (sum(results), len(results)))
    return 0 if all(results) else 1


if __name__ == '__main__':
    sys.exit(main())
