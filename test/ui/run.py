#!/usr/bin/env python3
"""Headless UI test: the real game core (ui/) and portable engine, built for z88dk's
+test target and run under z88dk-ticks with a scripted keyboard.

The same ui/ sources are what the Aquarius+, NC200 and Z88 builds use; only the
platform file differs (target/test_ui here, platform/console there).

  usage: test/ui/run.py

Scenarios work on whatever random landscape the game generates: they first run a
do-nothing game to read the map, find dirt to build on, then run again with keys
that move the cursor there and build.
"""
import os
import re
import subprocess
import sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
TICKS = 'z88dk-ticks'
OUT = os.path.join(ROOT, 'build', 'test')
ROWS, COLS = 24, 64
MAP_W = 96
SCRIPT_LEN = 2048
END = 0xFF


def build():
    subprocess.run(['make', '-s', '-C', ROOT, 'build/test/simcity.bin'], check=True, capture_output=True)
    syms = {}
    for line in open(os.path.join(OUT, 'simcity.map')):
        m = re.match(r'(\S+)\s*=\s*\$([0-9A-Fa-f]+)', line)
        if m:
            syms[m.group(1)] = int(m.group(2), 16)
    return open(os.path.join(OUT, 'simcity.bin'), 'rb').read(), syms


def build_modal():
    out = os.path.join(ROOT, 'build', 'testmodal')
    subprocess.run(['make', '-s', '-C', ROOT, 'build/testmodal/simcity.bin'], check=True, capture_output=True)
    syms = {}
    for line in open(os.path.join(out, 'simcity.map')):
        m = re.match(r'(\S+)\s*=\s*\$([0-9A-Fa-f]+)', line)
        if m:
            syms[m.group(1)] = int(m.group(2), 16)
    return open(os.path.join(out, 'simcity.bin'), 'rb').read(), syms


def build_narrow():
    out = os.path.join(ROOT, 'build', 'testnarrow')
    subprocess.run(['make', '-s', '-C', ROOT, 'build/testnarrow/simcity.bin'], check=True, capture_output=True)
    syms = {}
    for line in open(os.path.join(out, 'simcity.map')):
        m = re.match(r'(\S+)\s*=\s*\$([0-9A-Fa-f]+)', line)
        if m:
            syms[m.group(1)] = int(m.group(2), 16)
    return open(os.path.join(out, 'simcity.bin'), 'rb').read(), syms


def build_hires_minimap():
    out = os.path.join(ROOT, 'build', 'testhires')
    subprocess.run(['make', '-s', '-C', ROOT, 'build/testhires/simcity.bin'], check=True, capture_output=True)
    syms = {}
    for line in open(os.path.join(out, 'simcity.map')):
        m = re.match(r'(\S+)\s*=\s*\$([0-9A-Fa-f]+)', line)
        if m:
            syms[m.group(1)] = int(m.group(2), 16)
    return open(os.path.join(out, 'simcity.bin'), 'rb').read(), syms


def build_scroll():
    out = os.path.join(ROOT, 'build', 'testscroll')
    subprocess.run(['make', '-s', '-C', ROOT, 'build/testscroll/simcity.bin'], check=True, capture_output=True)
    syms = {}
    for line in open(os.path.join(out, 'simcity.map')):
        m = re.match(r'(\S+)\s*=\s*\$([0-9A-Fa-f]+)', line)
        if m:
            syms[m.group(1)] = int(m.group(2), 16)
    return open(os.path.join(out, 'simcity.bin'), 'rb').read(), syms


def build_native_minimap():
    out = os.path.join(ROOT, 'build', 'testnative')
    subprocess.run(['make', '-s', '-C', ROOT, 'build/testnative/simcity.bin'], check=True, capture_output=True)
    syms = {}
    for line in open(os.path.join(out, 'simcity.map')):
        m = re.match(r'(\S+)\s*=\s*\$([0-9A-Fa-f]+)', line)
        if m:
            syms[m.group(1)] = int(m.group(2), 16)
    return open(os.path.join(out, 'simcity.bin'), 'rb').read(), syms


def build_native_art():
    out = os.path.join(ROOT, 'build', 'testart')
    subprocess.run(['make', '-s', '-C', ROOT, 'build/testart/simcity.bin'], check=True, capture_output=True)
    syms = {}
    for line in open(os.path.join(out, 'simcity.map')):
        m = re.match(r'(\S+)\s*=\s*\$([0-9A-Fa-f]+)', line)
        if m:
            syms[m.group(1)] = int(m.group(2), 16)
    return open(os.path.join(out, 'simcity.bin'), 'rb').read(), syms


def run(binary, syms, keys, limit=4_000_000_000, patch=None, city=b''):
    """Run the game with the given key script; return (memory dump, symbols).  A build that asks for the city's name
    after the level (it has test_app_name) gets the name in `city` at the first title screen, and just ENTER after the others."""
    if '_test_app_name' in syms:
        typed, title, named = [], True, city
        for k in keys:
            typed.append(k)
            if title and k in (ord('1'), ord('2'), ord('3')):
                typed += list(named) + [13]
                named = b''                                             # a later title screen just takes the default
                title = False
            if k == 0x90:                                               # CMD_NEW_CITY: the title screen again
                title = True
        keys = typed
    assert len(keys) < SCRIPT_LEN
    image = bytearray(binary)
    script = bytes(keys) + bytes([END]) + bytes(SCRIPT_LEN - len(keys) - 1)
    a = syms['_test_script']
    image[a:a + SCRIPT_LEN] = script
    for name, data in (patch or {}).items():
        image[syms[name]:syms[name] + len(data)] = data
    path = os.path.join(OUT, 'run.bin')
    open(path, 'wb').write(image)
    dump = os.path.join(OUT, 'run.out')
    if os.path.exists(dump):
        os.remove(dump)
    subprocess.run([TICKS, path, '-end', f'{syms["__Exit"]:x}', '-counter', str(limit), '-output', dump],
                   capture_output=True)
    return open(dump, 'rb').read()


def screen(mem, syms, cols=COLS):
    a = syms['_test_screen']
    return [mem[a + r * cols:a + (r + 1) * cols].decode('latin1') for r in range(ROWS)]


def levelmap(mem, syms):
    a = syms['_levelmap']
    return mem[a:a + MAP_W * MAP_W]


def money(mem, syms):
    a = syms['_V_money']
    return mem[a] | mem[a + 1] << 8 | mem[a + 2] << 16


KEY_LEFT, KEY_RIGHT, KEY_DOWN, KEY_UP = 8, 9, 10, 11
KEY_FAR_LEFT, KEY_FAR_RIGHT, KEY_FAR_DOWN, KEY_FAR_UP = 28, 29, 30, 31
KEY_ESC = 27


