#!/usr/bin/env python3
"""The AY sound effect player (target/common/ay_sfx.asm) under z88dk-ticks.

Every effect in assets/st_sounds.bin is started and ticked until it has finished and a little more; the writes to the chip's ports (found in
the instruction trace) are compared tick by tick with what tools/extract_st_sounds.py's own decoder says the packed effect holds: the three
registers set at the start, then for each tick channel C's tone (two registers), its noise and its volume, then silence.  Also with the
frame skip that makes 50 Hz of a 60 Hz display (AY_SKIP) and with the Multi 8's ports.

  usage: test/ay_sfx/run.py
"""
import os
import random
import re
import subprocess
import sys
import tempfile

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
sys.path.insert(0, os.path.join(ROOT, 'tools'))
import extract_st_sounds as st                      # (its packer and its decoder)

Z80ASM = 'z88dk-z80asm'
TICKS = 'z88dk-ticks'

HARNESS = '''        SECTION code_user
        org     $2000
        EXTERN  ay_start, ay_tick
start:  ld      sp,$7000
        ld      ix,plan
next:   ld      a,(ix+0)                ; the effect
        cp      255
        jr      z,fin
        out     ($FD),a                 ; (a marker: an effect starts)
        call    ay_start
        ld      b,(ix+1)                ; the calls of ay_tick
tloop:  ld      a,b
        out     ($FE),a                 ; (a marker: a call of ay_tick)
        push    bc
        call    ay_tick
        pop     bc
        djnz    tloop
        inc     ix
        inc     ix
        jr      next
fin:    halt
plan:
PLAN
'''


def run_trace(effects_ticks, defines, addr_port, data_port):
    with tempfile.TemporaryDirectory() as tmp:
        plan = ''.join(f'        defb {e},{t}\n' for e, t in effects_ticks) + '        defb 255\n'
        open(os.path.join(tmp, 'h.asm'), 'w').write(HARNESS.replace('PLAN\n', plan))
        out = subprocess.run([Z80ASM, '-b', '-m', '-I' + ROOT] + defines + ['-oh.bin', 'h.asm', os.path.join(ROOT, 'target/common/ay_sfx.asm')],
                             cwd=tmp, capture_output=True, text=True)
        if out.returncode or out.stderr.strip():
            print(out.stdout + out.stderr)
            return None
        syms = {}
        for line in open(os.path.join(tmp, 'h.map')):
            m = re.match(r'(\S+)\s+= \$([0-9A-F]+) ;', line)
            if m:
                syms[m.group(1)] = int(m.group(2), 16)
        code = open(os.path.join(tmp, 'h_code_user.bin'), 'rb').read()
        img = bytearray(65536)
        img[0x2000:0x2000 + len(code)] = code
        open(os.path.join(tmp, 'img.bin'), 'wb').write(img)
        with open(os.path.join(tmp, 'trace.txt'), 'w') as tf:
            subprocess.run([TICKS, '-pc', '2000', '-end', f'{syms["fin"]:x}', '-counter', '400000000', '-trace', 'img.bin'],
                           cwd=tmp, stdout=tf, stderr=subprocess.DEVNULL)
        reg_re = re.compile(r'pc=(\w+), \[pc\]=\w+,\s+bc=(\w+),\s+de=(\w+),\s+hl=(\w+),\s+af=(\w+)')
        ins_re = re.compile(r'^\s+out\s+\(\$([0-9a-fA-F]+)\),a\s+;\[(\w+)\]')
        outc_re = re.compile(r'^\s+out\s+\(c\),([ad])\s+;\[(\w+)\]')
        a = d = bc = 0
        effects, reg = [], 0
        for line in open(os.path.join(tmp, 'trace.txt'), errors='replace'):
            if line.startswith('pc='):
                g = reg_re.match(line)
                a = int(g.group(5), 16) >> 8
                d = int(g.group(3), 16) >> 8
                bc = int(g.group(2), 16)
                continue
            g = ins_re.match(line)
            if g:
                port = int(g.group(1), 16)
            else:
                g = outc_re.match(line)
                if not g:
                    continue
                port = bc                            # (the SAA's ports are 16 bit: out (c),r with b = 1 for the address)
                if g.group(1) == 'd':
                    a = d
            if port == 0xFD:
                effects.append({'effect': a, 'start': [], 'ticks': []})
            elif port == 0xFE:
                effects[-1]['ticks'].append([])
            elif port == addr_port:
                reg = a
            elif port == data_port:
                (effects[-1]['ticks'][-1] if effects[-1]['ticks'] else effects[-1]['start']).append((reg, a))
        return effects


