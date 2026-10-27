#!/usr/bin/env python3
"""The simulation on a bigger map: the engine in the headless test platform at 96x96 and at the other sizes, the same town (a coal plant, a power line, a road and
a row of zones, placed from the engine's own zone tables in the top left corner), 60 ticks under z88dk-ticks, for a few seeds of the random numbers.  The
simulation does not draw a random number for an empty cell, so a town in the corner must come out the same on any size of map: the same levelmap in the
cells the 96x96 has, the same minimaps (cell for cell), the same variables.  That makes this a check of the whole engine, not only its address arithmetic
(it found write_print_entry's stride: 94 is MAP_W - 2).  test/golden is the comparison with the original, for 96x96.  Also: the town grows, nothing
the engine writes lands in its code or tables.

    python3 test/mapsize/smoke.py [WxH ...]"""
import os
import re
import subprocess
import sys
import tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
TICKS = 60
SEEDS = (3, 5)
ZONES = {'coal': ('default_coal_power_station_tile', 4, 4), 'res': ('default_residential_tiles', 3, 3),
         'com': ('default_commercial_tiles', 3, 3), 'ind': ('default_industrial_tiles', 3, 3)}
DIRT, ROAD, POWER = 2, 7, 33
SETTINGS = {'V_auto_bulldoze': 1, 'V_difficulty': 0, 'SMC_tax_rate': 7, 'SMC_transport_percent': 100, 'SMC_police_percent': 100,
            'SMC_fire_percent': 100, 'V_simulation_speed': 1, 'V_auto_budget': 1, 'V_disaster_reset': 1}


def simulate(w, h, ticks=TICKS, seed=None, patch=None):
    """The town after `ticks` ticks on a w x h map: (memory, symbols, memory before) or None."""
    with tempfile.TemporaryDirectory() as tmp:
        subprocess.run(['cp', '-R'] + [os.path.join(ROOT, d) for d in ('engine', 'platform', 'target', 'test', 'assets')] + [tmp], check=True)
        if patch:
            patch(tmp)
        r = subprocess.run(['z88dk-z80asm', '-Iengine', '-DPORTABLE', f'-DMAP_W={w}', f'-DMAP_H={h}', '-b', '-m', 'target/test/test_platform.asm'],
                           cwd=tmp, capture_output=True, text=True)
        if r.returncode:
            print(f'FAIL  {w}x{h}: assembling\n{r.stdout}{r.stderr}')
            return None
        syms = {m.group(1): int(m.group(2), 16) for m in re.finditer(r'^(\S+)\s*=\s*\$([0-9A-Fa-f]+)', open(f'{tmp}/target/test/test_platform.map').read(), re.M)}
        binary = open(f'{tmp}/target/test/test_platform.bin', 'rb').read()
        img = bytearray(65536)
        img[0x100:0x100 + len(binary)] = binary
        for k, v in SETTINGS.items():
            img[syms[k]] = v
        cells = bytearray([DIRT]) * (w * h)

        def zone(name, x, y):
            sym, zw, zh = ZONES[name]
            t = img[syms[sym]:syms[sym] + zw * zh]
            for r_ in range(zh):
                for c in range(zw):
                    cells[(y + r_) * w + x + c] = t[r_ * zw + c]
        zone('coal', 10, 10)
        for x in range(10, 60):
            cells[14 * w + x] = POWER
        for i, n in enumerate(['res', 'res', 'res', 'res', 'com', 'com', 'ind', 'ind', 'res', 'com']):
            zone(n, 12 + 4 * i, 15)
        for x in range(10, 60):
            cells[18 * w + x] = ROAD
        img[syms['levelmap']:syms['levelmap'] + len(cells)] = cells
        img[syms['test_ticks']] = ticks
        if seed is not None:
            img[syms['V_random_seed']] = seed & 255
            img[syms['V_random_seed'] + 1] = seed >> 8
        before = bytes(img)
        path, out = f'{tmp}/image.bin', f'{tmp}/mem.bin'
        open(path, 'wb').write(img)
        subprocess.run(['z88dk-ticks', '-pc', '100', '-end', f'{syms["test_done"]:x}', '-counter', '4000000000', '-output', out, path], capture_output=True)
        mem = open(out, 'rb').read()
    return mem, syms, before


