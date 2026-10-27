#!/usr/bin/env python3
"""The ZX Spectrum Next build under JNext (headless): the level screen, a city, the cursor and a road, the popup menu, a mini map, the
budget and evaluation screens, scrolling by the DMA, the animated pictures, a city saved and loaded back, and the sound.  Needs JNext, Pillow and make, Pillow, and JNext:

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
    made = subprocess.run(['make', '-s', 'ZXN=build/zxntest/simcity.nex', 'ZXN_MAP=120x100', 'ZXN_ENTROPY=target/zxn/entropy_test.asm', 'ZXN_FLAGS=-Ca-DZXN_TEST_ENTROPY=4660',
                           'build/zxntest/simcity.nex'], cwd=ROOT, capture_output=True, text=True)
    if made.returncode != 0 or not os.path.exists(NEX):
        print('FAIL  the test build: ' + made.stdout[-400:] + made.stderr[-400:])
        return 1

    # Rio's extracted scenario text includes all 774 bytes of its event block;
    # the NEX record must retain it rather than silently clipping the ending.
    scenario_dir = os.path.join(ROOT, 'build', 'zxn', 'scenarios')
    banks = sorted(f for f in os.listdir(scenario_dir) if f.startswith('scenarios_') and f.endswith('.bin'))
    records = b''.join(open(os.path.join(scenario_dir, f), 'rb').read() for f in banks)
    # a record, as tools/convert_amiga_scenarios.py and ui/scenarios.c have it: the map, its preview, the power map, the traffic map, 1,024 bytes of text
    meta_at = 12000 + 12000 + 15 * 100 + 60 * 50
    record_size = meta_at + 1024
    rio_meta = 5 * record_size + meta_at
    rio_text_len = records[rio_meta + 4] | (records[rio_meta + 5] << 8)
    check('the NEX scenario record keeps Rio’s complete extracted text', rio_text_len == 774, str(rio_text_len))
    source_hamburg = open(os.path.join(ROOT, 'assets', 'amiga_scenarios', 'Hamburg.map'), 'rb').read()
    hamburg_map = records[4 * record_size:4 * record_size + 12000]
    source_water_cells = []
    source_tiles = [[int.from_bytes(source_hamburg[(x * 100 + y) * 2:(x * 100 + y) * 2 + 2], 'big') & 0x3ff
                     for x in range(120)] for y in range(100)]
    frame_conversion_ok = True
    for x in range(120):
        for y in range(100):
            src_at = (x * 100 + y) * 2
            tile = int.from_bytes(source_hamburg[src_at:src_at + 2], 'big') & 0x3ff
            map_at = y * 120 + x
            if tile in (2, 3, 4):
                source_water_cells.append(map_at)
            if tile >= 828 and hamburg_map[map_at] == 2:
                frame_conversion_ok = False
            if tile == 948:
                if not (x + 1 < 120 and y + 5 < 100 and
                        source_tiles[y][x + 1] == 949 and
                        source_tiles[y + 4][x] == 950 and
                        source_tiles[y + 4][x + 1] == 951 and
                        source_tiles[y + 5][x] == 65 and
                        all(hamburg_map[(yy * 120) + x] == 19 for yy in range(y, y + 5)) and
                        hamburg_map[y * 120 + x + 1] == 0 and
                        hamburg_map[(y + 4) * 120 + x + 1] == 0):
                    frame_conversion_ok = False
    # Hamburg's drawbridges (a head 948 and a foot 950 in a column, a few cells apart) are drawn raised or lowered by the Amiga: the span's cells are water in one
    # and bridge in the other.  There is no raising here, so the whole span is bridge (19), water between the head and the foot included; any other water is water (0)
    bridge_water = set()
    for x in range(120):
        for y in range(100):
            if source_tiles[y][x] == 948:
                foot = next((yy for yy in range(y + 1, min(y + 7, 100)) if source_tiles[yy][x] == 950), None)
                if foot is not None:
                    bridge_water.update((yy * 120) + x for yy in range(y + 1, foot) if source_tiles[yy][x] in (2, 3, 4))
    converted_animation_water = all(hamburg_map[i] == (19 if i in bridge_water else 0) for i in source_water_cells)
    check('Hamburg water, animation frames and bridge cells convert to valid map codes',
          converted_animation_water and frame_conversion_ok and hamburg_map.count(93) == 0,
          f'{len(source_water_cells)} water cells checked ({len(bridge_water)} in drawbridge spans); frame conversion {frame_conversion_ok}')
    san_francisco_map = records[6 * record_size:6 * record_size + 12000]
    san_francisco_coal_plants = 0
    for y in range(100):
        for x in range(120):
            at = y * 120 + x
            marker = san_francisco_map[at]
            if marker == 0xB4:
                piece = ((san_francisco_map[at + 1] & 63) << 3) | (san_francisco_map[at + 2] & 7)
                if 52 <= piece < 68:
                    san_francisco_coal_plants += 1
    dullsville_map = records[3 * record_size:3 * record_size + 12000]
    dullsville_source = open(os.path.join(ROOT, 'assets', 'amiga_scenarios', 'Dullsville.map'), 'rb').read()
    dullsville_source_rubble = sum(
        (int.from_bytes(dullsville_source[(x * 100 + y) * 2:(x * 100 + y) * 2 + 2], 'big') & 0x3ff) == 44
        for x in range(120) for y in range(100)
    )
    check('special building footprints retain San Francisco’s seven coal plants',
          san_francisco_coal_plants == 7,
          f'{san_francisco_coal_plants} San Francisco coal plants; {dullsville_map.count(58)} Dullsville rubble cells')
    check('Dullsville keeps its R zone and clears the overlapping road',
          dullsville_map[44 * 120 + 66] == 81 and dullsville_map[45 * 120 + 67] == 63 and
          dullsville_map.count(58) == dullsville_source_rubble,
          f'center {dullsville_map[44 * 120 + 66]}, road {dullsville_map[45 * 120 + 67]}, rubble {dullsville_map.count(58)}')
    tokyo_source = open(os.path.join(ROOT, 'assets', 'amiga_scenarios', 'Tokyo.map'), 'rb').read()
    tokyo_map = records[7 * record_size:7 * record_size + 12000]
    ring_codes = (73, 74, 75, 80, None, 76, 79, 78, 77)
    empty_zones_ok = True
    frame_aliases = {852: 621, 853: 621, 854: 621, 855: 621, 856: 621, 857: 621, 858: 621, 859: 621,
                     884: 641, 885: 641, 886: 641, 887: 641, 888: 644, 889: 644, 890: 644, 891: 644,
                     900: 676, 901: 676, 902: 676, 903: 676, 904: 677, 905: 677, 906: 677, 907: 677}
    for x in range(120):
        for y in range(100):
            src_at = (x * 100 + y) * 2
            word = int.from_bytes(tokyo_source[src_at:src_at + 2], 'big')
            tile = frame_aliases.get(word & 0x3ff, word & 0x3ff)
            for first, centre in ((423, (82, 85)), (612, (83, 86))):
                if first <= tile <= first + 8:
                    offset = tile - first
                    expected = centre[0 if word & 0x8000 else 1] if offset == 4 else ring_codes[offset]
                    if tokyo_map[y * 120 + x] != expected:
                        empty_zones_ok = False
    check('Tokyo empty commercial and industrial zones and animated tiles convert without false rubble',
          empty_zones_ok and tokyo_map.count(58) == 3,
          f'empty zone conversion {empty_zones_ok}; rubble {tokyo_map.count(58)} cells')
    scenario_names = ('Bern', 'Boston', 'Detroit', 'Dullsville', 'Hamburg', 'Rio_De_Janerio', 'San_Francisco', 'Tokyo')
    rubble_matches_source = True
    rubble_counts = []
    for i, name in enumerate(scenario_names):
        source = open(os.path.join(ROOT, 'assets', 'amiga_scenarios', name + '.map'), 'rb').read()
        expected = sum(
            (int.from_bytes(source[(x * 100 + y) * 2:(x * 100 + y) * 2 + 2], 'big') & 0x3ff) == 44
            for x in range(120) for y in range(100)
        )
        actual = records[i * record_size:i * record_size + 12000].count(58)
        rubble_counts.append(actual)
        rubble_matches_source &= actual == expected
    check('scenario rubble matches only the tiles explicitly saved as rubble', rubble_matches_source,
          ', '.join(f'{name}: {n}' for name, n in zip(scenario_names, rubble_counts)))
    shapes = (0, 1, 3, 4, 2, 5, 8, 6, 9, 7, 10)
    route_codes = {64: 18, 65: 19, 224: 31, 225: 32, 237: 46, 238: 47,
                   80: 18, 81: 19, 82: 7, 83: 8, 84: 11, 85: 9, 86: 10,
                   87: 12, 88: 14, 89: 16, 90: 13, 91: 15, 92: 17,
                   93: 49, 94: 48}
    for k, shape in enumerate(shapes):
        route_codes[66 + shape] = 7 + k
        route_codes[210 + shape] = 33 + k
        route_codes[226 + shape] = 20 + k
    route_errors = 0
    for x in range(120):
        for y in range(100):
            src_at = (x * 100 + y) * 2
            tile = int.from_bytes(tokyo_source[src_at:src_at + 2], 'big') & 0x3ff
            if tile in route_codes and tokyo_map[y * 120 + x] != route_codes[tile]:
                route_errors += 1
    check('Tokyo road, rail and power-line tile shapes retain their route types', route_errors == 0,
          f'{route_errors} converted route cells differ from their source mapping')
    sd = os.path.join(TMP, 'sd.img')
    if subprocess.run(['cp', '-c', SD, sd], stderr=subprocess.DEVNULL).returncode != 0:
        shutil.copyfile(SD, sd)

    # the level screen
    im = run([], 300)
    check('the level screen shows its choices on black', lit(im, (0, 0, 256, 64)) > 400 and distinct(im, (0, 80, 256, 192)) > 1,
          f'{lit(im, (0, 0, 256, 64))}')

    # The scenario choice displays the Amiga map preview beside its title and text; Enter launches the selected map.
    picker = run([(69, '4')], 110)
    check('the scenario picker shows text and the map preview', lit(picker, (0, 0, 128, 192)) > 400 and
          distinct(picker, (136, 64, 256, 164)) > 8,
          f'{lit(picker, (0, 0, 128, 192))} {distinct(picker, (136, 64, 256, 164))}')
    loaded_scenario = run([(69, '4'), (110, 'right'), (150, 'enter')], 900)
    check('a selected scenario launches into its city map', distinct(loaded_scenario, (0, 56, 256, 192)) >= 4,
          str(distinct(loaded_scenario, (0, 56, 256, 192))))
    sf_keys = [(69, '4')] + [(90 + 20 * i, 'right') for i in range(6)] + [(230, 'enter'), (700, 'm')]
    sf_minimap = run(sf_keys, 1000)
    check('San Francisco loads as a converted city across the minimap', distinct(sf_minimap, (0, 0, 192, 192)) > 4 and
          lit(sf_minimap, (0, 0, 192, 192)) > 10000,
          f'{distinct(sf_minimap, (0, 0, 192, 192))} colours, {lit(sf_minimap, (0, 0, 192, 192))} lit pixels')

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

    # animation: an airport (tool 13: twelve presses of '.' from the road) has a radar, and the park's fountain and the chimneys' smoke are others: the game
    # shows each animated picture's frames in turn, one every 16 game ticks.  Space the emulator screenshots 32 frames apart: the game's main-loop
    # counter can drift against JNext's frame scheduler, and 16-frame sampling can alias the animation.  Some cell should show four or more pictures
    # (the plane that flies over the airport and the cursor change a cell to one or two).
    airport = [S] + LAND + [(820 + 40 * i, '.') for i in range(12)] + [(1320, 'space'), (1400, 'caps+o')]
    frames = [run(airport, 1800 + 32 * k) for k in range(8)]
    most = max(len({f.crop((x * 8, y * 8, x * 8 + 8, y * 8 + 8)).tobytes() for f in frames}) for y in range(8, 24) for x in range(32))
    check('the airport\'s radar animates: a map cell shows its frames in turn', most >= 4, f'at most {most} different pictures in a cell')

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

    # the engine's bank (PORTING.md, a larger map): the simulation's code is in BANK_6, mapped over $4000-$7FFF while it runs, so everything above passed with
    # it: the city made, the ticks, the tools.  What the tests cannot see is a call or load from the bank to an address of the program's own in that range
    # (the bank is mapped there instead): the disassembly of the bank is checked for them
    r = subprocess.run([sys.executable, os.path.join(ROOT, 'tools', 'check_bank_refs.py'), os.path.join(ROOT, 'build', 'zxntest', 'simcity')], cwd=ROOT, capture_output=True, text=True)
    check('the engine bank refers to nothing of the program\'s in $4000-$7FFF', r.returncode == 0, r.stdout[-400:])

    shutil.rmtree(TMP, ignore_errors=True)
    print('%d of %d passed' % (sum(results), len(results)))
    return 0 if all(results) else 1


if __name__ == '__main__':
    sys.exit(main())
