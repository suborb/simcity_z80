#!/usr/bin/env python3
"""A converted scenario city (the Next's build/zxn/scenarios, make zxn first) in the engine under z88dk-ticks: the headless test platform at 120x100 with the Next's
engine flags, the scenario's map and power map poked in, optional power lines placed with the engine's own tool_apply, then some ticks.  Reports whether the run
finished, whether the engine's code or tables changed, and where the program counter was if it did not finish.  No emulator.

    python3 test/zxn/scenario_sim.py [--scenario N] [--ticks N] [--lines K] [--coarse]       (N is the picker's place: 0 Bern .. 4 Hamburg .. 7 Tokyo)"""
import argparse
import os
import re
import subprocess
import sys
import tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
W, H = 120, 100
MM25, MM50 = (W // 4) * (H // 4), (W // 2) * (H // 2)
MM_POWER = 2 * MM25 + 2 * MM50
RECORD = 12000 + 12000 + 15 * 100 + 60 * 50 + 1024
SETTINGS = {'V_auto_bulldoze': 1, 'V_difficulty': 0, 'SMC_tax_rate': 7, 'SMC_transport_percent': 100, 'SMC_police_percent': 100,
            'SMC_fire_percent': 100, 'V_simulation_speed': 1, 'V_auto_budget': 1, 'V_disaster_reset': 1}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--scenario', type=int, default=4)
    ap.add_argument('--ticks', type=int, default=8)
    ap.add_argument('--lines', type=int, default=0, help='power lines to place (tool 2) on dirt, spread over the map, before the ticks')
    ap.add_argument('--dir', default=os.path.join(ROOT, 'build', 'zxn', 'scenarios'), help='the converted scenarios')
    ap.add_argument('--trace', type=int, default=0, help='run again with the instructions traced to this many cycles, and show the last ones (where a run that does not finish is)')
    ap.add_argument('--coarse', action='store_true', help='without FINE_ZONE_LEVELS (and the scenario converted for it: make zxn ZXN_FINE=0 first)')
    a = ap.parse_args()
    d = a.dir
    banks = sorted(f for f in os.listdir(d) if f.startswith('scenarios_') and f.endswith('.bin'))
    records = b''.join(open(os.path.join(d, f), 'rb').read() for f in banks)
    rec = records[a.scenario * RECORD:(a.scenario + 1) * RECORD]
    cells, power = rec[:12000], rec[24000:24000 + 1500]
    with tempfile.TemporaryDirectory() as tmp:
        subprocess.run(['cp', '-R'] + [os.path.join(ROOT, x) for x in ('engine', 'platform', 'target', 'test', 'assets')] + [tmp], check=True)
        flags = ['-DPORTABLE', f'-DMAP_W={W}', f'-DMAP_H={H}', '-DPOWER_SHOWN', '-DHAVE_SCENARIOS']
        if not a.coarse:
            flags.append('-DFINE_ZONE_LEVELS')
        r = subprocess.run(['z88dk-z80asm', '-Iengine'] + flags + ['-b', '-m', 'target/test/test_platform.asm'], cwd=tmp, capture_output=True, text=True)
        if r.returncode:
            print('FAIL  assembling\n' + r.stdout + r.stderr)
            return 1
        syms = {m.group(1): int(m.group(2), 16) for m in re.finditer(r'^(\S+)\s*=\s*\$([0-9A-Fa-f]+)', open(f'{tmp}/target/test/test_platform.map').read(), re.M)}
        binary = open(f'{tmp}/target/test/test_platform.bin', 'rb').read()
        img = bytearray(65536)
        img[0x100:0x100 + len(binary)] = binary
        for k, v in SETTINGS.items():
            img[syms[k]] = v
        img[syms['levelmap']:syms['levelmap'] + 12000] = cells
        img[syms['minimaps'] + MM_POWER:syms['minimaps'] + MM_POWER + 1500] = power
        img[syms['test_ticks']] = a.ticks & 255
        img[syms['test_ticks'] + 1] = a.ticks >> 8
        acts = bytearray()
        placed = 0
        step = 7
        for y in range(2, H - 2, step):
            for x in range(2, W - 2, 13):
                if placed < a.lines and cells[y * W + x] == 2:
                    acts += bytes([2, x, y])
                    placed += 1
        acts += b'\xff'
        img[syms['test_actions']:syms['test_actions'] + len(acts)] = acts
        code_end = syms.get('__data_user_head', 0) or 0
        before = bytes(img)
        open(f'{tmp}/image.bin', 'wb').write(img)
        run = subprocess.run(['z88dk-ticks', '-pc', '100', '-end', f'{syms["test_done"]:x}', '-counter', '6000000000', '-output', f'{tmp}/mem.bin', f'{tmp}/image.bin'],
                             capture_output=True, text=True)
        mem = open(f'{tmp}/mem.bin', 'rb').read()
        if a.trace:
            import collections
            p = subprocess.Popen(['z88dk-ticks', '-trace', '-pc', '100', '-end', f'{syms["test_done"]:x}', '-counter', str(a.trace), f'{tmp}/image.bin'],
                                 stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, errors='replace')
            last = collections.deque(maxlen=600)
            for line in p.stdout:                   # (stop at the first halt: the program has run into something that is not code)
                if ('[pc]=00,' in line) or (';[' in line and ' nop ' in line):
                    continue                        # (a run through zeroed memory: not the way in)
                last.append(line)
                if 'halt' in line and 'pc=' not in line:
                    break
            p.kill()
            lines = ''.join(last).splitlines()
            print('\n'.join(l for l in lines if l.lstrip().startswith(('pc=', 'halt')) or ';[' in l)[-9000:])
            by_addr = sorted((v, k) for k, v in syms.items())
            import bisect
            for pc in (0x4F11, 0x1725):
                i = bisect.bisect_right([v for v, _ in by_addr], pc) - 1
                print(f'{pc:04x} is after {by_addr[i][1]} (+{pc - by_addr[i][0]})')
    finished = 'counter limit' not in run.stdout + run.stderr
    changed = [i for i in range(0x100, 0x100 + len(binary)) if before[i] != mem[i] and i < syms.get('test_ticks', 0)]
    print(('PASS' if finished and not changed else 'FAIL') + f'  {"coarse" if a.coarse else "fine"} scenario {a.scenario}, {placed} power lines, {a.ticks} ticks: '
          + ('finished' if finished else 'did not finish (the engine is running somewhere it should not)') + f', {len(changed)} bytes of code or tables changed')
    return 0 if finished and not changed else 1


if __name__ == '__main__':
    sys.exit(main())
