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
    subprocess.run([os.path.join(ROOT, 'tools', 'build.sh'), 'test'], check=True, capture_output=True)
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

    print()
    print('\n'.join(scr))
    print()
    print('FAILED: ' + ', '.join(failures) if failures else 'all UI tests passed')
    sys.exit(1 if failures else 0)


if __name__ == '__main__':
    main()
