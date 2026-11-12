#!/usr/bin/env python3
"""The game's sound on the ticks MZ-800 model's SN76489 log (MZ800_PORTLOG: every write to $F2): the chip is silenced at start, a refused tool (Space with the cursor where nothing can be built) sounds
an effect, and its ticks come about every 20 ms: the writes are in groups of five (tone latch, tone high bits, the volume, the noise, its volume), the bytes are valid SN76489 commands, and they are
20 ms apart (71683 cycles) however the game's frames fall.  About 15 s.
"""
import os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import ipl_boot

ROOT = ipl_boot.ROOT
DISC = os.path.join(ROOT, 'build/mz800/simcity.d88')
M = 1000000


def key(at, name, hold=400000):
    return '%d:%s:1,%d:%s:0' % (at, name, at + hold, name)


def main():
    bad = 0

    def check(n, c, x=''):
        nonlocal bad
        print(('ok   ' if c else 'FAIL ') + n + ('' if c else '  ' + str(x)))
        bad += not c

    keys = [key(30 * M, '1')] + [key((95 + 4 * i) * M, 'space') for i in range(6)]
    tmp, r = ipl_boot.boot(DISC, 130 * M, '', {'MZ800_KEYS': ','.join(keys), 'MZ800_PORTLOG': '1'})
    w = [(int(l.split()[0]), int(l.split('$f2,$')[1], 16)) for l in open(os.path.join(tmp, 'ports.txt')).read().splitlines() if '$f2' in l]
    check('the chip is silenced at start: all four volumes off', [b for t, b in w[:4]] == [0x9F, 0xBF, 0xDF, 0xFF], w[:4])
    rest = w[4:]
    check('sound is written (%d writes after the start)' % len(rest), len(rest) >= 10 and len(rest) % 5 == 0, len(rest))
    groups = [rest[i:i + 5] for i in range(0, len(rest) - len(rest) % 5, 5)]
    ok = all((g[0][1] & 0xF0) == 0x80 and g[1][1] < 0x40 and (g[2][1] & 0xF0) == 0x90 and g[3][1] == 0xE4 and (g[4][1] & 0xF0) == 0xF0 for g in groups)
    check('each tick is tone latch, tone high bits, volume, noise control, noise volume', ok, groups[:2])
    times = [g[0][0] for g in groups]
    runs = [[times[0]]]
    for x in times[1:]:
        (runs[-1].append(x) if x - runs[-1][-1] < 600000 else runs.append([x]))
    ends = [g for g in groups[:-1] if True]
    runs = [r_ for r_ in runs if len(r_) >= 10]
    spacing = sum(r_[-1] - r_[0] for r_ in runs) / sum(len(r_) - 1 for r_ in runs)
    check('%d effects of 10 or more ticks, 20 ms apart on average (71683 cycles): measured %d' % (len(runs), spacing), len(runs) >= 4 and 0.85 * 71683 < spacing < 1.05 * 71683, [len(r_) for r_ in runs])
    last = groups[-1]
    check('the last tick of the run is silent (tone volume $9F, noise volume $FF)', last[2][1] == 0x9F and last[4][1] == 0xFF, [hex(b) for t, b in last])
    return bad


if __name__ == '__main__':
    sys.exit(1 if main() else 0)
