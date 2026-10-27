#!/usr/bin/env python3
"""Focused tests for the PORTABLE power scan, run under z88dk-ticks.

Checks connected and disconnected conductors, summed coal capacity, and the
portable coal/nuclear budgets on both map sizes.

    python3 test/power_scan/run.py
"""
import os
import re
import shutil
import subprocess
import tempfile
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
DIRT, WIRE, NUCLEAR_MARK = 2, 33, 136


def assemble(tmp, w, h):
    for directory in ('engine', 'platform', 'target', 'test', 'assets'):
        shutil.copytree(os.path.join(ROOT, directory), os.path.join(tmp, directory))
    result = subprocess.run(
        ['z88dk-z80asm', '-Iengine', '-DPORTABLE', '-DPOWER_SCAN_TEST', f'-DMAP_W={w}', f'-DMAP_H={h}', '-b', '-m',
         'target/test/test_platform.asm'], cwd=tmp, capture_output=True, text=True)
    if result.returncode:
        raise RuntimeError(f'assembly failed for {w}x{h}:\n{result.stdout}{result.stderr}')
    with open(os.path.join(tmp, 'target/test/test_platform.map')) as f:
        symbols = {m.group(1): int(m.group(2), 16) for m in re.finditer(r'^(\S+)\s*=\s*\$([0-9A-Fa-f]+)', f.read(), re.M)}
    with open(os.path.join(tmp, 'target/test/test_platform.bin'), 'rb') as f:
        binary = f.read()
    image = bytearray(65536)
    image[0x100:0x100 + len(binary)] = binary
    return symbols, image


