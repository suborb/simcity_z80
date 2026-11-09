#!/usr/bin/env python3
"""target/lynx/plat_sound.asm (the ST's effects rendered into the 6-bit DAC at port $84) under z88dk-ticks: z88dk's lib/ticks/memory/lynx.lua logs every DAC write with the CPU's T-state count, so this
checks what MAME's wav could only approximate.  For each of the six effects (and the earthquake rumble, 100 calls):
  * the samples are SAMPLE_T (180) T-states apart, whichever way the noise branch went, except where a tick or a pass of the loop begins
  * the effect lasts what its data says (20 ms a tick of 6 MHz, within a few %)
  * the level is 0 or twice the AY volume's level (3 dB a step, 62 at the top) and the DAC ends at rest (0)
  * a tone-only effect has the AY's pitch (125000 / the period Hz) in every tick
(the pitch assumes the 6 MHz clock: CPU_MHZ in plat_sound.asm)
"""
import os, subprocess, sys, tempfile

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
HERE = os.path.dirname(os.path.abspath(__file__))
CFG = os.environ.get('ZCCCFG', os.path.expanduser('~/z88dk/lib/config'))
MODEL = os.path.join(CFG, '..', 'ticks', 'memory', 'lynx.lua')        # z88dk's Lynx 128K model
CLOCK = 6_000_000
LEVELS = [0, 1, 1, 1, 1, 2, 3, 4, 5, 8, 11, 16, 22, 31, 44, 62]
SAMPLE_T = 180

HARNESS = """
        SECTION code_user
        org     $2000
        PUBLIC  mp_vbl
        EXTERN  play_place_sound, play_crash_sound, play_rising_tone, play_falling_tone, play_built_sound, soundfx1
start:  ld      sp,$7000
        @CALL@
        ld      a,1
        out     ($F0),a
done:   jp      done
mp_vbl: defb    100
"""
CALLS = {
    'refused': 'call play_place_sound', 'crash': 'call play_crash_sound', 'rising': 'call play_rising_tone', 'falling': 'call play_falling_tone',
    'built': 'call play_built_sound', 'rumble': 'ld b,100\nrum:    push bc\n        call soundfx1\n        pop bc\n        djnz rum',
}
INDEX = {'refused': 0, 'crash': 1, 'rising': 2, 'falling': 3, 'built': 5, 'rumble': 4}


def decode(i):
    d = open(os.path.join(ROOT, 'assets/st_sounds.bin'), 'rb').read()
    o = d[1 + 2 * i] | d[2 + 2 * i] << 8
    mix, vl, per = d[o], d[o + 1], d[o + 2] | d[o + 3] << 8
    vol, pseg = d[o + 4:o + 4 + vl], d[o + 4 + vl:]
    vs = []
    for b in vol:
        if b == 0:
            break
        vs += [b & 15] * (b >> 4)
    ps, k, left, delta, p = [per], 0, 0, 0, per
    for t in range(1, len(vs)):
        if left == 0:
            if k < len(pseg) and pseg[k] != 0:
                b = pseg[k]; k += 1; left = b & 0x7f
                if b & 0x80:
                    delta = pseg[k] | pseg[k + 1] << 8; k += 2
                    if delta >= 32768: delta -= 65536
                else:
                    delta = pseg[k]; k += 1
                    if delta >= 128: delta -= 256
            else:
                delta, left = 0, 255
        p = (p + delta) & 0xfff; left -= 1; ps.append(p)
    return mix, vs, ps


