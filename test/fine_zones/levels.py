#!/usr/bin/env python3
"""FINE_ZONE_LEVELS: every level the zone handlers can write, and what the engine does with it.  test/fine_zones/levels.asm, in the headless test platform at 120x100
with the flag, puts a zone of each kind at its level 0 and, for every land value from 0 to 255 and three seeds of the random numbers, calls the real DoResidential,
DoCommercial or DoIndustrial (the land value is the one thing the test sets: the routine that works it out is patched to return).  Checked, for each:
  * the zone's rows are still a zone: markers, then the group and piece of nine consecutive pieces of one block (three to a row), the block's own
  * the block is one of the kind's levels: residential 8 from piece 136, commercial 10 from 208, industrial 8 from 298 (what the tables and the art have)
  * the group of its first piece is in D_zone_handler_config (what get_zone_handler_type and the zone dispatcher look up), and get_zone_handler_type answers with the
    kind's handler type and leaves the stack as it found it
and every level of every kind has been written by some land value.  Under z88dk-ticks; no emulator.

    python3 test/fine_zones/levels.py"""
import os
import re
import subprocess
import sys
import tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
W, H = 120, 100
KINDS = (('residential', 136, 8, 9), ('commercial', 208, 10, 10), ('industrial', 298, 8, 11))     # name, first piece, levels, the handler type get_zone_handler_type gives
WHERE = ((10, 10), (20, 10), (30, 10))
SEEDS = 3
# a zone with nothing in it (what a handler puts when the land is worth nothing): the three rows of tiles, not of pieces
EMPTY = (bytes.fromhex('424042415143434243'), bytes.fromhex('494a4b50524c4f4e4d'), bytes.fromhex('494a4b50534c4f4e4d'))
# the land value below which the commercial and industrial handlers empty the zone (their growth index, the value over 25 or 31, is 0)
EMPTY_BELOW = (None, 25, 31)


def piece(group_byte, piece_byte):
    return (group_byte & 63) << 3 | (piece_byte & 7)