def scaled(p, limit):
    """A period for the ST's 2 MHz chip as one for a chip at 3.579545 MHz: times 1.78125 (1 + 1/2 + 1/4 + 1/32), at most `limit`."""
    q = min(limit, p + (p >> 1) + (p >> 2) + (p >> 5))
    if limit == 4095 and 100 <= p <= 2200:      # (a tone: within a percent of the true ratio of the clocks, where it can be)
        assert abs(q / p / (3579545 / 2000000) - 1) < 0.01, (p, q)
    return q


def expected(blob, effect, calls, skip, acc=0, scale=False):
    """The writes the player should make for the effect's first `calls` calls of ay_tick."""
    at = blob[1 + 2 * effect] | blob[2 + 2 * effect] << 8
    mixer, ticks = st.unpack_effect(blob, at)
    start = [(8, 0), (9, 0), (7, mixer)]
    out, n, active = [], 0, True
    for _ in range(calls):
        if not active:
            out.append([])
            continue
        if skip:
            acc += skip
            if acc > 255:
                acc &= 255
                out.append([])                      # a frame that is not a tick
                continue
        if n < len(ticks):
            period, vol = ticks[n]
            if scale:
                out.append([(4, scaled(period, 4095) & 255), (5, scaled(period, 4095) >> 8), (6, scaled(period & 31, 31)), (10, vol)])
            else:
                out.append([(4, period & 255), (5, period >> 8), (6, period & 31), (10, vol)])
            n += 1
        else:
            out.append([(10, 0)])                   # the end: silence
            active = False
    return start, out, acc


SAA_AMP = [0x00, 0x00, 0x00, 0x00, 0x00, 0x11, 0x11, 0x11, 0x11, 0x22, 0x33, 0x44, 0x55, 0x88, 0xBB, 0xFF]


def saa_tick(period, vol):
    """What the SAM's player writes for a tick of period and volume (the AY's): channel 0's tone, octave, noise rate and amplitude.
    Written from the chip, not the player: the SAA's tone is 15625 * 2^octave / (511 - N) Hz and the AY's 125000 / P, so the octave takes
    P * 2^octave into 2048..4095 and 511 - N is that divided by 8."""
    p = period & 4095 or 1
    octave, x = 0, p
    while x < 2048 and octave < 7:
        x, octave = x * 2, octave + 1
    n = 511 - (x >> 3) if x >= 2048 else 255          # (too high for the SAA: its highest tone)
    assert 0 <= n <= 255
    if x >= 2048:
        assert abs(15625 * 2 ** octave / (511 - n) / (125000 / p) - 1) < 0.005, (period, octave, n)        # the pitch is the AY's, to half a percent
    rate = 0 if period & 31 < 6 else 1 if period & 31 < 12 else 2
    return [(8, n), (0x10, octave), (0x16, rate), (0, SAA_AMP[vol])]