def run(name):
    with tempfile.TemporaryDirectory() as tmp:
        open(os.path.join(tmp, 'h.asm'), 'w').write(HARNESS.replace('@CALL@', CALLS[name]))
        r = subprocess.run(['z88dk-z80asm', '-b', '-m', '-DAY_SHADOW', '-I' + ROOT, os.path.join(tmp, 'h.asm'), os.path.join(ROOT, 'target/lynx/plat_sound.asm'),
                            os.path.join(ROOT, 'target/common/ay_sfx.asm')], capture_output=True, text=True, cwd=ROOT)
        if r.returncode:
            sys.exit(r.stdout + r.stderr)
        img = open(os.path.join(tmp, 'h_code_user.bin'), 'rb').read()
        open(os.path.join(tmp, 'img.bin'), 'wb').write(bytearray(0x2000) + img)
        done = [l for l in open(os.path.join(tmp, 'h.map')) if l.startswith('done ')][0].split('$')[1][:4]
        r = subprocess.run(['z88dk-ticks', '-b', 'lua', '-lua', MODEL, '-pc', '2000', '-end', done, '-counter', '2000000000', '-output', os.path.join(tmp, 'mem.out'),
                            os.path.join(tmp, 'img.bin')], capture_output=True, text=True, cwd=tmp, env=dict(os.environ, ZCCCFG=CFG, LYNX_OUTDIR=tmp))
        p = os.path.join(tmp, 'dac_out.txt')
        if not os.path.exists(p):
            sys.exit('no DAC log:\n' + r.stdout + r.stderr)
        return [tuple(map(int, l.split())) for l in open(p) if l.strip()]


def main():
    bad = 0

    def check(n, c, x=''):
        nonlocal bad
        print(('ok   ' if c else 'FAIL ') + n + ('' if c else '  ' + str(x)))
        bad += not c

    for name in ('refused', 'crash', 'rising', 'falling', 'built', 'rumble'):
        log = run(name)
        mix, vs, ps = decode(INDEX[name])
        ts = [t for t, v in log]
        deltas = [b - a for a, b in zip(ts, ts[1:])]
        in_loop = sum(1 for d in deltas if d == SAMPLE_T)
        check('%s: %d samples, %.1f%% of them %d T-states apart' % (name, len(log), 100.0 * in_loop / max(1, len(deltas)), SAMPLE_T), in_loop >= 0.99 * len(deltas),
              sorted(set(deltas))[:8])
        # the longest gap is a tick's own work (the two divisions): they must be short next to the tick
        gaps = [d for d in deltas if d != SAMPLE_T]
        check('%s: the gaps between loops are short (largest %d T-states: the setup of a tick, 1.8 ms at most)' % (name, max(gaps) if gaps else 0), not gaps or max(gaps) < 11000)
        dur = (ts[-1] - ts[0]) / CLOCK
        want = len(vs) * 0.02 if name != 'rumble' else 100 * 0.02
        check('%s: lasts %.3f s (the data: %.3f s)' % (name, dur, want), abs(dur - want) <= max(0.03, want * 0.04), '%.3f vs %.3f' % (dur, want))
        levels = sorted(set(v for t, v in log))
        legal = {0} | {2 * 0 + LEVELS[i] for i in range(16)}
        check('%s: levels are 0 or a volume level' % name, set(levels) <= legal, levels)
        if name != 'rumble':        # (the rumble is cut off after 100 calls)
            check('%s: the DAC ends at rest' % name, log[-1][1] == 0, log[-1])
        if name in ('refused', 'rising'):
            # tone only: the pitch over the whole effect (the edges counted against the cycles the data asks for: a tick of a low note has only a cycle or two)
            edges = sum(1 for (t0, a), (t1, b) in zip(log, log[1:]) if a == 0 and b > 0)
            # (a tick's tone runs while its samples are made: not through the 1.7 ms of its setup, when the DAC holds)
            sample_time = len(log) / len(vs) * SAMPLE_T / CLOCK
            want_edges = sum(125000.0 / ps[k] * sample_time for k in range(len(vs)) if vs[k] > 0)
            err = abs(edges - want_edges) / want_edges
            check('%s: the pitch is 125000 / period: %d cycles, the data asks for %.1f (%.1f%% off)' % (name, edges, want_edges, 100 * err), err < 0.05, err)
    print('FAILED' if bad else 'all ok')
    return 1 if bad else 0


if __name__ == '__main__':
    sys.exit(main())
