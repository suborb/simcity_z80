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
Z88DK = os.environ.get('Z88DK', os.path.expanduser('~/z88dk'))
TICKS = os.path.join(Z88DK, 'bin', 'z88dk-ticks')
OUT = os.path.join(ROOT, 'build', 'test')
ROWS, COLS = 24, 64
MAP_W = 96
SCRIPT_LEN = 512
END = 0xFF


def build():
    subprocess.run(['make', '-s', '-C', ROOT, 'build/test/simcity.bin'], check=True, capture_output=True)
    syms = {}
    for line in open(os.path.join(OUT, 'simcity.map')):
        m = re.match(r'(\S+)\s*=\s*\$([0-9A-Fa-f]+)', line)
        if m:
            syms[m.group(1)] = int(m.group(2), 16)
    return open(os.path.join(OUT, 'simcity.bin'), 'rb').read(), syms


def run(binary, syms, keys, limit=4_000_000_000):
    """Run the game with the given key script; return (memory dump, symbols)."""
    assert len(keys) < SCRIPT_LEN
    image = bytearray(binary)
    script = bytes(keys) + bytes([END]) + bytes(SCRIPT_LEN - len(keys) - 1)
    a = syms['_test_script']
    image[a:a + SCRIPT_LEN] = script
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
    check('text window: all three help lines fit', sum(1 for r in text if 'MOVE' in r or 'PICK' in r or 'QUIT' in r) == 3, '\n'.join(text))
    check('text window: the map is only the map (no text on it)',
          not any(w in r for r in mapp for w in ('FUNDS', 'POP', 'ROAD', 'MOVE', 'JAN', 'MORE')), '\n'.join(mapp))
    check('text window: the map fills all 8 rows of the console', all(r.strip() for r in mapp), '\n'.join(mapp))
    mem = run(pbin, psyms, [LEVEL_MEDIUM, CMD_TOOL + 5, 0, 0])
    check('text window: a menu command updates the text window', any('RESIDENTIAL' in r for r in panes(mem)[1]))
    mem = run(pbin, psyms, [LEVEL_MEDIUM, CMD_NEW_CITY, ord('3'), 0, 0])
    mapp, text = panes(mem)
    check('text window: a new city goes through the title and back (hard level, status and map drawn)',
          mem[psyms['_V_difficulty']] == 2 and any('FUNDS' in r for r in text) and all(r.strip() for r in mapp),
          '\n'.join(text))

    print()
    print('\n'.join(scr))
    print()
    print('FAILED: ' + ', '.join(failures) if failures else 'all UI tests passed')
    sys.exit(1 if failures else 0)


if __name__ == '__main__':
    main()