def main():
    src = open(os.path.join(ROOT, 'engine', 'simulation.asm'), encoding='latin-1').read()
    part = src.split('IFDEF   FINE_ZONE_LEVELS')[1].split('ELSE')[0]
    table = {0, 1, 2, 3, 4, 6, 8, 10, 12} | {int(m.group(1), 16) for m in re.finditer(r'defb\s+\$([0-9a-f]+),\$0[9ab]', part)}
    with tempfile.TemporaryDirectory() as tmp:
        subprocess.run(['cp', '-R'] + [os.path.join(ROOT, d) for d in ('engine', 'platform', 'target', 'test', 'assets')] + [tmp], check=True)
        r = subprocess.run(['z88dk-z80asm', '-Iengine', '-DPORTABLE', '-DLEVELS_TEST', f'-DMAP_W={W}', f'-DMAP_H={H}', '-DFINE_ZONE_LEVELS', '-DPOWER_SHOWN', '-b', '-m',
                            'target/test/test_platform.asm'], cwd=tmp, capture_output=True, text=True)
        if r.returncode:
            print('FAIL  assembling\n' + r.stdout + r.stderr)
            return 1
        syms = {m.group(1): int(m.group(2), 16) for m in re.finditer(r'^(\S+)\s*=\s*\$([0-9A-Fa-f]+)', open(f'{tmp}/target/test/test_platform.map').read(), re.M)}
        binary = open(f'{tmp}/target/test/test_platform.bin', 'rb').read()
        img = bytearray(65536)
        img[0x100:0x100 + len(binary)] = binary
        img[syms['calculate_zone_land_value']] = 0xC9              # (ret: the test sets the land value)
        img[syms['V_display_population']] = 1                      # (an industrial population: without one a commercial or industrial zone does not grow)
        for k, (name, base, levels, _) in enumerate(KINDS):
            rows = b''.join(bytes([0xB3 if row == 0 else 0x83, 0xC0 | ((base + 3 * row) >> 3 & 63), 0xC0 | ((base + 3 * row) & 7)]) for row in range(3))
            img[syms['lev_zone0'] + 9 * k:syms['lev_zone0'] + 9 * k + 9] = rows
            img[syms['lev_xy'] + 2 * k:syms['lev_xy'] + 2 * k + 2] = bytes(WHERE[k])
        mems = []
        for seed in range(SEEDS):
            img[syms['lev_seed_n']] = seed
            open(f'{tmp}/image.bin', 'wb').write(img)
            run = subprocess.run(['z88dk-ticks', '-pc', '100', '-end', f'{syms["levels_end"]:x}', '-counter', '4000000000', '-output', f'{tmp}/mem.bin', f'{tmp}/image.bin'],
                                 capture_output=True, text=True)
            if not os.path.exists(f'{tmp}/mem.bin') or 'counter limit' in run.stdout + run.stderr:
                print('FAIL  the run did not finish\n' + (run.stdout + run.stderr)[-300:])
                return 1
            mems.append(open(f'{tmp}/mem.bin', 'rb').read())
            os.remove(f'{tmp}/mem.bin')
    out = syms['lev_out']
    ok = True
    seen = {k: set() for k in range(3)}
    wrong = {k: [] for k in range(3)}
    emptied = [0, 0, 0]
    for seed in range(SEEDS):
        mem = mems[seed]
        case = 0
        for kind in range(3):
            name, base, levels, handler = KINDS[kind]
            for value in range(256):
                rec = mem[out + 12 * case:out + 12 * case + 12]
                case += 1
                rows = [rec[3 * r:3 * r + 3] for r in range(3)]
                p0 = piece(rows[0][1], rows[0][2])
                bad = None
                if bytes(b for row in rows for b in row) == EMPTY[kind]:
                    emptied[kind] += 1
                    if EMPTY_BELOW[kind] and value >= EMPTY_BELOW[kind]:
                        bad = f'the zone was emptied, at a land value that should grow it'
                    elif not bad:
                        continue
                elif any(rows[r][0] & 0xC7 != 0x83 or rows[r][1] & 0xC0 != 0xC0 or rows[r][2] & 0xC0 != 0xC0 for r in range(3)) or rows[0][0] & 0x20 == 0:
                    bad = 'the rows are not a zone: ' + ' '.join(f'{b:02x}' for row in rows for b in row)
                elif any(piece(rows[r][1], rows[r][2]) != p0 + 3 * r for r in range(3)):
                    bad = f'the rows are not three nine-piece rows: {[piece(rows[r][1], rows[r][2]) for r in range(3)]}'
                elif not base <= p0 < base + 9 * levels or (p0 - base) % 9:
                    bad = f'piece {p0} is not a level of the block at {base}'
                elif p0 >> 3 not in table:
                    bad = f'group {p0 >> 3} (piece {p0}) is not in D_zone_handler_config'
                elif rec[9] != handler:
                    bad = f'get_zone_handler_type says {rec[9]:#x}, not {handler:#x}'
                elif rec[10]:
                    bad = 'a call left the stack different'
                if bad:
                    wrong[kind].append(f'land value {value}, seed {seed}: {bad}')
                else:
                    seen[kind].add((p0 - base) // 9)
    for kind in range(3):
        name, base, levels, _ = KINDS[kind]
        missing = sorted(set(range(levels)) - seen[kind])
        good = not wrong[kind] and not missing
        ok = ok and good
        print(('PASS' if good else 'FAIL') + f'  {name}: levels written {sorted(seen[kind])} of {levels}' + (f', never written: {missing}' if missing else '') +
              f', emptied to a lot {emptied[kind]} times, {len(wrong[kind])} wrong' + ('' if not wrong[kind] else '\n      ' + '\n      '.join(wrong[kind][:5])))
    unknown, stack = mems[0][syms['lev_unknown']], mems[0][syms['lev_unknown_stack']]
    good = unknown == 0xFF and not stack
    ok = ok and good
    print(('PASS' if good else 'FAIL') + f'  a zone of a group the table lacks: get_zone_handler_type says {unknown:#x} (not found: 0xff) and {"leaves the stack as it was" if not stack else "LEAVES THE STACK DIFFERENT"}')
    return 0 if ok else 1


if __name__ == '__main__':
    sys.exit(main())