def moves(dx, dy, cursor=False):
    """Key presses that move the cursor by (dx, dy): 8-cell jumps then single steps.  The letters (O P Q A) on
    the plain test platform, the cursor keys (shifted for the jumps) on one with menus, as the Z88."""
    k = []
    if cursor:
        k += [KEY_FAR_RIGHT if dx > 0 else KEY_FAR_LEFT] * (abs(dx) // 8) + [KEY_RIGHT if dx > 0 else KEY_LEFT] * (abs(dx) % 8)
        k += [KEY_FAR_DOWN if dy > 0 else KEY_FAR_UP] * (abs(dy) // 8) + [KEY_DOWN if dy > 0 else KEY_UP] * (abs(dy) % 8)
        return k
    k += [ord('P' if dx > 0 else 'O')] * (abs(dx) // 8) + [ord('p' if dx > 0 else 'o')] * (abs(dx) % 8)
    k += [ord('A' if dy > 0 else 'Q')] * (abs(dy) // 8) + [ord('a' if dy > 0 else 'q')] * (abs(dy) % 8)
    return k


def find_dirt_block(lm, size):
    """A size x size block of dirt (tile 2) close to the centre of the map."""
    best = None
    for y in range(40, 60):
        for x in range(40, 60):
            if all(lm[(y + j) * MAP_W + x + i] == 2 for j in range(size) for i in range(size)):
                d = abs(x - 48) + abs(y - 48)
                if best is None or d < best[0]:
                    best = (d, x, y)
    return best and best[1:]


failures = []


def check(name, ok, detail=''):
    print(('PASS  ' if ok else 'FAIL  ') + name + (('  ' + detail) if detail and not ok else ''))
    if not ok:
        failures.append(name)


def main():
    binary, syms = build()
    LEVEL_MEDIUM = ord('2')     # 10000 starting funds
    PAUSE = ord('h')

    # --- 1. the title screen and a do-nothing game ------------------------------
    mem = run(binary, syms, [LEVEL_MEDIUM, PAUSE])
    scr = screen(mem, syms)
    lm = levelmap(mem, syms)
    check('game starts and quits cleanly', mem[syms['_test_done']] == 1)
    check('status panel shows the funds', any('FUNDS $10000' in row for row in scr), '\n'.join(scr))
    mem5 = run(binary, syms, [LEVEL_MEDIUM, PAUSE] + [0] * 8)
    check('the status panel of the plain build (the Spectrum code) shows the finished population, 5000, not the running total',
          any('POP 5000' in row for row in screen(mem5, syms)), '\n'.join(screen(mem5, syms)))
    check('status panel shows the tool', any('ROAD $10' in row for row in scr))
    check('map has water and land', 0 in lm and 2 in lm)

    # --- 2. build a road and a residential zone ----------------------------------
    blk = find_dirt_block(lm, 4)
    check('found a place to build', blk is not None)
    if blk:
        bx, by = blk
        keys = [LEVEL_MEDIUM, PAUSE]
        keys += moves(bx - 48, by - 48)
        keys += [ord(' ')]                          # road (the default tool) at (bx, by)
        keys += moves(1, 1)
        keys += [ord('5'), ord(' ')]                # residential at (bx+1, by+1)
        mem = run(binary, syms, keys)
        lm2 = levelmap(mem, syms)
        check('road built where the cursor was', lm2[by * MAP_W + bx] == 7,
              f'tile={lm2[by * MAP_W + bx]}')
        zone = [lm2[(by + 1 + j) * MAP_W + bx + 1 + i] for j in range(3) for i in range(3)]
        expect = [0x49, 0x4a, 0x4b, 0x50, 0x54, 0x4c, 0x4f, 0x4e, 0x4d]
        check('residential zone built', zone == expect, f'{zone}')
        check('funds spent: $10 road + $100 zone', money(mem, syms) == 10000 - 10 - 100,
              f'money={money(mem, syms)}')
        scr = screen(mem, syms)
        check('status panel shows the new funds', any('FUNDS $9890' in row for row in scr))
        check('status panel shows the residential tool', any('RESIDENTIAL' in row for row in scr))

        # bulldoze it again: the bulldozer (tool 0) over the zone
        keys2 = keys + moves(1, 1)[:0] + [ord('0'), ord(' ')]
        mem = run(binary, syms, keys2)
        lm3 = levelmap(mem, syms)
        cleared = [lm3[(by + 1 + j) * MAP_W + bx + 1 + i] for j in range(3) for i in range(3)]
        check('bulldozer clears the zone', cleared != expect, f'{cleared}')

    # --- 2b. the cursor is the size of what the tool places ---
    sizes = {}
    for tool, size in (('1', 1), ('5', 3), ('k', 0)):
        counts = set()
        for pad in range(0, 10):
            if tool == 'k':
                continue
            mem = run(binary, syms, [LEVEL_MEDIUM, PAUSE, ord(tool)] + [0] * (6 + pad))
            cells = [(r, c) for r, row in enumerate(screen(mem, syms)[8:]) for c, ch in enumerate(row) if ch == '@']
            counts.add(len(cells))
            if cells:
                rs, cs = {r for r, _ in cells}, {c for _, c in cells}
                if len(cells) != size * size or max(rs) - min(rs) != size - 1 or max(cs) - min(cs) != size - 1:
                    counts.add(-1)
        sizes[tool] = counts
    check('cursor: tool 1 (road) shows one cell', sizes['1'] == {0, 1}, str(sizes['1']))
    check('cursor: tool 5 (residential) shows a 3x3 square', sizes['5'] == {0, 9}, str(sizes['5']))

    # --- 3. let the simulation run -------------------------------------------------
    # fast speed for 250 frames: a tick takes 96 frames (one map row per frame) plus the
    # wait between ticks, and the month advances when the first tick completes
    keys = [LEVEL_MEDIUM, ord('+')] + [0] * 250
    mem = run(binary, syms, keys)
    scr = screen(mem, syms)
    year = mem[syms['_V_year']] | mem[syms['_V_year'] + 1] << 8
    check('simulation advances the date', year > 1902 or mem[syms['_V_month']] > 0,
          f'year={year} month={mem[syms["_V_month"]]}')

    # --- 4. menu commands (what the Z88's OZ menus send) behave like the keys ------------------
    CMD_NEW_CITY, CMD_PAUSE = 0x90, 0x91
    CMD_FAST, CMD_NORMAL, CMD_SLOW = 0x92, 0x93, 0x94
    CMD_COAL, CMD_NUCLEAR, CMD_DIS_ON, CMD_DIS_OFF, CMD_BULL_ON, CMD_BULL_OFF = 0x95, 0x96, 0x97, 0x98, 0x99, 0x9A
    CMD_QUIT, CMD_REDRAW = 0x9B, 0x9C
    CMD_MAP, CMD_MAP_OFF = 0x87, 0xA3
    byte = lambda mem, name: mem[syms[name]]

    mem = run(binary, syms, [LEVEL_MEDIUM, ord('5'), 0, 0])
    check('command: tool 5 chooses residential', any('RESIDENTIAL' in row for row in screen(mem, syms)))
    mem = run(binary, syms, [LEVEL_MEDIUM] + [ord('.')] * 12 + [0, 0])
    check('command: tool 13 chooses the airport', any('AIRPORT' in row for row in screen(mem, syms)))
    for cmd, word in ((CMD_FAST, 'FAST'), (CMD_SLOW, 'SLOW'), (CMD_PAUSE, 'PAUSED'), (CMD_NORMAL, 'NORMAL')):
        mem = run(binary, syms, [LEVEL_MEDIUM, CMD_PAUSE if cmd == CMD_NORMAL else cmd, cmd if cmd == CMD_NORMAL else 0, 0, 0])
        check(f'command: speed shows {word}', any(word in row for row in screen(mem, syms)))
    mem = run(binary, syms, [LEVEL_MEDIUM, CMD_DIS_OFF, CMD_BULL_OFF, CMD_NUCLEAR, 0])
    check('command: disasters off', byte(mem, '_V_disaster_reset') == 1)
    check('command: auto-bulldoze off', byte(mem, '_V_auto_bulldoze') == 0)
    mem = run(binary, syms, [LEVEL_MEDIUM, CMD_DIS_OFF, CMD_DIS_ON, CMD_BULL_OFF, CMD_BULL_ON, 0])
    check('command: disasters and auto-bulldoze back on', byte(mem, '_V_disaster_reset') == 0 and byte(mem, '_V_auto_bulldoze') == 1)
    mem = run(binary, syms, [LEVEL_MEDIUM, CMD_QUIT, ord('3')])
    check('command: quit leaves the game', byte(mem, '_test_done') == 1 and byte(mem, '_V_difficulty') == 1,
          f'difficulty {byte(mem, "_V_difficulty")}')
    mem = run(binary, syms, [LEVEL_MEDIUM, CMD_NEW_CITY, ord('3'), ord('2'), 0, 0])
    check('command: new city goes back to the title and starts a harder city',
          byte(mem, '_V_difficulty') == 2 and byte(mem, '_test_done') == 1, f'difficulty {byte(mem, "_V_difficulty")}')
    check('command: the new city is drawn (tool shown, map present)',
          any('POWER LINES' in row for row in screen(mem, syms)) and any('~' in row for row in screen(mem, syms)[8:]))
    mem = run(binary, syms, [LEVEL_MEDIUM, CMD_REDRAW, 0, 0])
    check('command: redraw draws the status panel again', any('FUNDS $10000' in row for row in screen(mem, syms)))

    # --- 4b. the portable box + message menu used by the console targets -----------------------
    mem = run(binary, syms, [LEVEL_MEDIUM, KEY_ESC])
    scr = screen(mem, syms)
    check('popup menu opens over the city', any('SIMCITY' in row for row in scr) and any('GAME OPTIONS' in row for row in scr), '\n'.join(scr))
    mem = run(binary, syms, [LEVEL_MEDIUM, KEY_ESC, 13, KEY_DOWN, 13, ord('x'), 0, 0])
    scr = screen(mem, syms)
    check('popup menu toggles in place and X restores the city', any('FAST' in row for row in scr) and not any('SIMCITY' in row for row in scr), '\n'.join(scr))

    # --- 5. a platform with a text window of its own (the Z88's shape): the map is the whole 32x8 console ---
    subprocess.run(['make', '-s', '-C', ROOT, 'build/testpanel/simcity.bin'], check=True, capture_output=True)
    psyms = {}
    for line in open(os.path.join(ROOT, 'build', 'testpanel', 'simcity.map')):
        m = re.match(r'(\S+)\s*=\s*\$([0-9A-Fa-f]+)', line)
        if m:
            psyms[m.group(1)] = int(m.group(2), 16)
    pbin = open(os.path.join(ROOT, 'build', 'testpanel', 'simcity.bin'), 'rb').read()

    def panes(mem):
        a, t = psyms['_test_screen'], psyms['_test_text']
        return ([mem[a + r * 32:a + (r + 1) * 32].decode('latin1') for r in range(8)],
                [mem[t + r * 51:t + (r + 1) * 51].decode('latin1') for r in range(8)])

    mem = run(pbin, psyms, [LEVEL_MEDIUM, PAUSE])
    mapp, text = panes(mem)
    check('text window: the game ran and quit cleanly', mem[psyms['_test_done']] == 1)
    shown = panes(run(pbin, psyms, [LEVEL_MEDIUM, PAUSE] + [0] * 8))[1]
    check('the status shows the population the engine has finished counting (V_display_population, 5000 here), not the running total',
          any('POP 5000' in r for r in shown), '\n'.join(shown))
    check('text window: the status is in the text window', any('FUNDS $10000' in r for r in text) and any('ROAD $10' in r for r in text),
          '\n'.join(text))
    check('text window: no key tips; rows 3, 4 (the icons), 5 and 7 are left empty',
          not any('MOVE' in r or 'PICK' in r or 'QUIT' in r for r in text) and not any(text[i].strip() for i in (3, 4, 5, 7)), '\n'.join(text))
    check('text window: the icons are drawn with the tool in use highlighted (the road, tool 1, to start with)',
          mem[psyms['_test_icons_selected']] == 1 and mem[psyms['_test_icons_calls']] > 0)
    check('text window: the map is only the map (no text on it)',
          not any(w in r for r in mapp for w in ('FUNDS', 'POP', 'ROAD', 'MOVE', 'JAN', 'MORE')), '\n'.join(mapp))
    check('text window: the map fills all 8 rows of the console', all(r.strip() for r in mapp), '\n'.join(mapp))
    mem = run(pbin, psyms, [LEVEL_MEDIUM, ord('5'), 0, 0])
    check('text window: choosing a tool moves the icon highlight to it', mem[psyms['_test_icons_selected']] == 5)
    mem = run(pbin, psyms, [LEVEL_MEDIUM, ord('9'), 0, 0])
    check('text window: so does a digit key', mem[psyms['_test_icons_selected']] == 9)
    mem = run(pbin, psyms, [LEVEL_MEDIUM, ord('5'), 0, 0])
    check('text window: a menu command updates the text window', any('RESIDENTIAL' in r for r in panes(mem)[1]))
    mem = run(pbin, psyms, [LEVEL_MEDIUM, CMD_NEW_CITY, ord('3'), 0, 0])
    mapp, text = panes(mem)
    check('text window: a new city goes through the title and back (hard level, status and map drawn)',
          mem[psyms['_V_difficulty']] == 2 and any('FUNDS' in r for r in text) and all(r.strip() for r in mapp),
          '\n'.join(text))

    # --- 6. the mini maps (on the 32x8 platform, which can draw bitmaps) ---
    def bitmaps(mem, symbols=psyms, cols=32, col=4, height=64, screen_row=0):
        """The 24-cell-wide mini-map picture the game drew, as rows of 0/1."""
        base = symbols['_test_bitmap']
        rows = []
        for py in range(height):
            row = []
            for cx in range(24):
                b = mem[base + (((screen_row + py // 8) * cols + col + cx) * 8) + py % 8]
                row += [(b >> (7 - i)) & 1 for i in range(8)]
            rows.append(row)
        return rows

    BAYER2 = [0, 2, 3, 1]
    BAYER4 = [0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5]

    def reference(mem, view, top, height=64, symbols=psyms):
        """The same picture worked out from the engine's memory, pixel by pixel (a tile is 2x2 pixels)."""
        lm, mm = symbols['_levelmap'], symbols['_minimaps']
        flags_at = symbols['_D_tile_flags']

        def tile_level(t):
            if t & 0x80: return 4
            if t == 2: return 0
            if t == 6: return 2
            if t <= 5 or t == 68: return 1
            return 3 if t < 56 and mem[flags_at + t] & 0x0E else 4

        level16 = lambda v: min(16, v >> 2)
        flags_of = lambda t: 0x99 if t & 0x80 else mem[flags_at + t]

        def crime(tx, ty):
            ccx, ccy = mem[symbols['_V_CCxy']], mem[symbols['_V_CCxy'] + 1]
            d = min(31, abs(tx - ccx) + abs(ty - ccy))
            e = 0 if d == 0 else 15 - ((32 - d) >> 1)
            return max(0, e - mem[mm + 576 + (ty >> 2) * 24 + (tx >> 2)])
        out = []
        for py in range(height):
            y = top + py
            row = []
            for x in range(192):
                tile = mem[lm + (y // 2) * 96 + x // 2]
                if view == 1:
                    v = tile_level(tile) > BAYER2[(y & 1) * 2 + (x & 1)]
                elif view == 6:
                    tx = x // 2
                    powered = mem[mm + 5760 + (y // 2) * 12 + tx // 8] >> (7 - tx % 8) & 1
                    level = 4 if powered else min(1, tile_level(tile))
                    v = level > BAYER2[(y & 1) * 2 + (x & 1)]
                elif view == 7:
                    level = 4 if flags_of(tile) & 6 else min(1, tile_level(tile))
                    v = level > BAYER2[(y & 1) * 2 + (x & 1)]
                elif view == 8:
                    tx, ty = x // 2, y // 2
                    v = (crime(tx, ty) if flags_of(tile) & 0x10 else 0) > BAYER4[((((ty & 1) << 1) | (y & 1)) << 2) | ((tx & 1) << 1) | (x & 1)]
                elif view in (2, 5):
                    base = mm + (1152 if view == 2 else 3456)
                    v = level16(mem[base + (y // 4) * 48 + x // 4]) > BAYER4[(y & 3) * 4 + (x & 3)]
                else:
                    base = mm + (576 if view == 3 else 0)
                    v = mem[base + (y // 8) * 24 + x // 8] > BAYER4[((y & 7) >> 1) * 4 + ((x & 7) >> 1)]
                row.append(1 if v else 0)
            out.append(row)
        return out

    def differences(got, want, top=64, cursor_y=48):
        """Pixels that differ, ignoring the 2x2 the cursor inverts (the cursor is at map 48, cursor_y)."""
        cursor = {(96 + i, 2 * cursor_y - top + j) for i in (0, 1) for j in (0, 1)}
        return [(x, y) for y in range(len(got)) for x in range(192) if got[y][x] != want[y][x] and (x, y) not in cursor]

    KEY_M = ord('m')
    for view, name in ((1, 'city'), (2, 'pollution'), (3, 'police'), (4, 'fire'), (5, 'traffic'), (6, 'power'), (7, 'transport'), (8, 'crime')):
        mem = run(pbin, psyms, [LEVEL_MEDIUM, PAUSE] + [KEY_M] * view + [0] * 12)
        got = bitmaps(mem)
        d = differences(got, reference(mem, view, 64))
        check(f'mini map {view}: {name} is drawn as the engine data says', not d, f'{len(d)} pixels differ, first {d[:4]}')
        if view > 1:        # the harness fills the coverage maps with a pattern, so something must show
            lit = sum(map(sum, got))
            check(f'mini map {view}: {name} has lit and dark pixels', (20 if view == 8 else 300) < lit < 192 * 64 - 300, f'{lit} of 12288 lit')
        _, text = panes(mem)
        check(f'mini map {view}: the text window names it', any(minimap_name in r for r in text for minimap_name in [name.upper()]),
              '\n'.join(text))
    mem = run(pbin, psyms, [LEVEL_MEDIUM, PAUSE, KEY_M] + [0] * 12)
    lit = sum(map(sum, bitmaps(mem)))
    check('mini map: the city view shows the water', 100 < lit < 192 * 64 - 100, f'{lit} of 12288 pixels lit')
    # the cursor in the top half: the picture shows the top of the city, and the cursor's pixel is in it
    for view in (1, 3):
        mem = run(pbin, psyms, [LEVEL_MEDIUM, PAUSE] + [KEY_FAR_UP] * 5 + [KEY_M] * view + [0] * 12)
        d = differences(bitmaps(mem), reference(mem, view, 0), 0, 8)
        check(f'mini map {view}: with the cursor in the top half the top of the city is shown', not d, f'{len(d)} pixels differ, first {d[:4]}')

    # up and down turn the pages (the cursor stays where it is: its 2x2 is only shown on the page it is on)
    # the pages start where the cursor is (64) and step 48 pixels, so 16 stay in view
    for keys, top, what in (([KEY_UP], 16, 'up steps 48 pixels back, keeping 16 of the last page in view'), ([KEY_DOWN], 112, 'down steps 48 pixels on'),
                            ([KEY_DOWN, KEY_DOWN], 128, 'down stops at the end of the city'), ([KEY_DOWN, KEY_DOWN, KEY_DOWN], 128, 'down stays there'),
                            ([KEY_UP, KEY_UP, KEY_UP, KEY_UP], 0, 'up stops at the top of the city'),
                            ([KEY_FAR_DOWN], 112, 'shifted down turns a page too')):
        mem = run(pbin, psyms, [LEVEL_MEDIUM, PAUSE, KEY_M] + keys + [0] * 12)
        d = differences(bitmaps(mem), reference(mem, 1, top), top, 48)
        check(f'mini map: {what}', not d, f'{len(d)} pixels differ, first {d[:4]}')

    mem = run(pbin, psyms, [LEVEL_MEDIUM, PAUSE, KEY_M, 27, 0, 0])
    mapp, text = panes(mem)
    check('mini map: escape goes back to the city instead of quitting', mem[psyms['_test_done']] == 1 and any('~' in r for r in mapp)
          and not any('MAP:' in r for r in text), '\n'.join(mapp))
    mem = run(pbin, psyms, [LEVEL_MEDIUM, PAUSE, ord('x')] + [0] * 20)
    check('a platform with menus: x does not quit (quit is in the menu)', mem[psyms['_test_frames']] >= 20, f"{mem[psyms['_test_frames']]} frames")
    mem = run(pbin, psyms, [LEVEL_MEDIUM, PAUSE, 27] + [0] * 20)
    check('a platform with menus: escape does not quit either', mem[psyms['_test_frames']] >= 20, f"{mem[psyms['_test_frames']]} frames")

    # --- 6a. a taller mini map in the Aquarius+'s 40x25 map window ---
    hbin, hsyms = build_hires_minimap()
    mem = run(hbin, hsyms, [LEVEL_MEDIUM, PAUSE, KEY_M] + [0] * 12)
    got = bitmaps(mem, hsyms, 40, 8, 152, 6)
    want = reference(mem, 1, 40, 152, hsyms)
    d = differences(got, want, 40)
    check('high-resolution mini map: all 19 map-window rows are used', not d, f'{len(d)} pixels differ, first {d[:4]}')
    a = hsyms['_test_screen']
    caption = mem[a + 5 * 40:a + 6 * 40].decode('latin1')
    check('high-resolution mini map: the status-panel caption remains above the picture', 'MAP: CITY' in caption and 'M NEXT' in caption, repr(caption))
    after_page_key = run(hbin, hsyms, [LEVEL_MEDIUM, PAUSE, KEY_M, KEY_UP] + [0] * 12)
    d = differences(bitmaps(after_page_key, hsyms, 40, 8, 152, 6), reference(after_page_key, 1, 0, 152, hsyms), 0)
    check('high-resolution mini map: up shows the remaining top strip of the city', not d, f'{len(d)} pixels differ, first {d[:4]}')
    # --- 6b. scrolling the map by moving its pixels (HAVE_SCROLL): the same picture as drawing every cell ---
    sbin, ssyms = build_scroll()
    script = [LEVEL_MEDIUM, PAUSE] + moves(30, 0) + moves(0, 22) + moves(-26, 0) + moves(0, -30) + moves(12, 12) + moves(-3, 40) + [0] * 10
    plain = run(hbin, hsyms, script)
    moved = run(sbin, ssyms, script)

    def map_pictures(mem, symbols):
        b = symbols['_test_bitmap']
        return mem[b + 6 * 40 * 8:b + 25 * 40 * 8]

    scrolls = moved[ssyms['_test_scrolls']] | moved[ssyms['_test_scrolls'] + 1] << 8
    diff = [i for i, (a, b) in enumerate(zip(map_pictures(plain, hsyms), map_pictures(moved, ssyms))) if a != b]
    check('scrolling by moving pixels: the map is drawn %d times by scrolling, and is the same picture as drawing every cell' % scrolls,
          scrolls > 10 and not diff,
          f'{scrolls} scrolls; {len(diff)} bytes differ, first cells (col,row) {sorted({((i // 8) % 40, (i // 8) // 40) for i in diff})[:8]}')

    # --- 6b. the pop-up menu and the file dialogues are boxes in the middle of the map (rows 6..24), not the screen ---
    def box_rows(m, text=None):
        """The screen's rows, and the first and last row of the box (the one round `text`, the screen's lowest row
        of a box if none: the headless screen keeps the text under the pictures the game draws over it)."""
        a = hsyms['_test_screen']
        scr = [m[a + r * 40:a + (r + 1) * 40].decode('latin1') for r in range(25)]
        edge = [r for r, row in enumerate(scr) if row.strip().startswith('+--') and row.strip().endswith('--+')]
        if text is not None:
            at = [r for r, row in enumerate(scr) if text in row]
            if not at:
                return scr, (None, None)
            above = [r for r in edge if r < at[0]]
            below = [r for r in edge if r > at[0]]
            return scr, (above[-1], below[0]) if above and below else (None, None)
        return scr, (edge[0], edge[-1]) if len(edge) >= 2 else (None, None)
    mem = run(hbin, hsyms, [LEVEL_MEDIUM, PAUSE, KEY_ESC] + [0] * 8)
    scr, (top, bottom) = box_rows(mem)
    check('popup menu: it is centred in the map, below the status panel', top is not None and top >= 6 and abs((top - 6) - (24 - bottom)) <= 1,
          f'box rows {top}..{bottom}')
    mem = run(hbin, hsyms, [LEVEL_MEDIUM, PAUSE, KEY_ESC, KEY_DOWN, KEY_DOWN, 13] + [0] * 8)
    scr, (top, bottom) = box_rows(mem, 'SAVE THIS CITY')
    check('save: the dialogue is a box in the map asking for the file name',
          top is not None and bottom - top == 6 and top >= 6 and abs((top - 6) - (24 - bottom)) <= 1 and any('SAVE THIS CITY' in r for r in scr)
          and any('FILE NAME:' in r for r in scr), f'box rows {top}..{bottom}')
    check('save: the dialogue leaves the status panel alone', any('FUNDS' in r for r in scr[:6]), '\n'.join(scr[:6]))
    mem = run(hbin, hsyms, [LEVEL_MEDIUM, PAUSE, KEY_ESC, KEY_DOWN, KEY_DOWN, 13, ord('a'), ord('b'), 13, 13] + [0] * 8)
    name = bytes(mem[hsyms['_test_file_name']:hsyms['_test_file_name'] + 3])
    check('save: the file is written under the typed name', name == b'ab\0', repr(name))
    # --- 6c. the colour a tile mini map (the Multi 8's reserve mode): the whole city, every other row ---
    nbin, nsyms = build_native_minimap()

    keep = [5, 21, 22, 25]                                     # the rows the test platform keeps

    def rows48(m):
        a = nsyms['_test_minirow']
        return {sy: list(m[a + k * 96:a + (k + 1) * 96]) for k, sy in enumerate(keep)}
    mem = run(nbin, nsyms, [LEVEL_MEDIUM, PAUSE, KEY_M, 0])
    a = nsyms['_test_minirow_n']
    drawn = sum(1 for r in range(48) if mem[a + r])
    caption = mem[nsyms['_test_screen'] + 5 * 40:nsyms['_test_screen'] + 6 * 40].decode('latin1')
    check('native mini map: the status says what was asked for at once, before the map is drawn',
          'MAP: CITY' in caption and 0 < drawn < 48, f'{drawn} rows drawn; {caption!r}')
    mem = run(nbin, nsyms, [LEVEL_MEDIUM, PAUSE, KEY_M] + [0] * 12)
    a = nsyms['_test_minirow_n']
    check('native mini map: all 48 rows are drawn', all(mem[a + r] for r in range(48)), [mem[a + r] for r in range(48)])
    rows = rows48(mem)
    cols = {c for r in rows.values() for c in r}
    check('native mini map: the city is drawn in colours (dirt, water, trees...)', {0, 1, 4} <= cols and cols <= set(range(8)), sorted(cols))
    check('native mini map: a road is white, houses cyan (the tiles the test puts in the city)',
          rows[21][40:60] == [7] * 20 and rows[22][40:60] == [5] * 20, (rows[21][38:62], rows[22][38:62]))
    want = []
    for g in (0x10, 0x11, 0x14, 0x15, 0x18, 0x19, 0x1A, 0x1D, 0x1E, 0x00, 0x12, 0x16):     # a zone row's colour from its group
        want += [5 if 0x11 <= g <= 0x14 else 6 if 0x15 <= g <= 0x18 else 3 if 0x1A <= g <= 0x1D else 2] * 4
    check('native mini map: a large zone is residential cyan, commercial yellow, industrial magenta, or a service red, by its group',
          rows[25][40:88] == want, str((rows[25][40:88], want)))
    lm = mem[nsyms['_levelmap']:nsyms['_levelmap'] + 9216]
    water = [(r, x) for r in rows for x in range(96) if lm[2 * r * 96 + x] == 0 and rows[r][x] not in (1, 6)]      # (6: the blinking cursor's tile, inverted)
    check('native mini map: row sy shows tile row 2 sy, every tile column', not water, f'{len(water)} water tiles are not blue')
    mem = run(nbin, nsyms, [LEVEL_MEDIUM, PAUSE, KEY_M, KEY_M] + [0] * 12)
    rows = rows48(mem)
    mm = mem[nsyms['_minimaps']:nsyms['_minimaps'] + 6912]
    bad = [(r, x) for r in keep for x in range(96) if rows[r][x] != mm[1152 + r * 48 + (x >> 1)] >> 5]
    check('native mini map: a density map (pollution) is eight colours, an eighth of its value, 48x48 over 96x96', not bad, bad[:6])
    mem = run(nbin, nsyms, [LEVEL_MEDIUM, PAUSE, KEY_M] + [0] * 12 + [ord('x'), 0, 0])
    caption = mem[nsyms['_test_screen'] + 5 * 40:nsyms['_test_screen'] + 6 * 40].decode('latin1')
    check('native mini map: X goes back to the city', 'MAP:' not in caption, repr(caption))

    # --- 6d. the same with the tiles' own pictures at a quarter of the size (HAVE_MINIMAP_ART), the views laid over them ---
    abin, asyms = build_native_art()
    mini = open(os.path.join(ROOT, 'build', 'common', 'minitiles_640x200_3bpp.bin'), 'rb').read()

    def nib(rec, i):
        return (rec[i >> 1] >> 4) if i % 2 == 0 else rec[i >> 1] & 15

    def tile_nibbles(rec, c):
        """A tile's nine nibbles (plane 0's three lines, plane 1's, plane 2's): its picture, or with a level c (1..7) its ground in that
        colour, solid, and its shape (what is not its ground in any plane) as it is."""
        n = [nib(rec, i) for i in range(9)]
        if not c:
            return n
        g = [15 if (nib(rec, 9) >> k) & 1 else 0 for k in range(3)]
        out = [0] * 9
        for j in range(3):
            d = (n[j] ^ g[0]) | (n[3 + j] ^ g[1]) | (n[6 + j] ^ g[2])
            for k in range(3):
                out[3 * k + j] = (n[3 * k + j] & d) | (~d & 15 if (c >> k) & 1 else 0)
        return out

    def row_bytes(recs, levels):
        """What mm_row holds: nine blocks of 48 bytes, a byte for two tiles (the left tile in the high half)."""
        tiles = [tile_nibbles(r, c) for r, c in zip(recs, levels)]
        return bytes((tiles[2 * q][i] << 4) | tiles[2 * q + 1][i] for i in range(9) for q in range(48))

    def city_recs(lm, ty):
        recs, base, k = [], 0, 0
        for tx in range(96):
            t = lm[ty * 96 + tx]
            if t < 94:
                idx = t
            elif t < 128:
                idx = 2
            else:
                if t < 192:
                    base = (lm[ty * 96 + tx + 1] & 63) * 8 + (lm[ty * 96 + tx + 2] & 7)
                    k = 0
                else:
                    k += 1
                idx = 94 + base + k
            recs.append(mini[idx * 5:idx * 5 + 5])
        return recs
    keep = [5, 21, 22, 25]

    def art_rows(m):
        a = asyms['_test_minirow']
        return {sy: bytes(m[a + k * 432:a + (k + 1) * 432]) for k, sy in enumerate(keep)}
    mem = run(abin, asyms, [LEVEL_MEDIUM, PAUSE, KEY_M, 0])
    a = asyms['_test_minirow_n']
    drawn = sum(1 for r in range(48) if mem[a + r])
    caption = mem[asyms['_test_screen'] + 5 * 40:asyms['_test_screen'] + 6 * 40].decode('latin1')
    check('art mini map: the status says what was asked for at once, before the map is drawn', 'MAP: CITY' in caption and 0 < drawn < 48,
          f'{drawn} rows drawn; {caption!r}')
    mem = run(abin, asyms, [LEVEL_MEDIUM, PAUSE, KEY_M] + [0] * 16)
    a = asyms['_test_minirow_n']
    check('art mini map: all 48 rows are drawn', all(mem[a + r] for r in range(48)), [mem[a + r] for r in range(48)])
    lm = mem[asyms['_levelmap']:asyms['_levelmap'] + 9216]
    got = art_rows(mem)
    bad = [sy for sy in keep if got[sy] != row_bytes(city_recs(lm, 2 * sy), [0] * 96)]
    check('art mini map: each row is its tiles\' pictures (ordinary tiles and large zones) in the three planes, four pixels by three lines each',
          not bad, f'rows {bad} differ')
    mem = run(abin, asyms, [LEVEL_MEDIUM, PAUSE, KEY_M, KEY_M] + [0] * 16)
    lm = mem[asyms['_levelmap']:asyms['_levelmap'] + 9216]
    mm = mem[asyms['_minimaps']:asyms['_minimaps'] + 6912]
    got = art_rows(mem)
    bad = [sy for sy in keep if got[sy] != row_bytes(city_recs(lm, 2 * sy), [mm[1152 + sy * 48 + (x >> 1)] >> 5 for x in range(96)])]
    check('art mini map: pollution is laid over the city: each tile\'s ground is the colour of its level (an eighth of its value), '
          'solid, its shape as it is, and the picture as it is where there is no level', not bad, f'rows {bad} differ')
    tf = mem[asyms['_D_tile_flags']:asyms['_D_tile_flags'] + 128]
    water = {0, 1, 3, 4, 5, 68, 92, 93}
    mem = run(abin, asyms, [LEVEL_MEDIUM, PAUSE] + [KEY_M] * 7 + [0] * 16)
    lm = mem[asyms['_levelmap']:asyms['_levelmap'] + 9216]
    got = art_rows(mem)

    def transport_level(t):
        return 7 if t < 128 and tf[t] & 6 else 1 if t in water else 0
    bad = [sy for sy in keep if got[sy] != row_bytes(city_recs(lm, 2 * sy), [transport_level(lm[2 * sy * 96 + x]) for x in range(96)])]
    check('art mini map: roads and rails are laid over the city in white, water in blue (transport)', not bad, f'rows {bad} differ')
    mem = run(abin, asyms, [LEVEL_MEDIUM, PAUSE, KEY_M] + [0] * 16 + [ord('x'), 0, 0])
    caption = mem[asyms['_test_screen'] + 5 * 40:asyms['_test_screen'] + 6 * 40].decode('latin1')
    check('art mini map: X goes back to the city', 'MAP:' not in caption, repr(caption))
    for name, b2, s2 in (('art', abin, asyms), ('native', nbin, nsyms)):
        m0 = run(b2, s2, [LEVEL_MEDIUM, PAUSE, KEY_M] + [0] * 4)
        m1 = run(b2, s2, [LEVEL_MEDIUM, PAUSE, KEY_M] + [ord('p')] * 5 + [ord('a')] * 3 + [ord(' ')] * 2 + [0] * 4)
        check(f'{name} mini map: there is no cursor to move and nothing to build with: movement and the tools do nothing in it',
              m0[s2['_cur_x']] == m1[s2['_cur_x']] and m0[s2['_cur_y']] == m1[s2['_cur_y']] and money(m0, s2) == money(m1, s2),
              f"cursor {m1[s2['_cur_x']]},{m1[s2['_cur_y']]} funds {money(m1, s2)}")
        m2 = run(b2, s2, [LEVEL_MEDIUM, PAUSE, KEY_M, ord('x')] + [ord('p')] * 5 + [0] * 4)
        check(f'{name} mini map: back in the city the cursor moves again', m2[s2['_cur_x']] == m0[s2['_cur_x']] + 5, m2[s2['_cur_x']])

    mem = run(pbin, psyms, [LEVEL_MEDIUM, ord('+')] + [0] * 250)
    text = panes(mem)[1]
    check('the advisor message is on row 6 (below the icons), where the Z88 shows it', text[6].strip() and not text[3].strip(), '\n'.join(text))
    mem = run(pbin, psyms, [LEVEL_MEDIUM, PAUSE] + [KEY_M] * 9 + [0, 0])
    check('mini map: m cycles through the views and back to the city', any('~' in r for r in panes(mem)[0]))
    mem = run(pbin, psyms, [LEVEL_MEDIUM, PAUSE, CMD_MAP + 1, 0, 0])
    check('mini map: a menu command shows its view', any('POLLUTION' in r for r in panes(mem)[1]))
    mem = run(pbin, psyms, [LEVEL_MEDIUM, PAUSE, CMD_MAP + 1, CMD_MAP_OFF, 0, 0])
    check('mini map: the menu can go back to the city', any('~' in r for r in panes(mem)[0]) and not any('MAP:' in r for r in panes(mem)[1]))

    # --- 6b. the budget can be automatic ---
    CMD_AUTOBUDGET_ON, CMD_AUTOBUDGET_OFF = 0xA8, 0xA9
    mem = run(pbin, psyms, [LEVEL_MEDIUM, PAUSE, CMD_AUTOBUDGET_ON, 0, 0])
    check('auto-budget: the menu turns it on', mem[psyms['_V_auto_budget']] == 1)
    mem = run(pbin, psyms, [LEVEL_MEDIUM, PAUSE, CMD_AUTOBUDGET_ON, CMD_AUTOBUDGET_OFF, 0, 0])
    check('auto-budget: and off again', mem[psyms['_V_auto_budget']] == 0)
    mem = run(pbin, psyms, [LEVEL_MEDIUM, ord('+'), CMD_AUTOBUDGET_ON] + [0] * 1500)
    text = panes(mem)[1]
    check('auto-budget: in November the engine runs the budget without stopping for the screen',
          not any('FISCAL' in r for r in text) and any('FUNDS' in r for r in text), '\n'.join(text))

    # --- 6c. the sound option ---
    CMD_SOUND_ON, CMD_SOUND_OFF = 0xAA, 0xAB
    mem = run(pbin, psyms, [LEVEL_MEDIUM, PAUSE, CMD_SOUND_OFF, 0, 0])
    check('sound: the menu turns it off', mem[psyms['_sound_enabled']] == 0)
    mem = run(pbin, psyms, [LEVEL_MEDIUM, PAUSE, CMD_SOUND_OFF, CMD_SOUND_ON, 0, 0])
    check('sound: and on again', mem[psyms['_sound_enabled']] == 1)

    # --- 6d. disasters started from the menu ---
    CMD_DISASTER = 0x81
    for n, (name, alert) in enumerate((('fire', 22), ('flood', 23), ('earthquake', 24), ('air crash', 0), ('tornado', 26), ('meltdown', 0))):
        mem = run(pbin, psyms, [LEVEL_MEDIUM, PAUSE, CMD_DISASTER + n] + [0] * 40)
        # the engine takes the request a few frames on (sim_periodic); an air crash needs an airport and a meltdown a
        # nuclear plant, as on the Spectrum, so in an empty city those two come to nothing
        check(f'disaster menu: {name} is taken up by the engine' + (f' and raises alert {alert}' if alert else ' (nothing to crash or melt in an empty city)'),
              mem[psyms['_V_disaster_option']] == 0 and mem[psyms['_V_alertmessage']] == alert,
              f"option {mem[psyms['_V_disaster_option']]}, alert {mem[psyms['_V_alertmessage']]}")
    mem = run(pbin, psyms, [LEVEL_MEDIUM, PAUSE, CMD_DISASTER + 1, 0])
    check('disaster menu: the request is held in V_disaster_option until the engine takes it', mem[psyms['_V_disaster_option']] in (0, 2))

    # --- 6e. the city's name ---
    CMD_SAVE, CMD_LOAD = 0xA6, 0xA7
    rd = lambda mem, name, n: bytes(mem[psyms[name]:psyms[name] + n])
    app_name = lambda mem: bytes(mem[psyms['_test_app_name']:psyms['_test_app_name'] + 16]).split(b'\0')[0]
    mem = run(pbin, psyms, [LEVEL_MEDIUM, PAUSE, 0, 0])
    check('city name: without one the default, HERESVILLE, is the name the machine is told', app_name(mem) == b'HERESVILLE', repr(app_name(mem)))
    mem = run(pbin, psyms, [LEVEL_MEDIUM, PAUSE, 0, 0], city=b'noodle')
    check('city name: a name typed at the title screen is the name the machine is told', app_name(mem) == b'noodle', repr(app_name(mem)))
    clears = lambda m: m[psyms['_test_text_clears']] | m[psyms['_test_text_clears'] + 1] << 8
    check('city name: typing letters redraws the name only, not the whole text window (the same number of clears with a long name as with none)',
          clears(run(pbin, psyms, [LEVEL_MEDIUM, PAUSE, 0, 0], city=b'abcdefghijkl')) == clears(run(pbin, psyms, [LEVEL_MEDIUM, PAUSE, 0, 0])),
          f"{clears(run(pbin, psyms, [LEVEL_MEDIUM, PAUSE, 0, 0], city=b'abcdefghijkl'))} vs {clears(run(pbin, psyms, [LEVEL_MEDIUM, PAUSE, 0, 0]))}")
    mem = run(pbin, psyms, [LEVEL_MEDIUM, PAUSE, 0, 0], city=b'ab' + bytes([127, 127]) + b'cd')
    check('city name: delete takes letters back and the name is right on screen (ab, delete, delete, cd = cd)', app_name(mem) == b'cd', repr(app_name(mem)))
    mem = run(pbin, psyms, [LEVEL_MEDIUM, PAUSE, 0, 0], city=b'a name that is too long')
    check('city name: it is cut to the 12 the Spectrum keeps', app_name(mem) == b'a name that ', repr(app_name(mem)))
    mem = run(pbin, psyms, [LEVEL_MEDIUM, PAUSE, CMD_SAVE, ord('f'), 13, ord(' '), 0, 0], city=b'noodle')
    check('city name: it is in the save file header, padded with spaces', rd(mem, '_test_file', 31)[19:31] == b'noodle      ', repr(rd(mem, '_test_file', 31)[19:31]))
    mem = run(pbin, psyms, [LEVEL_MEDIUM, PAUSE, CMD_SAVE, ord('f'), 13, ord(' '), CMD_NEW_CITY, ord('2'), 0, 0], city=b'noodle')
    check('city name: a new city goes back to the default', app_name(mem) == b'HERESVILLE', repr(app_name(mem)))
    mem = run(pbin, psyms, [LEVEL_MEDIUM, PAUSE, CMD_SAVE, ord('f'), 13, ord(' '), CMD_NEW_CITY, ord('2'), CMD_LOAD, ord('f'), 13, 0, 0], city=b'noodle')
    check('city name: loading the file brings the name back', app_name(mem) == b'noodle', repr(app_name(mem)))

    # --- 7. the budget screen (the 32x8 platform has it too) ---
    CMD_BUDGET = 0xA4
    byte_p = lambda mem, name: mem[psyms[name]]
    mem = run(pbin, psyms, [LEVEL_MEDIUM, PAUSE, CMD_BUDGET, 0, 0])
    text = panes(mem)[1]
    check('budget: the screen shows the headings and the departments',
          all(any(w in r for r in text) for w in ('FISCAL BUDGET', 'TAX RATE', 'TRANSPORT', 'POLICE', 'FIRE', 'CASH FLOW', 'ENTER OK')),
          '\n'.join(text))
    check('budget: the funds row shows the label and both figures, not overlapping (the test city pays 350 in tax: FUNDS 10000>10350)',
          re.search(r'CASH FLOW\s+350\s+FUNDS\s+10000>\s+10350', text[6]) is not None, repr(text[6]))
    check('budget: the figures of the three departments line up under their headings',
          text[2].index('REQSTD') + 5 == text[3].index('0 ') and all(len(r.rstrip()) <= 40 for r in text), '\n'.join(text))
    check('budget: it starts with the tax rate of 7%', any('TAX RATE  7%' in r for r in text), '\n'.join(text))
    check('budget: every line fits the 8 rows and 40 columns', all(len(r.rstrip()) <= 40 for r in text))
    map_clears = lambda m: m[psyms['_test_clears']] | m[psyms['_test_clears'] + 1] << 8
    base = map_clears(run(pbin, psyms, [LEVEL_MEDIUM, PAUSE, 0, 0]))
    check('budget: leaving the screen redraws the text window but not the map (the map console is not cleared again)',
          map_clears(run(pbin, psyms, [LEVEL_MEDIUM, PAUSE, CMD_BUDGET, 13, 0, 0])) == base, f'{map_clears(run(pbin, psyms, [LEVEL_MEDIUM, PAUSE, CMD_BUDGET, 13, 0, 0]))} vs {base}')
    mem = run(pbin, psyms, [LEVEL_MEDIUM, PAUSE, CMD_BUDGET, 13, 0, 0])
    check('budget: ...and the status panel is back in the text window', any('FUNDS' in r for r in panes(mem)[1]), '\n'.join(panes(mem)[1]))
    mem = run(pbin, psyms, [LEVEL_MEDIUM, PAUSE, CMD_BUDGET, KEY_RIGHT, KEY_RIGHT, 0, 0])
    check('budget: p raises the tax rate and the screen shows it',
          byte_p(mem, '_SMC_tax_rate') == 9 and any('TAX RATE  9%' in r for r in panes(mem)[1]))
    mem = run(pbin, psyms, [LEVEL_MEDIUM, PAUSE, CMD_BUDGET] + [KEY_LEFT] * 9 + [0, 0])
    check('budget: the tax rate stops at 0', byte_p(mem, '_SMC_tax_rate') == 0)
    mem = run(pbin, psyms, [LEVEL_MEDIUM, PAUSE, CMD_BUDGET] + [KEY_RIGHT] * 20 + [0, 0])
    check('budget: the tax rate stops at 20', byte_p(mem, '_SMC_tax_rate') == 20)
    mem = run(pbin, psyms, [LEVEL_MEDIUM, PAUSE, CMD_BUDGET, KEY_DOWN, KEY_LEFT, KEY_DOWN, KEY_LEFT, KEY_LEFT, KEY_DOWN, KEY_LEFT, KEY_LEFT, KEY_LEFT, 0, 0])
    check('budget: a selects the next item and o lowers its funding by 10% (transport 90, police 80, fire 70)',
          (byte_p(mem, '_SMC_transport_percent'), byte_p(mem, '_SMC_police_percent'), byte_p(mem, '_SMC_fire_percent')) == (90, 80, 70))
    mem = run(pbin, psyms, [LEVEL_MEDIUM, PAUSE, CMD_BUDGET, KEY_RIGHT, 13, 0, 0])
    text = panes(mem)[1]
    check('budget: enter accepts it and the game goes on (status panel back, new rate kept)',
          any('FUNDS' in r for r in text) and not any('FISCAL' in r for r in text) and byte_p(mem, '_SMC_tax_rate') == 8, '\n'.join(text))
    check('budget: the game asks the player for the annual budget', byte_p(mem, '_V_auto_budget') == 0)
    # the engine's own request, in November: fast, until the year's tick; then the player changes the tax rate and accepts
    mem = run(pbin, psyms, [LEVEL_MEDIUM, ord('+')] + [0] * 1500 + [KEY_RIGHT, KEY_RIGHT, 0, 0])
    text = panes(mem)[1]
    check('budget: in November the game stops for the budget screen', any('FISCAL BUDGET' in r for r in text), '\n'.join(text))
    check('budget: the player can change the tax rate in it', byte_p(mem, '_SMC_tax_rate') == 9)

    # --- 8. the evaluation screen: the mayor's approval ---
    CMD_EVALUATION = 0xA5
    mem = run(pbin, psyms, [LEVEL_MEDIUM, PAUSE, CMD_EVALUATION, 0, 0])
    text = panes(mem)[1]
    show = '\n'.join(text)
    has = lambda *words: any(all(w in r for w in words) for r in text)
    check('evaluation: the screen shows the mayor approval and the problems',
          has('MAYOR APPROVAL') and has('TRAFFIC') and has('POLLUTION') and has('CRIME') and has('FIRE') and has('TAXES')
          and has('HOUSE PRICES') and has('UNEMPLOYMENT') and has('CITY SCORE') and has('ENTER OK'), show)
    check('evaluation: each problem is the percentage the Spectrum works out (10, 10, 10, 10, 16, 4, 0)',
          has('TRAFFIC', ' 10%') and has('POLLUTION', ' 10%') and has('CRIME', ' 10%') and has('FIRE', ' 10%')
          and has('TAXES', ' 16%') and has('HOUSE PRICES', '  4%') and has('UNEMPLOYMENT', '  0%'), show)
    check('evaluation: the city score is (250 - 3 * 60) * 4 = 280', has('CITY SCORE', ' 280'), show)
    check('evaluation: population, migration and assessed value',
          has('POPULATION', ' 5000') and has('MIGRATION', ' 1000') and has('ASSESSED VALUE $4000000'), show)
    check('evaluation: the category is a town and the level medium', has('TOWN', 'MEDIUM'), show)
    row = next(r for r in text if 'MAYOR APPROVAL' in r)
    yes, no = (int(x) for x in re.findall(r'(\d+)%', row))
    check('evaluation: approval is yes + no = 100 and about 280/1024 of the people say yes',
          yes + no == 100 and 10 <= yes <= 45, row)
    mem = run(pbin, psyms, [LEVEL_MEDIUM, PAUSE, CMD_EVALUATION, 0, 0], patch={'_test_poke_city': b'\0'})
    text = panes(mem)[1]
    row = next(r for r in text if 'MAYOR APPROVAL' in r)
    check('evaluation: with nobody in the city there is nobody to ask',
          any('NOBODY LIVES HERE' in r for r in text) and ' 0%' in row, '\n'.join(text))
    mem = run(pbin, psyms, [LEVEL_MEDIUM, PAUSE, ord('v'), 13, 0, 0])
    text = panes(mem)[1]
    check('evaluation: v opens it and enter closes it again',
          any('FUNDS' in r for r in text) and not any('MAYOR APPROVAL' in r for r in text), '\n'.join(text))

    # --- 8b. full-height modal screens: the full layout follows the Spectrum's sections ---
    mbin, msyms = build_modal()
    mem = run(mbin, msyms, [LEVEL_MEDIUM, PAUSE, CMD_BUDGET, 0, 0])
    text = screen(mem, msyms)
    check('full-height budget: collection, cash flow and both funds figures have their own rows',
          all(word in text[row] for row, word in ((0, 'FISCAL BUDGET'), (2, 'TAX RATE'), (4, 'TAX COLLECTED'),
                                                    (6, 'REQUESTED'), (8, 'TRANSPORT'), (10, 'POLICE'), (12, 'FIRE'),
                                                    (15, 'CASH FLOW'), (17, 'PREVIOUS FUNDS'),
                                                    (19, 'CURRENT FUNDS'), (23, 'ENTER OK'))), '\n'.join(text))
    mem = run(mbin, msyms, [LEVEL_MEDIUM, PAUSE, CMD_EVALUATION, 0, 0])
    text = screen(mem, msyms)
    check('full-height evaluation: approval, problems, statistics and category have their own sections',
          all(word in text[row] for row, word in ((0, 'EVALUATION'), (2, 'GOOD JOB'), (3, 'YES'),
                                                    (6, 'WORST PROBLEMS'), (8, 'TRAFFIC'), (11, 'UNEMPLOYMENT'),
                                                    (14, 'POPULATION'), (16, 'ASSESSED VALUE'), (19, 'CATEGORY'),
                                                    (21, 'CITY SCORE'), (23, 'ENTER OK'))), '\n'.join(text))

    # --- 8c. the 32 column layouts, on a 32x24 screen (the Spectrum's shape) ---
    nbin, nsyms = build_narrow()
    mem = run(nbin, nsyms, [LEVEL_MEDIUM, PAUSE, CMD_BUDGET, 0, 0])
    text = screen(mem, nsyms, 32)
    check('32 column budget: every group on its own row',
          all(word in text[row] for row, word in ((0, 'FISCAL BUDGET'), (2, 'TAX RATE'), (4, 'TAX COLLECTED'),
                                                    (6, 'REQSTD'), (8, 'TRANSPORT'), (10, 'POLICE'), (12, 'FIRE'),
                                                    (15, 'CASH FLOW'), (17, 'PREVIOUS FUNDS'),
                                                    (19, 'CURRENT FUNDS'), (23, 'ENTER OK'))), '\n'.join(text))
    check('32 column budget: the figures sit under their headings (the % of each service in column 28)',
          all(text[r][28] == '%' and text[r][16].isdigit() and text[r][23].isdigit() for r in (8, 10, 12))
          and text[2][12] == '%', '\n'.join(text))
    mem = run(nbin, nsyms, [LEVEL_MEDIUM, PAUSE, CMD_EVALUATION, 0, 0])
    text = screen(mem, nsyms, 32)
    check('32 column evaluation: approval, the problems one to a row, statistics and category',
          all(word in text[row] for row, word in ((0, 'EVALUATION'), (2, 'GOOD JOB'), (3, 'YES'), (4, 'NO'),
                                                    (6, 'WORST PROBLEMS'), (8, 'TRAFFIC'), (9, 'POLLUTION'),
                                                    (10, 'CRIME'), (11, 'FIRE'), (12, 'TAXES'), (13, 'HOUSE PRICES'),
                                                    (14, 'UNEMPLOYMENT'), (16, 'POPULATION'), (17, 'MIGRATION'),
                                                    (18, 'ASSESSED VALUE'), (20, 'CATEGORY'), (21, 'GAME LEVEL'),
                                                    (22, 'CITY SCORE'), (23, 'ENTER OK'))), '\n'.join(text))
    check('32 column evaluation: the percentages line up (the % in column 22) and nothing is left of the screen',
          all(text[r][22] == '%' for r in range(8, 15)) and text[3][14] == '%', '\n'.join(text))

    # --- 9. the moving sprites, drawn over the map's pictures (composited into them, and drawn over them) ---
    for tgt in ('testsprites', 'testoverlay'):
        subprocess.run(['make', '-s', '-C', ROOT, 'build/' + tgt + '/simcity.bin'], check=True, capture_output=True)
        ssyms = {}
        for line in open(os.path.join(ROOT, 'build', tgt, 'simcity.map')):
            m = re.match(r'(\S+)\s*=\s*\$([0-9A-Fa-f]+)', line)
            if m:
                ssyms[m.group(1)] = int(m.group(2), 16)
        sbin = open(os.path.join(ROOT, 'build', tgt, 'simcity.bin'), 'rb').read()
        spr = open(os.path.join(ROOT, 'assets', 'transport.spr'), 'rb').read()

        def cells(mem):
            b = ssyms['_test_bitmap']
            return {(c, r): bytes(mem[b + (r * 32 + c) * 8:b + (r * 32 + c) * 8 + 8]) for r in range(8) for c in range(32)}

        with_s = cells(run(sbin, ssyms, [LEVEL_MEDIUM, PAUSE] + [0] * 20))
        without = cells(run(sbin, ssyms, [LEVEL_MEDIUM, PAUSE] + [0] * 20, patch={'_test_poke_sprites': b'\0'}))
        # origin of the view is (32, 44): the train at map (40, 46) is console cell (8, 2), the plane at (36, 45) is (4, 1)
        want = {}
        for (c0, r0, sid) in ((8, 2, 3), (4, 1, 0)):
            for qy in (0, 1):
                for qx in (0, 1):
                    base = without[(c0 + qx, r0 + qy)]
                    want[(c0 + qx, r0 + qy)] = bytes(base[r] | spr[sid * 32 + (qy * 8 + r) * 2 + qx] for r in range(8))
        wrong = [(k, with_s[k].hex(), v.hex()) for k, v in want.items() if with_s[k] != v]
        check(tgt + ' sprites: the train and the plane are drawn over the tiles, 2x2 cells each', not wrong, str(wrong[:3]))
        check(tgt + ' sprites: they changed the pictures of those cells (not all: water is solid already)', sum(with_s[k] != without[k] for k in want) >= 4)
        other = [k for k in with_s if k not in want and k != (16, 4) and with_s[k] != without[k]]
        check(tgt + ' sprites: no other cell is touched', not other, str(other[:5]))
        mem = run(sbin, ssyms, [LEVEL_MEDIUM, PAUSE] + [0] * 20 + [KEY_RIGHT] * 40 + [0] * 10)
        moved = cells(mem)
        # the view scrolled right once the cursor passed its edge: the sprite must have moved on the screen with the map
        check(tgt + ' sprites: they scroll with the map (the cells where they were no longer hold them)',
              any(moved[(8, 2)] != with_s[(8, 2)] for _ in [0]))

    # --- 10. saving and loading a city ---
    CMD_SAVE, CMD_LOAD = 0xA6, 0xA7
    rd = lambda mem, name, n: bytes(mem[psyms[name]:psyms[name] + n])
    mem = run(pbin, psyms, [LEVEL_MEDIUM, PAUSE, CMD_SAVE, ord('a'), ord('b'), 13, ord(' '), 0, 0])
    text = panes(mem)[1]
    header = rd(mem, '_test_file', 31)
    check('save: asks for a name and says it saved', rd(mem, '_test_file_name', 3) == b'ab\0', repr(rd(mem, '_test_file_name', 3)))
    check('save: the header is the Spectrum\'s (name, 7 bytes of money and date, city name)',
          header[:12] == b'ab          ' and header[12:19] == bytes([0x10, 0x27, 0, 0, 0, 0x6E, 0x07]) and header[19:31] == b'HERESVILLE  ',
          header.hex())
    lm = levelmap(mem, psyms) if False else mem[psyms['_levelmap']:psyms['_levelmap'] + 9216]
    check('save: the map is in the file after the header', rd(mem, '_test_file', 31 + 2400)[31:] == bytes(lm[3600:6000]))
    check('save: the file is 31 + 9216 bytes', int.from_bytes(rd(mem, '_test_file_len', 2), 'little') == 31 + 9216)
    spot = find_dirt_block(bytes(lm), 1)                   # somewhere a road can be built
    at = psyms['_levelmap'] + spot[1] * 96 + spot[0]
    go = moves(spot[0] - 48, spot[1] - 48, cursor=True)
    money0 = mem[psyms['_V_money']] | mem[psyms['_V_money'] + 1] << 8
    # save, build a road there (costs $10), and see it built; then do the same and load the city back
    keys = [LEVEL_MEDIUM, PAUSE] + go + [CMD_SAVE, ord('a'), ord('b'), 13, ord(' '), ord(' ')]
    built = run(pbin, psyms, keys)
    check('(the road is built at the dirt spot if we do not load: so the next test can tell)', built[at] == 7 and built[at] != lm[spot[1] * 96 + spot[0]])
    letters = run(pbin, psyms, [LEVEL_MEDIUM, PAUSE] + moves(spot[0] - 48, spot[1] - 48) + [ord(' '), 0, 0])
    check('a platform with menus: the letters O P Q A do not move the cursor (the cursor keys do: the road above)',
          letters[at] == lm[spot[1] * 96 + spot[0]])
    mem = run(pbin, psyms, keys + [CMD_LOAD, ord('a'), ord('b'), 13, 0, 0])
    check('load: the map and the money are what they were when saved (the road is gone, $10 is back)',
          mem[at] == lm[spot[1] * 96 + spot[0]] and (mem[psyms['_V_money']] | mem[psyms['_V_money'] + 1] << 8) == money0)
    base = mem[psyms['_levelmap'] + 48 * 96 + 48]
    mem = run(pbin, psyms, [LEVEL_MEDIUM, PAUSE, CMD_LOAD, ord('n'), ord('o'), 13, ord(' '), 0, 0])
    check('load: a file that is not there is reported and the city goes on',
          mem[psyms['_levelmap'] + 48 * 96 + 48] == base and mem[psyms['_test_done']] == 1)
    mem = run(pbin, psyms, [LEVEL_MEDIUM, PAUSE, CMD_SAVE, ord('x'), 27, 0, 0])
    check('save: escape cancels without saving', rd(mem, '_test_file_name', 1) == b'\0')
    mem = run(pbin, psyms, [LEVEL_MEDIUM, PAUSE, CMD_SAVE, ord('a'), ord('b'), 127, ord('c'), 13, ord(' '), 0, 0])
    check('save: delete takes back a letter (a, b, delete, c = ac)', rd(mem, '_test_file_name', 3) == b'ac\0')

    print()
    print('\n'.join(scr))
    print()
    print('FAILED: ' + ', '.join(failures) if failures else 'all UI tests passed')
    sys.exit(1 if failures else 0)


if __name__ == '__main__':
    main()
