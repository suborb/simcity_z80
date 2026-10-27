#!/usr/bin/env python3
"""Golden-master test: the portable engine must behave exactly like the original.

Both versions are built from the repository in a scratch directory:

  reference  disassembly/sim_game.asm          the original Spectrum program, untouched
  portable   target/test/test_platform.asm    the engine + headless test platform

The same city is loaded into each, the same number of simulation ticks is run
under z88dk-ticks, and the levelmap, all minimaps and every engine variable are
compared.  Any difference is a bug in the extraction.

  usage: test/golden/run.py [--ticks N] [--scenario NAME ...] [--keep]

Needs z88dk on the PATH: z88dk-z80asm and z88dk-ticks.
"""
import argparse
import os
import re
import shutil
import subprocess
import sys
import tempfile

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
Z80ASM = 'z88dk-z80asm'
TICKS = 'z88dk-ticks'

ZX_ORG = 23323
MAP_W = 96

# Settings both builds are forced to (normally owned by the UI).
SETTINGS = {
    'V_auto_bulldoze': 1,
    'V_demolish_wait': 0,       # Spectrum only: no pause before demolishing
    'V_difficulty': 0,
    'SMC_tax_rate': 7,
    'SMC_transport_percent': 100,
    'SMC_police_percent': 100,
    'SMC_fire_percent': 100,
    'V_simulation_speed': 1,
    'V_auto_budget': 1,
    'V_disaster_reset': 1,
}


def run(cmd, cwd=None):
    r = subprocess.run(cmd, cwd=cwd, capture_output=True, text=True)
    if r.returncode != 0:
        sys.exit(f'command failed: {" ".join(cmd)}\n{r.stdout}{r.stderr}')
    return r.stdout


def parse_map(path):
    syms = {}
    for line in open(path):
        m = re.match(r'(\S+)\s*=\s*\$([0-9A-Fa-f]+)', line)
        if m:
            syms[m.group(1)] = int(m.group(2), 16)
    return syms


def build(tmp):
    """Build the reference and portable images in tmp; return their paths."""
    for d in ('assets', 'engine', 'platform', 'target', 'disassembly'):
        junk = None if d == 'assets' else shutil.ignore_patterns('*.bin', '*.o', '*.map', '*.sym')
        shutil.copytree(os.path.join(ROOT, d), os.path.join(tmp, d), ignore=junk)
    run([Z80ASM, '-b', '-m', 'disassembly/sim_game.asm'], cwd=tmp)
    run([Z80ASM, '-b', '-m', 'target/zx-original/zx_game.asm'], cwd=tmp)
    run([Z80ASM, '-Iengine', '-DPORTABLE', '-DSIM_STACK_FILL', '-b', '-m', 'target/test/test_platform.asm'], cwd=tmp)
    ref = ('disassembly/sim_game.bin', 'disassembly/sim_game.map')
    po = ('target/test/test_platform.bin', 'target/test/test_platform.map')
    a = open(os.path.join(tmp, 'disassembly/sim_game.bin'), 'rb').read()
    b = open(os.path.join(tmp, 'target/zx-original/zx_game.bin'), 'rb').read()
    if a != b:
        sys.exit('FAIL  the split Spectrum build (target/zx-original) differs from the original disassembly')
    print('PASS  target/zx-original/zx_game.asm assembles to exactly the original binary '
          f'({len(a)} bytes)')
    return [os.path.join(tmp, p) for p in ref + po]


# ---------------------------------------------------------------------------
# Scenarios: a 96x96 levelmap built from the game's own zone tile tables
# ---------------------------------------------------------------------------
ZONES = {   # table symbol, width, height
    'res': ('default_residential_tiles', 3, 3),
    'com': ('default_commercial_tiles', 3, 3),
    'ind': ('default_industrial_tiles', 3, 3),
    'police': ('default_police_tiles', 3, 3),
    'fire': ('default_fire_tiles', 3, 3),
    'stadium': ('default_stadium_tiles', 4, 4),
    'coal': ('default_coal_power_station_tile', 4, 4),
    'nuclear': ('default_nuclear_power_station_tiles', 4, 4),
    'port': ('default_seaport_tiles', 4, 4),
    'airport': ('default_airport_tiles', 6, 6),
}
TILE_WATER, TILE_DIRT, TILE_H_ROAD, TILE_V_ROAD, TILE_H_POWER = 0, 2, 7, 8, 33


