#!/usr/bin/env python3
"""The FP-1100 floppy driver (fp1100_disk_read/write of z88dk's fp1100 library) under z88dk-ticks, against the uPD765A pack model in fdc_model.lua.

Reads sectors across a track boundary and a seek, writes sectors and reads the written values back out of the model, and checks the error
paths (no pack, a sector that does not exist).  What it cannot check is the timing: the model has no clock.
"""
import os, random, subprocess, sys, tempfile

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
HERE = os.path.dirname(os.path.abspath(__file__))


def pattern(c, h, i, n):
    return (c * 7 + h * 13 + i * 29 + n) & 0xff


def run(mode, unit, track, sector, count, pack_slot=5, preload=None, c_entry=False):
    with tempfile.TemporaryDirectory() as tmp:
        src = open(os.path.join(HERE, 'disk_harness_c.asm.in' if c_entry else 'disk_harness.asm.in')).read()
        for k, v in dict(MODE=mode, UNIT=unit, TRACK=track, SECTOR=sector, COUNT=count, ENTRY='_fp1100_disk_write' if mode else '_fp1100_disk_read').items():
            src = src.replace('@%s@' % k, str(v))
        open(os.path.join(tmp, 'h.asm'), 'w').write(src)
        # (assembled from the repository root so the INCLUDE path works)
        r = subprocess.run(['z88dk-z80asm', '-b', '-m', '-I' + ROOT, '-L' + os.environ.get('ZCCCFG', os.path.expanduser('~/z88dk/lib/config/')) + '/../clibs', '-lfp1100_clib', os.path.join(tmp, 'h.asm')], capture_output=True, text=True, cwd=ROOT)
        if r.returncode:
            sys.exit(r.stdout + r.stderr)
        img = b''.join(open(os.path.join(tmp, f), 'rb').read() for f in ('h_code_user.bin', 'h_code_clib.bin') if os.path.exists(os.path.join(tmp, f)))
        full = bytearray(0x2000) + img          # loaded at $2000
        open(os.path.join(tmp, 'img.bin'), 'wb').write(full)
        env = dict(os.environ, PACK_SLOT=str(pack_slot))
        out = os.path.join(tmp, 'mem.out')
        r = subprocess.run(['z88dk-ticks', '-lua', os.path.join(HERE, 'fdc_model.lua'), '-pc', '2000', '-end', '2' + '000', '-counter', '3000000', '-output', out, os.path.join(tmp, 'img.bin')],
                           capture_output=True, text=True, cwd=tmp, env=env)
        mem = open(out, 'rb').read() if os.path.exists(out) else b''
        written = {}
        p = os.path.join(tmp, 'disk_out.txt')
        if os.path.exists(p):
            for line in open(p):
                c, h, i, hx = line.split()
                written[(int(c), int(h), int(i))] = bytes.fromhex(hx)
        log = open(os.path.join(tmp, 'fdc_log.txt')).read() if os.path.exists(os.path.join(tmp, 'fdc_log.txt')) else ''
        return mem, written, log, r.stdout + r.stderr


def main():
    bad = 0

    def check(name, cond, extra=''):
        nonlocal bad
        print(('ok   ' if cond else 'FAIL ') + name + ('  ' + extra if (extra and not cond) else ''))
        bad += not cond

    # the C entries give the same answers (a read across a track, a write, a sector that does not exist)
    for mode, unit, track, sector, count in ((0, 0, 5, 10, 20), (1, 0, 9, 3, 2), (0, 0, 5, 20, 1)):
        a = run(mode, unit, track, sector, count)
        b = run(mode, unit, track, sector, count, c_entry=True)
        check('C entry mode %d track %d sector %d x%d = the register entry' % (mode, track, sector, count),
              a[0][0x3F00:0x3F02] == b[0][0x3F00:0x3F02] and a[0][0x4000:0x4000 + 256 * count] == b[0][0x4000:0x4000 + 256 * count] and a[1] == b[1],
              'hl %s vs %s' % (a[0][0x3F00:0x3F02].hex(), b[0][0x3F00:0x3F02].hex()))

    # read 20 sectors from track 5 (cylinder 2, side 1) sector 10: 7 sectors on this track, then track 6, 7
    mem, w, log, o = run(0, 0, 5, 10, 20)
    if not mem:
        sys.exit('no memory dump:\n' + o)
    res = mem[0x3F00] | mem[0x3F01] << 8
    check('read 20 sectors across tracks: result 0', res == 0, 'hl=%d err=%d\n%s' % (res, mem[0x3F02], log[-600:]))
    ok = True
    t, s = 5, 10
    for n in range(20):
        exp = bytes(pattern(t >> 1, t & 1, s, i) for i in range(256))
        if mem[0x4000 + n * 256:0x4100 + n * 256] != exp:
            ok = False
            print('   sector', n, 'track', t, 'id', s, 'differs')
        s += 1
        if s > 16:
            s, t = 1, t + 1
    check('read data right', ok)
    check('read: a recalibrate and two seeks (cylinders 2 and 3)', log.count('cmd 0f') == 2 and log.count('cmd 07') == 1, log)
    check('no model errors', 'ERROR' not in log, log)

    # write 3 sectors, track 0 sector 15..16 and track 1 sector 1
    mem, w, log, o = run(1, 0, 0, 15, 3)
    res = mem[0x3F00] | mem[0x3F01] << 8
    check('write 3 sectors: result 0', res == 0, 'hl=%d err=%d\n%s' % (res, mem[0x3F02], log[-600:]))
    ok = True
    for n, (c, h, i) in enumerate([(0, 0, 15), (0, 0, 16), (0, 1, 1)]):
        got = w.get((c, h, i))
        ok = ok and got == mem[0x4000 + n * 256:0x4100 + n * 256]
    check('written sectors reach the right places', ok, str(sorted(w)))
    check('no model errors (write)', 'ERROR' not in log, log)

    # no pack in any slot
    mem, w, log, o = run(0, 0, 0, 1, 1, pack_slot=9)
    res = mem[0x3F00] | mem[0x3F01] << 8
    check('no pack: error 1', res == 1, 'hl=%d' % res)

    # a sector that does not exist (id 17 is made by running past 16 only: ask for count 2 from sector 16 of track 39*2+1 = the last track, then the next does not exist)
    mem, w, log, o = run(0, 0, 79, 16, 2)
    res = mem[0x3F00] | mem[0x3F01] << 8
    check('past the last track: error 3 or 4', res in (3, 4), 'hl=%d' % res)
    print('FAILED' if bad else 'all ok')
    return 1 if bad else 0


if __name__ == '__main__':
    sys.exit(main())