def maps(mem, syms, w, h):
    """The four minimaps and the power map as {name: {(x, y): value}}."""
    mm = syms['minimaps']
    m25, m50 = (w // 4) * (h // 4), (w // 2) * (h // 2)
    out = {}
    for name, o, cw, ch in (('fire', 0, w // 4, h // 4), ('police', m25, w // 4, h // 4), ('pollution', 2 * m25, w // 2, h // 2),
                            ('traffic', 2 * m25 + m50, w // 2, h // 2)):
        out[name] = {(x, y): mem[mm + o + y * cw + x] for y in range(ch) for x in range(cw)}
    pw = mm + 2 * m25 + 2 * m50
    out['power'] = {(x, y): (mem[pw + y * (w // 8) + (x >> 3)] >> (7 - (x & 7))) & 1 for y in range(h) for x in range(w)}
    return out


# what holds addresses of the map or the minimaps (which move with its size), or the coordinates of the last cell visited
ADDRESSES = {'V_map_iter_addr', 'V_map_iter_xy', 'V_minimap_start', 'V_powerstation_list', 'V_ric_tile_current', 'V_t_1zone_cost_on_water',
             'V_CChr', 'V_zone_unpow_tile', 'V_powersp', 'V_power_bfs_pos', 'V_zone_best_coords', 'V_cursor_map_coords', 'V_CrashXY', 'V_powerqueue',
             # the power search's scratch: the bigger maps share one capacity across the city (POWER_CITYWIDE), the 96x96 does it a station at a time
             'V_power_bfs_down', 'V_power_bfs_up', 'V_power_units_left'}


def compare(small, big):
    """What differs between the town on the small map and on the big one, over what they have in common: a list of words."""
    (ma, sa, wa, ha), (mb, sb, wb, hb) = small, big
    problems = []
    cells = sum(1 for y in range(ha) for x in range(wa) if ma[sa['levelmap'] + y * wa + x] != mb[sb['levelmap'] + y * wb + x])
    if cells:
        problems.append(f'{cells} map cells')
    a, b = maps(ma, sa, wa, ha), maps(mb, sb, wb, hb)
    for k in a:
        n = sum(1 for p in a[k] if p in b[k] and a[k][p] != b[k][p])
        if n:
            problems.append(f'{n} cells of the {k} map')
    names = [n for n in sa if n.startswith('V_') and n in sb and n not in ADDRESSES]

    def extent(syms, n):
        # The variable's bytes: up to the next symbol, 4 at most.  (What follows it may be bigger on the bigger map, or an address: not this variable.)
        nxt = min((v for v in syms.values() if v > syms[n]), default=syms[n] + 4)
        return min(4, nxt - syms[n])
    var = []
    for n in names:
        if n == 'V_pollution_sum':
            # The 120x100 build extends this accumulator to 24 bits; compare
            # the numeric value, not the following variables at different offsets.
            def pollution_sum(mem, syms):
                lo = int.from_bytes(mem[syms[n]:syms[n] + 2], 'little')
                hi = mem[syms['V_pollution_sum_high']] if 'V_pollution_sum_high' in syms else 0
                return lo | (hi << 16)
            different = pollution_sum(ma, sa) != pollution_sum(mb, sb)
        else:
            different = ma[sa[n]:sa[n] + extent(sa, n)] != mb[sb[n]:sb[n] + extent(sb, n)]
        if different:
            var.append(n)
    if var:
        problems.append('variables ' + ', '.join(var[:6]))
    return problems


def main():
    sizes = [tuple(int(v) for v in a.split('x')) for a in sys.argv[1:]] or [(96, 96), (120, 100)]
    ok = True
    for seed in SEEDS:
        runs = []
        for w, h in sizes:
            res = simulate(w, h, TICKS, seed)
            if res is None:
                return 1
            mem, syms, before = res
            ram = syms['__data_user_head']
            changed = sum(1 for i in range(ram) if mem[i] != before[i])
            pop = int.from_bytes(mem[syms['V_CityPop']:syms['V_CityPop'] + 3], 'little')
            good = pop > 500 and mem[syms['V_month']] == 6 and not changed
            ok = ok and good
            runs.append((mem, syms, w, h))
            line = f'seed {seed}  {w}x{h}: {TICKS} ticks, population {pop}, {changed} bytes of code or tables changed'
            if len(runs) > 1:
                problems = compare(runs[0], runs[-1])
                good = good and not problems
                ok = ok and not problems
                line += ', differs from %dx%d in: %s' % (sizes[0] + (', '.join(problems),)) if problems else f', the same as {sizes[0][0]}x{sizes[0][1]}'
            print(('PASS' if good else 'FAIL') + '  ' + line)
    return 0 if ok else 1


if __name__ == '__main__':
    sys.exit(main())