class City:
    def __init__(self, zx_bin, zx_syms):
        self.zx_bin, self.syms = zx_bin, zx_syms
        self.cells = bytearray([TILE_DIRT]) * (MAP_W * MAP_W)
        self.minimap_patches = []       # (offset from minimaps, value)

    def tiles(self, name):
        sym, w, h = ZONES[name]
        a = self.syms[sym] - ZX_ORG
        return self.zx_bin[a:a + w * h], w, h

    def put(self, x, y, tile):
        self.cells[y * MAP_W + x] = tile

    def zone(self, name, x, y):
        t, w, h = self.tiles(name)
        for r in range(h):
            for c in range(w):
                self.put(x + c, y + r, t[r * w + c])

    def hline(self, x0, x1, y, tile):
        for x in range(x0, x1 + 1):
            self.put(x, y, tile)

    def vline(self, x, y0, y1, tile):
        for y in range(y0, y1 + 1):
            self.put(x, y, tile)

    def lake(self, x0, y0, x1, y1):
        for y in range(y0, y1 + 1):
            for x in range(x0, x1 + 1):
                self.put(x, y, TILE_WATER)


def scenario_town(c):
    """Coal plant, power line, a row of R/C/I zones on a road, services."""
    c.lake(0, 0, 95, 2)
    c.zone('coal', 10, 10)
    c.hline(10, 60, 14, TILE_H_POWER)
    for i, name in enumerate(['res', 'res', 'res', 'res', 'com', 'com', 'ind', 'ind', 'res', 'com']):
        c.zone(name, 12 + 4 * i, 15)
    c.hline(10, 60, 18, TILE_H_ROAD)
    c.zone('police', 12, 20)
    c.zone('fire', 16, 20)
    c.zone('res', 20, 20)
    c.zone('res', 24, 20)
    c.zone('ind', 28, 20)


def scenario_unpowered(c):
    """Zones with a road but no power: exercises the unpowered paths."""
    c.zone('res', 20, 20)
    c.zone('com', 24, 20)
    c.zone('ind', 28, 20)
    c.hline(18, 34, 24, TILE_H_ROAD)
    c.zone('stadium', 40, 20)
    c.zone('port', 50, 5)   # next to the lake
    c.lake(40, 3, 70, 8)


def scenario_big(c):
    """Nuclear plant, airport, port and a larger grid of zones."""
    c.lake(0, 0, 95, 4)
    c.zone('nuclear', 6, 10)
    c.hline(6, 80, 14, TILE_H_POWER)
    c.vline(30, 14, 50, TILE_V_ROAD)
    for row in range(4):
        for i in range(8):
            c.zone(['res', 'com', 'ind', 'res'][(i + row) % 4], 8 + 5 * i, 15 + 6 * row)
        c.hline(6, 56, 18 + 6 * row, TILE_H_ROAD)
    c.zone('airport', 60, 30)
    c.zone('police', 50, 40)
    c.zone('fire', 54, 40)


# Tool use replayed through the original place_tool_at_cursor and the portable
# tool_apply.  Each action is (tool, x, y); tools: 0 bulldoze, 1 road, 2 power line,
# 3 rail, 4 park, 5 res, 6 com, 7 ind, 8 police, 9 fire, 10 stadium, 11 power plant,
# 12 seaport, 13 airport.
def actions_tools():
    a = []
    for x in range(10, 31):
        a.append((1, x, 30))                 # road row
    for y in range(30, 41):
        a.append((1, 20, y))                 # crossing road column
    for x in range(10, 41):
        a.append((2, x, 32))                 # power line, crosses the road at x = 20
    for x in range(10, 31):
        a.append((3, x, 34))                 # rail, crosses the road column
    a += [(4, 45, 30), (4, 46, 30), (4, 47, 31)]          # parks
    a += [(5, 30, 38), (6, 34, 38), (7, 38, 38)]           # zones
    a += [(8, 42, 38), (9, 46, 38), (10, 50, 38)]          # police, fire, stadium
    a += [(13, 60, 30)]                                    # airport
    a += [(5, 30, 38), (5, 31, 39), (6, 0, 0)]             # on top of zones / on water
    a += [(0, 31, 39), (0, 20, 35), (0, 12, 30), (0, 5, 5), (0, 0, 0)]   # bulldoze
    a += [(1, 5, 5), (2, 0, 0), (3, 31, 20)]               # more odd spots
    return a