def expected_saa(blob, effect, calls):
    at = blob[1 + 2 * effect] | blob[2 + 2 * effect] << 8
    mixer, ticks = st.unpack_effect(blob, at)
    start = [(0x1C, 2), (0x1C, 1), (0x14, 0 if mixer & 4 else 1), (0x15, 1 if mixer & 36 == 4 else 0)]
    out = []
    for t in range(calls):
        if t < len(ticks):
            out.append(saa_tick(*ticks[t]))
        elif t == len(ticks):
            out.append(saa_tick(ticks[-1][0], 0))              # the end: silence (the period as it was)
        else:
            out.append([])
    return start, out


CLOCK_HARNESS = '''        SECTION code_user
        org     $2000
        EXTERN  ay_sync, ay_clock_reset
        PUBLIC  ay_clock
start:  ld      sp,$7000
        ld      hl,table
        ld      (tp),hl
        call    ay_clock_reset          ; (reads the first value of the table)
        ld      bc,CALLS
loop:   push    bc
        call    ay_sync
        ld      a,0
        jr      nz,out
        inc     a
out:    out     ($FE),a                 ; 1: a frame, 0: none
        pop     bc
        dec     bc
        ld      a,b
        or      c
        jr      nz,loop
fin:    halt
; the counter: the next word of the table each time it is read
ay_clock:
        ld      hl,(tp)
        ld      e,(hl)
        inc     hl
        ld      d,(hl)
        inc     hl
        ld      (tp),hl
        ex      de,hl
        ret
tp:     defw    0
table:
TABLE
'''


def clock_model(values, calls, maxcatch=8):
    """What ay_sync should say on each call, given the counter's successive readings: Z (1) once for each pulse the counter has counted down
    since the last reading, at most maxcatch of them, then none until the next reading."""
    it = iter(values)
    last, pending, out = next(it), 0, []
    for _ in range(calls):
        if pending:
            pending -= 1
            out.append(1)
            continue
        now = next(it)
        elapsed = (last - now) & 0xFFFF
        last = now
        if elapsed == 0:
            out.append(0)
        else:
            pending = min(elapsed, maxcatch) - 1
            out.append(1)
    return out


def check_multi8_clock():
    """target/multi8/plat_sound.asm's ay_sync (with a stub for the timer read) against clock_model, on a counter that stands still, steps by one,
    jumps by more than it will catch up and wraps through 0."""
    rng = random.Random(8)
    value, values = 0x3000, [0x3000]
    for step in [0, 0, 1, 1, 2, 3, 20, 0, 1] + [rng.choice((0, 0, 1, 1, 1, 2, 3, 7, 8, 9, 40)) for _ in range(120)] + [0x3000 - 3] + [1, 1, 1, 1]:
        value = (value - step) & 0xFFFF if step < 0x3000 else step
        values.append(value)
    # make it pass through zero: start the second half near the bottom
    values += [(0x0006 - k * 2) & 0xFFFF for k in range(12)]
    calls = 400
    values += [0x0100] * (calls + 10)
    with tempfile.TemporaryDirectory() as tmp:
        table = ''.join(f'        defw ${v:04X}\n' for v in values)
        src = CLOCK_HARNESS.replace('TABLE\n', table).replace('CALLS', str(calls))
        open(os.path.join(tmp, 'h.asm'), 'w').write(src)
        out = subprocess.run([Z80ASM, '-b', '-m', '-I' + ROOT, '-DCLOCK_STUB', '-oh.bin', 'h.asm', os.path.join(ROOT, 'target/multi8/plat_sound.asm')],
                             cwd=tmp, capture_output=True, text=True)
        if out.returncode or out.stderr.strip():
            print(out.stdout + out.stderr)
            return False
        syms = {}
        for line in open(os.path.join(tmp, 'h.map')):
            m = re.match(r'(\S+)\s+= \$([0-9A-F]+) ;', line)
            if m:
                syms[m.group(1)] = int(m.group(2), 16)
        code = open(os.path.join(tmp, 'h_code_user.bin'), 'rb').read()
        img = bytearray(65536)
        img[0x2000:0x2000 + len(code)] = code
        open(os.path.join(tmp, 'img.bin'), 'wb').write(img)
        with open(os.path.join(tmp, 'trace.txt'), 'w') as tf:
            subprocess.run([TICKS, '-pc', '2000', '-end', f'{syms["fin"]:x}', '-counter', '400000000', '-trace', 'img.bin'],
                           cwd=tmp, stdout=tf, stderr=subprocess.DEVNULL)
        reg_re = re.compile(r'pc=(\w+), \[pc\]=\w+,\s+bc=(\w+),\s+de=(\w+),\s+hl=(\w+),\s+af=(\w+)')
        ins_re = re.compile(r'^\s+out\s+\(\$([0-9a-fA-F]+)\),a\s+;\[(\w+)\]')
        a, got = 0, []
        for line in open(os.path.join(tmp, 'trace.txt'), errors='replace'):
            if line.startswith('pc='):
                g = reg_re.match(line)
                a = int(g.group(5), 16) >> 8
                continue
            g = ins_re.match(line)
            if g and int(g.group(1), 16) == 0xFE:
                got.append(a)
    want = clock_model(values, calls)
    ok = got == want
    frames = sum(want)
    print(('PASS' if ok else 'FAIL') + f'  [Multi 8 frame clock] ay_sync over {calls} calls says "a frame" {frames} times, as the counter model does'
          + ('' if ok else f' (first difference at call {next((i for i in range(min(len(got), len(want))) if got[i] != want[i]), None)}; got {len(got)}, wanted {len(want)})'))
    return ok