def run_case(tmp, symbols, image, w, h, name, rect, stations, expected, brownout, branches=(), isolated=()):
    mem = bytearray(image)
    level = symbols['levelmap']
    mem[level:level + w * h] = bytes([DIRT]) * (w * h)
    x0, y0, rw, rh = rect
    for y in range(y0, y0 + rh):
        start = level + y * w + x0
        mem[start:start + rw] = bytes([WIRE]) * rw
    for x, y in isolated:
        mem[level + y * w + x] = WIRE
    for x, y in branches:
        mem[level + y * w + x] = WIRE

    station_list = symbols['V_powerstation_list']
    for i, (x, y, kind) in enumerate(stations):
        address = level + y * w + x
        mem[station_list + 2 * i:station_list + 2 * i + 2] = address.to_bytes(2, 'little')
        if kind == 'nuclear':
            mem[address + 1] = NUCLEAR_MARK  # & 63 == 8; still a conductor
    terminator = station_list + 2 * len(stations)
    mem[terminator:terminator + 2] = b'\0\0'

    mm_power = symbols['minimaps'] + 2 * (w // 4) * (h // 4) + 2 * (w // 2) * (h // 2)
    power_bytes = (w // 8) * h
    mem[mm_power:mm_power + power_bytes] = bytes(power_bytes)
    path, output = os.path.join(tmp, 'power_input.bin'), os.path.join(tmp, 'power_output.bin')
    with open(path, 'wb') as f:
        f.write(mem)
    result = subprocess.run(['z88dk-ticks', '-pc', '100', '-end', f'{symbols["power_scan_test_done"]:x}', '-counter',
                             '4000000000', '-output', output, path], capture_output=True, text=True)
    if result.returncode or not os.path.exists(output):
        raise RuntimeError(f'{name}: emulator failed:\n{result.stdout}{result.stderr}')
    with open(output, 'rb') as f:
        result_mem = f.read()
    count = sum((result_mem[mm_power + y * (w // 8) + (x >> 3)] >> (7 - (x & 7))) & 1
                for y in range(h) for x in range(w))
    isolated_powered = [((result_mem[mm_power + y * (w // 8) + (x >> 3)] >> (7 - (x & 7))) & 1)
                        for x, y in isolated]
    actual_brownout = result_mem[symbols['V_brownout_detected']]
    ok = count == expected and actual_brownout == brownout and not any(isolated_powered)
    detail = f'{count} powered (expected {expected}), brownout {actual_brownout} (expected {brownout})'
    if isolated:
        detail += f', isolated conductors off: {not any(isolated_powered)}'
    print(('PASS' if ok else 'FAIL') + f'  {w}x{h} {name}: {detail}')
    return ok


def run_generated_station_case(tmp, symbols, image, w, h):
    mem = bytearray(image)
    level = symbols['levelmap']
    mem[level:level + w * h] = bytes([DIRT]) * (w * h)
    coal = symbols['default_coal_power_station_tile']
    station_bytes = image[coal:coal + 16]
    sx, sy = 10, 10
    for row in range(4):
        start = level + (sy + row) * w + sx
        mem[start:start + 4] = station_bytes[row * 4:row * 4 + 4]
    # Connect a short wire run to the plant's south edge, as the game does.
    start = level + (sy + 4) * w + sx
    mem[start:start + 24] = bytes([WIRE]) * 24
    mm_power = symbols['minimaps'] + 2 * (w // 4) * (h // 4) + 2 * (w // 2) * (h // 2)
    power_bytes = (w // 8) * h
    mem[mm_power:mm_power + power_bytes] = bytes(power_bytes)
    path, output = os.path.join(tmp, 'power_generated.bin'), os.path.join(tmp, 'power_generated_output.bin')
    with open(path, 'wb') as f:
        f.write(mem)
    result = subprocess.run(['z88dk-ticks', '-pc', f'{symbols["power_scan_generated_test_start"]:x}', '-end',
                             f'{symbols["power_scan_test_done"]:x}', '-counter', '4000000000', '-output', output, path],
                           capture_output=True, text=True)
    if result.returncode or not os.path.exists(output):
        raise RuntimeError(f'generated station: emulator failed:\n{result.stdout}{result.stderr}')
    with open(output, 'rb') as f:
        result_mem = f.read()
    station_list = symbols['V_powerstation_list']
    found_station = int.from_bytes(result_mem[station_list:station_list + 2], 'little') != 0
    count = sum((result_mem[mm_power + y * (w // 8) + (x >> 3)] >> (7 - (x & 7))) & 1
                for y in range(h) for x in range(w))
    brownout = result_mem[symbols['V_brownout_detected']]
    ok = found_station and count >= 24 and count < 450 and brownout == 0
    print(('PASS' if ok else 'FAIL') + f'  {w}x{h} generate_power_map discovers one coal plant: '
          f'found={found_station}, {count} powered cells, brownout={brownout}')
    return ok


def run_placement_case(tmp, symbols, image, w, h):
    mem = bytearray(image)
    level = symbols['levelmap']
    mem[level:level + w * h] = bytes([DIRT]) * (w * h)
    path, output = os.path.join(tmp, 'power_placement.bin'), os.path.join(tmp, 'power_placement_output.bin')
    with open(path, 'wb') as f:
        f.write(mem)
    result = subprocess.run(['z88dk-ticks', '-pc', f'{symbols["power_scan_placement_test_start"]:x}', '-end',
                             f'{symbols["power_scan_test_done"]:x}', '-counter', '4000000000', '-output', output, path],
                           capture_output=True, text=True)
    if result.returncode or not os.path.exists(output):
        raise RuntimeError(f'placing a station on a blank city: emulator failed:\n{result.stdout}{result.stderr}')
    with open(output, 'rb') as f:
        result_mem = f.read()
    station_list = symbols['V_powerstation_list']
    found_station = int.from_bytes(result_mem[station_list:station_list + 2], 'little') != 0
    mm_power = symbols['minimaps'] + 2 * (w // 4) * (h // 4) + 2 * (w // 2) * (h // 2)
    count = sum((result_mem[mm_power + y * (w // 8) + (x >> 3)] >> (7 - (x & 7))) & 1
                for y in range(h) for x in range(w))
    ok = found_station and count > 0
    print(('PASS' if ok else 'FAIL') + f'  {w}x{h} blank city, place power station, tick: '
          f'found={found_station}, {count} powered cells')
    return ok


def run_scenario_case(tmp, symbols, image, w, h, scenario_name, scenario_path):
    sys.path.insert(0, os.path.join(ROOT, 'tools'))
    from convert_amiga_scenarios import convert_map, infer_raised_bridges
    scenario, _, source_power, source_traffic = convert_map(scenario_path, None)
    expected_stations = sum(scenario[i] == 0xB4 and scenario[i + 1] & 63 in (6, 8)
                            for i in range(len(scenario) - 1))
    mem = bytearray(image)
    level = symbols['levelmap']
    mem[level:level + w * h] = scenario
    mm_power = symbols['minimaps'] + 2 * (w // 4) * (h // 4) + 2 * (w // 2) * (h // 2)
    power_bytes = (w // 8) * h
    mem[mm_power:mm_power + power_bytes] = bytes(power_bytes)
    path, output = os.path.join(tmp, 'tokyo_power.bin'), os.path.join(tmp, 'tokyo_power_output.bin')
    with open(path, 'wb') as f:
        f.write(mem)
    def execute(entry, label, output_path):
        try:
            result = subprocess.run(['z88dk-ticks', '-pc', f'{symbols[entry]:x}', '-end',
                                     f'{symbols["power_scan_test_done"]:x}', '-counter', '4000000000',
                                     '-output', output_path, path], capture_output=True, text=True, timeout=30)
        except subprocess.TimeoutExpired:
            print(f'FAIL  Tokyo {label}: timed out after 30 seconds')
            return None
        if result.returncode or not os.path.exists(output_path):
            print(f'FAIL  Tokyo {label}: emulator failed:\n{result.stdout}{result.stderr}')
            return None
        with open(output_path, 'rb') as f:
            return f.read()

    scan_mem = execute('power_scan_generated_test_start', 'scenario power scan', output)
    tick_mem = execute('power_scan_scenario_tick_start', 'first scenario tick', output + '.tick')
    if scan_mem is None or tick_mem is None:
        return False
    station_list = symbols['V_powerstation_list']
    station_count = 0
    while station_count < 750 and int.from_bytes(scan_mem[station_list + 2 * station_count:
                                                          station_list + 2 * station_count + 2], 'little'):
        station_count += 1
    powered = sum((scan_mem[mm_power + y * (w // 8) + (x >> 3)] >> (7 - (x & 7))) & 1
                  for y in range(h) for x in range(w))
    zone_cells = [y * w + x for y in range(h) for x in range(w) if scan_mem[level + y * w + x] >= 128]
    powered_zone_cells = sum((scan_mem[mm_power + (i // w) * (w // 8) + ((i % w) >> 3)] >>
                              (7 - ((i % w) & 7))) & 1 for i in zone_cells)
    zone_markers = [i for i, tile in enumerate(scenario) if tile & 0xA0 == 0xA0]
    bern_stadiums_ok = True
    if scenario_name == 'Bern':
        bern_stadiums_ok = all(
            scenario[y * w + x] & 15 == 4 and
            scenario[y * w + x + 1] == 0xC4 and
            scenario[y * w + x + 2] == 0xC4
            for x, y in ((18, 44), (45, 83), (84, 46)))
    powered_zones = sum((scan_mem[mm_power + (i // w) * (w // 8) + ((i % w) >> 3)] >>
                         (7 - ((i % w) & 7))) & 1 for i in zone_markers)
    brownout = scan_mem[symbols['V_brownout_detected']]
    tick_powered = sum((tick_mem[mm_power + y * (w // 8) + (x >> 3)] >> (7 - (x & 7))) & 1
                       for y in range(h) for x in range(w))
    # Bern's source map has its saved power bit on each zone's centre tile.
    # Check the converter preserves those flags separately from the runtime
    # scan, which reconstructs power from the converted conductor network.
    saved_powered_zones = sum(bool(scenario[i] & 0x10) for i in zone_markers)
    saved_power_rects_ok = all(
        not (scenario[i] & 0x10) or all(
            (source_power[(i // w + dy) * (w // 8) + ((i % w + dx) >> 3)] >>
             (7 - ((i % w + dx) & 7))) & 1
            for dy in range(scenario[i] & 15) for dx in range(scenario[i] & 15))
        for i in zone_markers)
    raw_source = open(scenario_path, 'rb').read()
    source_tiles = [[int.from_bytes(raw_source[2 * (x * h + y):2 * (x * h + y) + 2], 'big') & 0x3ff
                     for x in range(w)] for y in range(h)]
    bridge_spine, bridge_overhang = infer_raised_bridges(source_tiles)
    airport_saved_power_ok = True
    detroit_airport_powered = True
    if scenario_name in ('Detroit', 'Boston', 'Tokyo', 'Bern', 'Rio_De_Janerio'):
        airports = [(x, y) for y in range(h) for x in range(w) if source_tiles[y][x] == 709]
        airport_saved_power_ok = bool(airports) and all(
            bool(int.from_bytes(raw_source[2 * ((x + 1) * h + y + 1):
                                         2 * ((x + 1) * h + y + 1) + 2], 'big') & 0x8000) ==
            bool(scenario[y * w + x] & 0x10)
            for x, y in airports)
        if scenario_name == 'Detroit':
            x, y = airports[0]
            detroit_airport_powered = bool(
                (scan_mem[mm_power + y * (w // 8) + (x >> 3)] >> (7 - (x & 7))) & 1)
    alternate_paths = {first + offset: code for first in (96, 112, 128)
                       for offset, code in enumerate((18, 19, 7, 8, 11, 9, 10, 12,
                                                      14, 16, 13, 15, 17, 49, 48, 0))}
    busy_source = {146: 7, 162: 7, 147: 8, 163: 8,
                   178: 7, 179: 8, 194: 7, 195: 8}
    expected_busy = []
    alternate_path_cells = []
    bridge_underlay_cells = []
    for x in range(w):
        for y in range(h):
            tile = int.from_bytes(raw_source[2 * (x * h + y):2 * (x * h + y) + 2], 'big') & 0x3ff
            if tile in busy_source:
                expected_busy.append((x, y, busy_source[tile]))
            if tile in alternate_paths:
                alternate_path_cells.append((x, y, alternate_paths[tile]))
            if tile in (79, 95):
                bridge_underlay_cells.append((x, y, 19 if (x, y) in bridge_spine else
                                              87 if tile == 79 else 88))
    saved_busy_roads = sum(value >= 150 for value in source_traffic)
    busy_conversion_ok = all(scenario[y * w + x] == road for x, y, road in expected_busy)
    alternate_path_conversion_ok = all(scenario[y * w + x] == code
                                       for x, y, code in alternate_path_cells)
    bridge_underlay_conversion_ok = all(scenario[y * w + x] == code
                                        for x, y, code in bridge_underlay_cells)
    inferred_bridge_conversion_ok = (
        all(scenario[y * w + x] == 19 for x, y in bridge_spine) and
        all(scenario[y * w + x] == 0 for x, y in bridge_overhang))
    busy_density_ok = all(source_traffic[(y >> 1) * (w // 2) + (x >> 1)] >= 150
                          for x, y, _ in expected_busy)
    expected_saved_powered = {'Bern': 216}.get(scenario_name)
    expected_powered_zones = {'Bern': 216}.get(scenario_name)
    hamburg_ports_powered = True
    if scenario_name == 'Hamburg':
        # These four 4x4 seaports are saved as powered in the ST scenario and
        # must remain on the runtime power map after the scenario scan.
        hamburg_ports_powered = all(
            scenario[y * w + x] == 0xB4 and scenario[y * w + x + 1] == 0xCA and
            scenario[y * w + x + 2] == 0xC4 and
            ((scan_mem[mm_power + y * (w // 8) + (x >> 3)] >>
              (7 - (x & 7))) & 1)
            for x, y in ((30, 79), (69, 82), (84, 82), (2, 86)))
    ok = (station_count == expected_stations and
          (powered > 0 or expected_stations == 0) and tick_powered == powered and
          saved_power_rects_ok and busy_conversion_ok and busy_density_ok and
          alternate_path_conversion_ok and bridge_underlay_conversion_ok and
          inferred_bridge_conversion_ok and
          bern_stadiums_ok and
          hamburg_ports_powered and
          airport_saved_power_ok and detroit_airport_powered and
          (expected_saved_powered is None or saved_powered_zones == expected_saved_powered) and
          (expected_powered_zones is None or powered_zones == expected_powered_zones))
    print(('PASS' if ok else 'FAIL') + f'  {scenario_name} scenario scan/tick: {station_count}/{expected_stations} stations, '
          f'{powered_zones}/{len(zone_markers)} zone centres, {powered_zone_cells}/{len(zone_cells)} zone cells, '
          f'{powered} total cells, {saved_powered_zones} saved-powered markers, '
          f'{saved_busy_roads} seeded traffic cells, {len(alternate_path_cells)} alternate path tiles, '
          f'brownout={brownout}')
    return ok


def main():
    ok = True
    cases = {
        (96, 96): [
            ('connected island only', (10, 10, 10, 10), [(10, 10, 'coal')], 100, 0, (), [(30, 30)]),
            ('shared two-coal limit', (10, 10, 40, 30), [(10, 10, 'coal'), (11, 10, 'coal')], 900, 1, (), ()),
            ('exact shared capacity', (10, 10, 30, 30), [(10, 10, 'coal'), (11, 10, 'coal')], 900, 0, (), ()),
            ('96-map nuclear limit', (10, 10, 60, 25), [(10, 10, 'nuclear')], 1350, 1, (), ()),
            ('queue overflow refills branch seeds', (1, 10, 90, 1), [(1, 10, 'coal')], 134, 0,
             [(x, 9) for x in range(2, 90, 2)], ()),
        ],
        (120, 100): [
            ('120-map coal limit', (10, 10, 50, 30), [(10, 10, 'coal')], 700, 1, (), ()),
            ('120-map nuclear limit', (10, 10, 60, 40), [(10, 10, 'nuclear')], 2000, 1, (), ()),
            ('full-map scan with capacity for every cell', (0, 0, 120, 100),
             [(10 + 12 * i, 10, 'nuclear') for i in range(9)], 12000, 0, (), ()),
        ],
    }
    for (w, h), scenarios in cases.items():
        with tempfile.TemporaryDirectory() as tmp:
            symbols, image = assemble(tmp, w, h)
            if (w, h) == (120, 100):
                ok = run_generated_station_case(tmp, symbols, image, w, h) and ok
                ok = run_placement_case(tmp, symbols, image, w, h) and ok
                scenario_dir = os.path.join(ROOT, 'build', 'amiga_scenarios')
                scenario_names = sorted(os.path.splitext(name)[0] for name in os.listdir(scenario_dir)
                                        if name.endswith('.map')) if os.path.isdir(scenario_dir) else ()
                for scenario_name in scenario_names:
                    scenario_path = os.path.join(ROOT, 'build', 'amiga_scenarios', scenario_name + '.map')
                    if os.path.isfile(scenario_path):
                        ok = run_scenario_case(tmp, symbols, image, w, h, scenario_name, scenario_path) and ok
            for name, rect, stations, expected, brownout, branches, isolated in scenarios:
                ok = run_case(tmp, symbols, image, w, h, name, rect, stations, expected, brownout, branches, isolated) and ok
    return 0 if ok else 1


if __name__ == '__main__':
    raise SystemExit(main())