def scenario_brownout(c):
    """A coal plant (450 units) on a power grid of about 800 tiles: the search runs out of power part way, so the cells it reaches first are powered and the
    rest are not (and zones on both sides): the plant's budget and the abort when it is spent are what is compared with the original."""
    c.lake(0, 0, 95, 2)
    c.zone('coal', 6, 6)
    c.vline(8, 10, 70, TILE_H_POWER)                 # a spine down from the plant
    for y in range(12, 70, 6):
        c.hline(9, 70, y, TILE_H_POWER)             # ribs off the spine: 10 rows of 62 tiles
    for i, name in enumerate(['res', 'com', 'ind', 'res', 'com', 'res', 'ind', 'res']):
        c.zone(name, 12 + 8 * i, 14 + 6 * (i % 4))   # zones the ribs run past: some reached first, some after the budget is gone
    c.hline(6, 76, 78, TILE_H_ROAD)


def scenario_traffic(c):
    """Roads with seeded traffic densities, to exercise the busy-road pictures."""
    c.hline(10, 40, 20, TILE_H_ROAD)
    c.vline(25, 10, 30, TILE_V_ROAD)
    c.zone('res', 12, 21)
    c.zone('com', 30, 21)
    # one value per minimap cell (the traffic map is 48x48, a cell covers 2x2 map tiles)
    for i, cx in enumerate(range(5, 21)):
        value = [254, 253, 174, 173, 200, 100][i % 6]       # 220/219/150/149 after one tick's decay
        c.minimap_patches.append((3456 + (20 // 2) * 48 + cx, value))
    for i, cy in enumerate(range(5, 16)):
        value = [254, 253, 174, 173, 160, 40][i % 6]
        c.minimap_patches.append((3456 + cy * 48 + 25 // 2, value))


def scenario_tools(c):
    scenario_town(c)
    c.hline(2, 6, 5, TILE_DIRT)


SCENARIOS = {'town': scenario_town, 'unpowered': scenario_unpowered, 'big': scenario_big, 'brownout': scenario_brownout,
             'tools': scenario_tools, 'traffic': scenario_traffic}
ACTIONS = {'tools': actions_tools}


# ---------------------------------------------------------------------------
# What to compare: the engine's variables, found in the engine sources
# ---------------------------------------------------------------------------
# Variables that hold addresses differ between two builds placed at different
# addresses.  Pointers are compared as offsets from their base symbol; the saved
# stack pointer is not compared at all.
POINTER_VARS = {
    'V_map_iter_addr': 'levelmap',
    'V_powerstation_list': 'levelmap',    # zero-terminated list of levelmap pointers
}
# V_minimap_start is a scratch pointer the Spectrum's map drawing also writes.
SKIP_VARS = {'V_powersp', 'V_minimap_start'}
# Scratch variables the Spectrum's map drawing resets (only relevant when a view is rendered).
VIEW_SCRATCH = {'V_zone_x_offset'}


def words(b):
    return [b[i] | b[i + 1] << 8 for i in range(0, len(b) - 1, 2)]


def normalise(name, data, syms):
    if name not in POINTER_VARS:
        return data
    base = syms[POINTER_VARS[name]]
    return bytes(sum(([(w - base) & 255, ((w - base) >> 8) & 255] if w else [0, 0]
                      for w in words(data)), []))

# The sizes engine/mapsize.inc gives by name (defs POWER_QUEUE_BYTES), for the 96x96 map the original Spectrum program has
# Variables engine/simulation.asm has only for the maps bigger than the original's (inside IF MAP_W != 96)
BIGGER_MAP_ONLY = {'V_pollution_sum_high'}
SIZES = {'POWER_STATION_LIST_BYTES': '32', 'POWER_QUEUE_BYTES': '256', 'MAP_CELLS': '9216', 'MM_BYTES': '6912'}


def engine_vars():
    """(name, size) for every V_ variable defined by an engine segment."""
    out = []
    for fn in sorted(os.listdir(os.path.join(ROOT, 'engine'))):
        if not fn.endswith('.asm') or fn in ('engine.asm', 'engine_api.asm', 'engine_defs.asm', 'engine_all.asm', 'view.asm', 'art.asm'):
            continue
        for line in open(os.path.join(ROOT, 'engine', fn), encoding='latin-1'):
            m = re.match(r'^\.?(V_\w+):?\s+(defb|defw|defs)\s+([^;]*)', line)
            if not m:
                continue
            name, kind, args = m.groups()
            if name in BIGGER_MAP_ONLY:
                continue
            args = args.strip()
            if kind == 'defs':
                size = args.split(',')[0].strip()
                n = int(SIZES.get(size, size), 0)       # (a size by name: engine/mapsize.inc's, for the 96x96 map)
            else:
                n = len([a for a in args.split(',') if a.strip()]) * (2 if kind == 'defw' else 1)
            out.append((name, n))
    return out


# ---------------------------------------------------------------------------
def make_image(binary, org, syms, city, extra=None):
    img = bytearray(65536)
    img[org:org + len(binary)] = binary
    for name, val in SETTINGS.items():
        if name in syms:
            img[syms[name]] = val
    lm = syms['levelmap']
    img[lm:lm + len(city.cells)] = city.cells
    if extra:
        extra(img)
    return img


def tick(image_path, pc, end, out_path):
    run([TICKS, '-pc', f'{pc:x}', '-end', f'{end:x}', '-counter', '4000000000',
         '-output', out_path, image_path])
    return open(out_path, 'rb').read()


def assemble_zx_driver(tmp, syms, ticks, view=None):
    src = os.path.join(tmp, 'zx_driver.asm')
    with open(src, 'w') as f:
        f.write('        org $0100\n')
        for n in ('initialise_simulation_variables', 'L8362', 'place_tool_at_cursor',
                  'V_selected_tool', 'V_pointer_charxy', 'V_view_topleft', 'V_cursor_validity',
                  'draw_map', 'V_ui_tick_counter', 'V_road_tile_variant'):
            f.write(f'        defc {n} = ${syms[n]:04x}\n')
        if view:
            vx, vy, tick = view
            view_code = f'''
        ld   a,{tick}
        ld   (V_ui_tick_counter),a
        and  16
        ld   (V_road_tile_variant),a
        ld   hl,{vx | vy << 8}
        ld   (V_view_topleft),hl
        call draw_map
'''
        else:
            view_code = ''
        f.write(f'''
        ld   sp,$0ff0
        di
        call initialise_simulation_variables
        ld   hl,$0600
zpoke:  ld   e,(hl)
        inc  hl
        ld   d,(hl)
        inc  hl
        ld   a,d
        or   e
        jr   z,zpoke_done
        ld   a,(hl)
        inc  hl
        ld   (de),a
        jr   zpoke
zpoke_done:
        ld   hl,0
        ld   (V_view_topleft),hl
        ld   a,1
        ld   (V_cursor_validity+1),a
        ld   hl,$0300
next:   ld   a,(hl)
        cp   $ff
        jr   z,actions_done
        ld   (V_selected_tool),a
        inc  hl
        ld   c,(hl)
        inc  hl
        ld   b,(hl)
        inc  hl
        ld   a,b
        add  a,8
        ld   b,a
        ld   (V_pointer_charxy),bc
        push hl
        call place_tool_at_cursor
        pop  hl
        jr   next
actions_done:
        ld   bc,{ticks}
loop:   ld   a,b
        or   c
        jr   z,view
        push bc
        call L8362
        pop  bc
        dec  bc
        jr   loop
view:{view_code}
done:   jr   done
''')
    run([Z80ASM, '-b', '-m', 'zx_driver.asm'], cwd=tmp)
    code = open(os.path.join(tmp, 'zx_driver.bin'), 'rb').read()
    done = parse_map(os.path.join(tmp, 'zx_driver.map'))['done']
    return code, done


LAST = None


def run_scenario(name, ticks, files, tmp, view=None):
    zx_bin, zx_map, po_bin, po_map = files
    zx_syms, po_syms = parse_map(zx_map), parse_map(po_map)
    zxb, pob = open(zx_bin, 'rb').read(), open(po_bin, 'rb').read()

    city = City(zxb, zx_syms)
    SCENARIOS[name](city)

    # reference: the original program, with its endless loop turned into a subroutine
    code, done = assemble_zx_driver(tmp, zx_syms, ticks, view)
    jr = zx_syms['L839b'] + 4
    assert zxb[jr - ZX_ORG] == 0x18, 'unexpected loop tail in the original'

    actions = ACTIONS.get(name, lambda: [])()
    table = bytes(v for act in actions for v in act) + b'\xff'
    assert len(table) <= 768

    def pokes(syms):
        t = b''
        for off, val in city.minimap_patches:
            a = syms['minimaps'] + off
            t += bytes([a & 255, a >> 8, val])
        assert len(t) <= 765
        return t + b'\x00\x00'

    def patch_zx(img):
        zp = pokes(zx_syms)
        img[0x0600:0x0600 + len(zp)] = zp
        img[0x0300:0x0300 + len(table)] = table
        # the real program finds this table in the Spectrum keyboard buffer
        img[0x5B11:0x5B19] = bytes([0x80, 0x40, 0x20, 0x10, 0x08, 0x04, 0x02, 0x01])
        img[0x0100:0x0100 + len(code)] = code
        img[jr] = 0xC9              # RET instead of JR start_simulation
        img[jr + 1] = 0x00

    zx_img = make_image(zxb, ZX_ORG, zx_syms, city, patch_zx)
    zx_path = os.path.join(tmp, f'{name}_zx.img')
    open(zx_path, 'wb').write(zx_img)
    zx_dump = tick(zx_path, 0x0100, done, os.path.join(tmp, f'{name}_zx.out'))

    def patch_po(img):
        pp = pokes(po_syms)
        img[po_syms['test_pokes']:po_syms['test_pokes'] + len(pp)] = pp
        img[po_syms['test_actions']:po_syms['test_actions'] + len(table)] = table
        if view:
            vx, vy, vt = view
            img[po_syms['test_view_on']] = 1
            img[po_syms['test_view_tick']] = vt
            img[po_syms['test_view_xy']] = vx
            img[po_syms['test_view_xy'] + 1] = vy
        img[po_syms['test_coop']] = 1 if COOP else 0
        img[po_syms['test_ticks']] = ticks & 255
        img[po_syms['test_ticks'] + 1] = ticks >> 8

    po_img = make_image(pob, 0x100, po_syms, city, patch_po)
    po_path = os.path.join(tmp, f'{name}_po.img')
    open(po_path, 'wb').write(po_img)
    po_dump = tick(po_path, 0x100, po_syms['test_done'], os.path.join(tmp, f'{name}_po.out'))

    global LAST
    LAST = (zx_dump, po_dump, zx_syms, po_syms)
    # compare
    problems = []
    # The portable image is laid out like a ROM machine's: code and tables below
    # __data_user_head, everything the engine writes above it.  So nothing below may change.
    ram = po_syms['__data_user_head']
    changed = [i for i in range(ram) if po_dump[i] != po_img[i]]
    if changed:
        near = lambda a: max(((v, k) for k, v in po_syms.items() if v <= a and not k.startswith('__')),
                             default=(0, '?'))[1]
        problems.append(f'the engine wrote to ROM: {len(changed)} bytes below {ram:#06x}, first at '
                        f'{changed[0]:#06x} (after {near(changed[0])})')
    regions = [('levelmap', MAP_W * MAP_W), ('minimaps', 6912)] + engine_vars()
    nvars = 0
    for rname, size in regions:
        if rname in SKIP_VARS or (view and rname in VIEW_SCRATCH):
            continue
        if rname not in zx_syms or rname not in po_syms:
            problems.append(f'{rname}: missing symbol ({"zx" if rname not in zx_syms else "portable"})')
            continue
        a = normalise(rname, zx_dump[zx_syms[rname]:zx_syms[rname] + size], zx_syms)
        b = normalise(rname, po_dump[po_syms[rname]:po_syms[rname] + size], po_syms)
        nvars += 1
        if a != b:
            first = next(i for i in range(len(a)) if a[i] != b[i])
            ndiff = sum(1 for i in range(len(a)) if a[i] != b[i])
            problems.append(f'{rname}: {ndiff} of {size} bytes differ, first at +{first} (zx={a[first]:02x} portable={b[first]:02x})')
    if view:
        out = po_syms['test_view_out']
        bad_cells = []
        for r in range(16):
            for c in range(32):
                row = 8 + r
                scr = 0x4000 + (row >> 3) * 0x800 + (row & 7) * 0x20 + c
                art_zx = bytes(zx_dump[scr + 0x100 * k] for k in range(8))
                attr_zx = zx_dump[0x5800 + row * 32 + c]
                o = out + (r * 32 + c) * 9
                art_po, attr_po = po_dump[o:o + 8], po_dump[o + 8]
                if art_zx != art_po or attr_zx != attr_po:
                    bad_cells.append((c, r, art_zx.hex(), attr_zx, art_po.hex(), attr_po))
        if bad_cells:
            problems.append(f'view: {len(bad_cells)} of 512 cells differ, e.g. col {bad_cells[0][0]} row {bad_cells[0][1]}: '
                            f'zx art={bad_cells[0][2]} attr={bad_cells[0][3]:02x} portable art={bad_cells[0][4]} attr={bad_cells[0][5]:02x}')
        nvars += 512
    if COOP:
        lo, hi = po_syms['sim_stack'], po_syms['sim_stack_top']
        used = next((hi - i for i in range(lo, hi) if po_dump[i] != 0xA5), 0)
        SIM_STACK_USED[name] = max(SIM_STACK_USED.get(name, 0), used)
        steps = int.from_bytes(po_dump[po_syms['test_steps']:po_syms['test_steps'] + 2], 'little')
        # each tick is 96 map rows, so at least 96 slices per tick if it really yielded
        if steps < ticks * 96:
            problems.append(f'cooperative run made only {steps} sim_step calls for {ticks} ticks (expected >= {ticks * 96})')
    # did the scenario actually exercise the simulation?
    pop = int.from_bytes(po_dump[po_syms['V_CityPop']:po_syms['V_CityPop'] + 3], 'little')
    month = po_dump[po_syms['V_month']]
    return problems, nvars, pop, month


COOP = False
SIM_STACK_USED = {}         # scenario -> deepest the simulation's own stack went (coop runs)

def main():
    global COOP
    ap = argparse.ArgumentParser()
    ap.add_argument('--ticks', type=int, default=40)
    ap.add_argument('--scenario', nargs='*', default=list(SCENARIOS))
    ap.add_argument('--keep', action='store_true', help='keep the scratch directory')
    ap.add_argument('--views', action='store_true', help='also compare the rendered view (several origins and animation phases)')
    ap.add_argument('--coop', action='store_true', help='tick the portable engine in sim_step slices (cooperative task)')
    args = ap.parse_args()
    COOP = args.coop

    tmp = tempfile.mkdtemp(prefix='simcity_golden_')
    try:
        files = build(tmp)
        bad = 0
        for name in args.scenario:
            runs = [None]
            if args.views:
                runs = [(0, 0, 0), (0, 0, 48), (11, 8, 32), (12, 12, 16), (30, 20, 48), (64, 40, 0)]
            for view in runs:
                problems, n, pop, month = run_scenario(name, args.ticks, files, tmp, view)
                status = 'PASS' if not problems else 'FAIL'
                label = name if not view else f'{name} view{view}'
                print(f'{status}  {label:30} {args.ticks} ticks, {n} regions compared, '
                      f'CityPop={pop} month={month}')
                for p in problems:
                    print('        ', p)
                bad += bool(problems)
        if COOP and SIM_STACK_USED:
            print('simulation stack depth in bytes (of 256), deepest per scenario: ' +
                  ', '.join(f'{k} {v}' for k, v in SIM_STACK_USED.items()))
        if args.keep:
            print('scratch directory:', tmp)
        sys.exit(1 if bad else 0)
    finally:
        if not args.keep:
            shutil.rmtree(tmp, ignore_errors=True)


if __name__ == '__main__':
    main()
