#!/usr/bin/env python3
"""Headless UI test: the real game core (ui/) and portable engine, built for z88dk's
+test target and run under z88dk-ticks with a scripted keyboard.

The same ui/ sources are what the Aquarius+, NC200 and Z88 builds use; only the
platform file differs (platform/test_ui here, platform/console there).

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


def run(binary, syms, keys, limit=4_000_000_000, patch=None):
    """Run the game with the given key script; return (memory dump, symbols)."""
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


def screen(mem, syms):
    a = syms['_test_screen']
    return [mem[a + r * COLS:a + (r + 1) * COLS].decode('latin1') for r in range(ROWS)]


def levelmap(mem, syms):
    a = syms['_levelmap']
    return mem[a:a + MAP_W * MAP_W]


def money(mem, syms):
    a = syms['_V_money']
    return mem[a] | mem[a + 1] << 8 | mem[a + 2] << 16


def moves(dx, dy):
    """Key presses that move the cursor by (dx, dy): 8-cell jumps then single steps."""
    k = []
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
    CMD_TOOL, CMD_NEW_CITY, CMD_PAUSE = 0x81, 0x90, 0x91
    CMD_FAST, CMD_NORMAL, CMD_SLOW = 0x92, 0x93, 0x94
    CMD_COAL, CMD_NUCLEAR, CMD_DIS_ON, CMD_DIS_OFF, CMD_BULL_ON, CMD_BULL_OFF = 0x95, 0x96, 0x97, 0x98, 0x99, 0x9A
    CMD_QUIT, CMD_REDRAW = 0x9B, 0x9C
    CMD_MAP, CMD_MAP_OFF = 0x9D, 0xA3
    byte = lambda mem, name: mem[syms[name]]

    mem = run(binary, syms, [LEVEL_MEDIUM, CMD_TOOL + 5, 0, 0])
    check('command: tool 5 chooses residential', any('RESIDENTIAL' in row for row in screen(mem, syms)))
    mem = run(binary, syms, [LEVEL_MEDIUM, CMD_TOOL + 13, 0, 0])
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
    mem = run(binary, syms, [LEVEL_MEDIUM, CMD_NEW_CITY, ord('3'), CMD_TOOL + 2, 0, 0])
    check('command: new city goes back to the title and starts a harder city',
          byte(mem, '_V_difficulty') == 2 and byte(mem, '_test_done') == 1, f'difficulty {byte(mem, "_V_difficulty")}')
    check('command: the new city is drawn (tool shown, map present)',
          any('POWER LINES' in row for row in screen(mem, syms)) and any('~' in row for row in screen(mem, syms)[8:]))
    mem = run(binary, syms, [LEVEL_MEDIUM, CMD_REDRAW, 0, 0])
    check('command: redraw draws the status panel again', any('FUNDS $10000' in row for row in screen(mem, syms)))

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
    check('text window: the status is in the text window', any('FUNDS $10000' in r for r in text) and any('ROAD $10' in r for r in text),
          '\n'.join(text))
    check('text window: no key tips; rows 3, 4 (the icons), 5 and 7 are left empty',
          not any('MOVE' in r or 'PICK' in r or 'QUIT' in r for r in text) and not any(text[i].strip() for i in (3, 4, 5, 7)), '\n'.join(text))
    check('text window: the icons are drawn with the tool in use highlighted (the road, tool 1, to start with)',
          mem[psyms['_test_icons_selected']] == 1 and mem[psyms['_test_icons_calls']] > 0)
    check('text window: the map is only the map (no text on it)',
          not any(w in r for r in mapp for w in ('FUNDS', 'POP', 'ROAD', 'MOVE', 'JAN', 'MORE')), '\n'.join(mapp))
    check('text window: the map fills all 8 rows of the console', all(r.strip() for r in mapp), '\n'.join(mapp))
    mem = run(pbin, psyms, [LEVEL_MEDIUM, CMD_TOOL + 5, 0, 0])
    check('text window: choosing a tool moves the icon highlight to it', mem[psyms['_test_icons_selected']] == 5)
    mem = run(pbin, psyms, [LEVEL_MEDIUM, ord('9'), 0, 0])
    check('text window: so does a digit key', mem[psyms['_test_icons_selected']] == 9)
    mem = run(pbin, psyms, [LEVEL_MEDIUM, CMD_TOOL + 5, 0, 0])
    check('text window: a menu command updates the text window', any('RESIDENTIAL' in r for r in panes(mem)[1]))
    mem = run(pbin, psyms, [LEVEL_MEDIUM, CMD_NEW_CITY, ord('3'), 0, 0])
    mapp, text = panes(mem)
    check('text window: a new city goes through the title and back (hard level, status and map drawn)',
          mem[psyms['_V_difficulty']] == 2 and any('FUNDS' in r for r in text) and all(r.strip() for r in mapp),
          '\n'.join(text))

    # --- 6. the mini maps (on the 32x8 platform, which can draw bitmaps) ---
    def bitmaps(mem):
        """The 192x64 picture the game drew: the 24x8 cells at console column 4, as rows of 0/1."""
        base = psyms['_test_bitmap']
        rows = []
        for py in range(64):
            row = []
            for cx in range(24):
                b = mem[base + ((py // 8) * 32 + 4 + cx) * 8 + py % 8]
                row += [(b >> (7 - i)) & 1 for i in range(8)]
            rows.append(row)
        return rows

    BAYER2 = [0, 2, 3, 1]
    BAYER4 = [0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5]
    flags_at = psyms['_D_tile_flags']

    def reference(mem, view, top):
        """The same picture worked out from the engine's memory, pixel by pixel (a tile is 2x2 pixels)."""
        lm, mm = psyms['_levelmap'], psyms['_minimaps']

        def tile_level(t):
            if t & 0x80: return 4
            if t == 2: return 0
            if t == 6: return 2
            if t <= 5 or t == 68: return 1
            return 3 if t < 56 and mem[flags_at + t] & 0x0E else 4

        level16 = lambda v: min(16, v >> 2)
        out = []
        for py in range(64):
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
        return [(x, y) for y in range(64) for x in range(192) if got[y][x] != want[y][x] and (x, y) not in cursor]

    KEY_M = ord('m')
    for view, name in ((1, 'city'), (2, 'pollution'), (3, 'police'), (4, 'fire'), (5, 'traffic'), (6, 'power')):
        mem = run(pbin, psyms, [LEVEL_MEDIUM, PAUSE] + [KEY_M] * view + [0] * 12)
        got = bitmaps(mem)
        d = differences(got, reference(mem, view, 64))
        check(f'mini map {view}: {name} is drawn as the engine data says', not d, f'{len(d)} pixels differ, first {d[:4]}')
        if view > 1:        # the harness fills the coverage maps with a pattern, so something must show
            lit = sum(map(sum, got))
            check(f'mini map {view}: {name} has lit and dark pixels', 300 < lit < 192 * 64 - 300, f'{lit} of 12288 lit')
        _, text = panes(mem)
        check(f'mini map {view}: the text window names it', any(minimap_name in r for r in text for minimap_name in [name.upper()]),
              '\n'.join(text))
    mem = run(pbin, psyms, [LEVEL_MEDIUM, PAUSE, KEY_M] + [0] * 12)
    lit = sum(map(sum, bitmaps(mem)))
    check('mini map: the city view shows the water', 100 < lit < 192 * 64 - 100, f'{lit} of 12288 pixels lit')
    # the cursor in the top half: the picture shows the top of the city, and the cursor's pixel is in it
    for view in (1, 3):
        mem = run(pbin, psyms, [LEVEL_MEDIUM, PAUSE] + [ord('Q')] * 5 + [KEY_M] * view + [0] * 12)
        d = differences(bitmaps(mem), reference(mem, view, 0), 0, 8)
        check(f'mini map {view}: with the cursor in the top half the top of the city is shown', not d, f'{len(d)} pixels differ, first {d[:4]}')

    mem = run(pbin, psyms, [LEVEL_MEDIUM, PAUSE, KEY_M, 27, 0, 0])
    mapp, text = panes(mem)
    check('mini map: escape goes back to the city instead of quitting', mem[psyms['_test_done']] == 1 and any('~' in r for r in mapp)
          and not any('MAP:' in r for r in text), '\n'.join(mapp))
    mem = run(pbin, psyms, [LEVEL_MEDIUM, PAUSE, ord('x')] + [0] * 20)
    check('a platform with menus: x does not quit (quit is in the menu)', mem[psyms['_test_frames']] >= 20, f"{mem[psyms['_test_frames']]} frames")
    mem = run(pbin, psyms, [LEVEL_MEDIUM, PAUSE, 27] + [0] * 20)
    check('a platform with menus: escape does not quit either', mem[psyms['_test_frames']] >= 20, f"{mem[psyms['_test_frames']]} frames")
    mem = run(pbin, psyms, [LEVEL_MEDIUM, ord('+')] + [0] * 250)
    text = panes(mem)[1]
    check('the advisor message is on row 6 (below the icons), where the Z88 shows it', text[6].strip() and not text[3].strip(), '\n'.join(text))
    mem = run(pbin, psyms, [LEVEL_MEDIUM, PAUSE] + [KEY_M] * 7 + [0, 0])
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

    # --- 7. the budget screen (the 32x8 platform has it too) ---
    CMD_BUDGET = 0xA4
    byte_p = lambda mem, name: mem[psyms[name]]
    mem = run(pbin, psyms, [LEVEL_MEDIUM, PAUSE, CMD_BUDGET, 0, 0])
    text = panes(mem)[1]
    check('budget: the screen shows the headings and the departments',
          all(any(w in r for r in text) for w in ('FISCAL BUDGET', 'TAX RATE', 'TRANSPORT', 'POLICE', 'FIRE', 'CASH FLOW', 'ENTER OK')),
          '\n'.join(text))
    check('budget: it starts with the tax rate of 7%', any('TAX RATE  7%' in r for r in text), '\n'.join(text))
    check('budget: every line fits the 8 rows and 40 columns', all(len(r.rstrip()) <= 40 for r in text))
    mem = run(pbin, psyms, [LEVEL_MEDIUM, PAUSE, CMD_BUDGET, ord('p'), ord('p'), 0, 0])
    check('budget: p raises the tax rate and the screen shows it',
          byte_p(mem, '_SMC_tax_rate') == 9 and any('TAX RATE  9%' in r for r in panes(mem)[1]))
    mem = run(pbin, psyms, [LEVEL_MEDIUM, PAUSE, CMD_BUDGET] + [ord('o')] * 9 + [0, 0])
    check('budget: the tax rate stops at 0', byte_p(mem, '_SMC_tax_rate') == 0)
    mem = run(pbin, psyms, [LEVEL_MEDIUM, PAUSE, CMD_BUDGET] + [ord('p')] * 20 + [0, 0])
    check('budget: the tax rate stops at 20', byte_p(mem, '_SMC_tax_rate') == 20)
    mem = run(pbin, psyms, [LEVEL_MEDIUM, PAUSE, CMD_BUDGET, ord('a'), ord('o'), ord('a'), ord('o'), ord('o'), ord('a'), ord('o'), ord('o'), ord('o'), 0, 0])
    check('budget: a selects the next item and o lowers its funding by 10% (transport 90, police 80, fire 70)',
          (byte_p(mem, '_SMC_transport_percent'), byte_p(mem, '_SMC_police_percent'), byte_p(mem, '_SMC_fire_percent')) == (90, 80, 70))
    mem = run(pbin, psyms, [LEVEL_MEDIUM, PAUSE, CMD_BUDGET, ord('p'), 13, 0, 0])
    text = panes(mem)[1]
    check('budget: enter accepts it and the game goes on (status panel back, new rate kept)',
          any('FUNDS' in r for r in text) and not any('FISCAL' in r for r in text) and byte_p(mem, '_SMC_tax_rate') == 8, '\n'.join(text))
    check('budget: the game asks the player for the annual budget', byte_p(mem, '_V_auto_budget') == 0)
    # the engine's own request, in November: fast, until the year's tick; then the player changes the tax rate and accepts
    mem = run(pbin, psyms, [LEVEL_MEDIUM, ord('+')] + [0] * 1500 + [ord('p'), ord('p'), 0, 0])
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

    # --- 9. the moving sprites, drawn over the map's pictures ---
    subprocess.run(['make', '-s', '-C', ROOT, 'build/testsprites/simcity.bin'], check=True, capture_output=True)
    ssyms = {}
    for line in open(os.path.join(ROOT, 'build', 'testsprites', 'simcity.map')):
        m = re.match(r'(\S+)\s*=\s*\$([0-9A-Fa-f]+)', line)
        if m:
            ssyms[m.group(1)] = int(m.group(2), 16)
    sbin = open(os.path.join(ROOT, 'build', 'testsprites', 'simcity.bin'), 'rb').read()
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
    check('sprites: the train and the plane are drawn over the tiles, 2x2 cells each', not wrong, str(wrong[:3]))
    check('sprites: they changed the pictures of those cells (not all: water is solid already)', sum(with_s[k] != without[k] for k in want) >= 4)
    other = [k for k in with_s if k not in want and k != (16, 4) and with_s[k] != without[k]]
    check('sprites: no other cell is touched', not other, str(other[:5]))
    mem = run(sbin, ssyms, [LEVEL_MEDIUM, PAUSE] + [0] * 20 + [ord('p')] * 40 + [0] * 10)
    moved = cells(mem)
    # the view scrolled right once the cursor passed its edge: the sprite must have moved on the screen with the map
    check('sprites: they scroll with the map (the cells where they were no longer hold them)',
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
    go = moves(spot[0] - 48, spot[1] - 48)
    money0 = mem[psyms['_V_money']] | mem[psyms['_V_money'] + 1] << 8
    # save, build a road there (costs $10), and see it built; then do the same and load the city back
    keys = [LEVEL_MEDIUM, PAUSE] + go + [CMD_SAVE, ord('a'), ord('b'), 13, ord(' '), ord(' ')]
    built = run(pbin, psyms, keys)
    check('(the road is built at the dirt spot if we do not load: so the next test can tell)', built[at] == 7 and built[at] != lm[spot[1] * 96 + spot[0]])
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