def main():
    blob = open(os.path.join(ROOT, 'assets', 'st_sounds.bin'), 'rb').read()
    count = blob[0]
    lengths = []
    for k in range(count):
        at = blob[1 + 2 * k] | blob[2 + 2 * k] << 8
        lengths.append(len(st.unpack_effect(blob, at)[1]))
    ok = True
    for name, defines, addr, data, skip in (('AQ+ ports', [], 0xF7, 0xF6, 0), ('60 Hz skip', ['-DAY_SKIP=43'], 0xF7, 0xF6, 43),
                                            ('Aquarius+ as built: 3.58 MHz chip, 60 Hz', ['-DAY_SKIP=43', '-DAY_SCALE'], 0xF7, 0xF6, 43),
                                            ('Multi 8 as built: its ports, 3.58 MHz chip', ['-DAY_ADDR_PORT=24', '-DAY_DATA_PORT=25', '-DAY_SCALE'], 24, 25, 0),
                                            ('SAM Coupe SAA 1099', ['-DAY_SAA'], 0x1FF, 0xFF, 0)):
        plan = [(k, min(255, int(lengths[k] * (1.25 if skip else 1)) + 4)) for k in range(count)]
        got = run_trace(plan, defines, addr, data)
        if got is None:
            print('FAIL  the player does not assemble')
            return 1
        bad = []
        acc = 0                                      # (the frame skip's accumulator carries on from one effect to the next)
        for k, (e, calls) in enumerate(plan):
            if 'SAA' in name:
                want_start, want = expected_saa(blob, e, calls)
            else:
                want_start, want, acc = expected(blob, e, calls, skip, acc, scale='-DAY_SCALE' in defines)
            g = got[k]
            if g['start'] != want_start or len(g['ticks']) != calls or g['ticks'] != want:
                first = next((i for i in range(min(len(want), len(g['ticks']))) if want[i] != g['ticks'][i]), None)
                bad.append((e, first, want[first] if first is not None else None, g['ticks'][first] if first is not None else None, g['start'], want_start))
        print(('PASS' if not bad else 'FAIL') + f'  [{name}] {count} effects, every tick of every effect writes what the packed data says'
              + (f' (bad: {bad[:2]})' if bad else ''))
        ok &= not bad
    ok &= check_multi8_clock()
    return 0 if ok else 1


if __name__ == '__main__':
    sys.exit(main())
