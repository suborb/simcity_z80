#!/usr/bin/env python3
"""mz800_disk_rw (libsrc/target/mz800/mz800/mz800_disk_rw.asm, built into a program by zcc +mz800) against the ticks MZ-800 model's MB8876 and a D88 disc built by
appmake: reads by logical sector over both heads and several cylinders, a write and the read back, and where the write landed (cylinder, head, record).
"""
import os, re, subprocess, sys, tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
CFG = os.environ.get('ZCCCFG', os.path.expanduser('~/z88dk/lib/config'))
MODEL = os.path.join(CFG, '..', 'ticks', 'memory', 'mz800.lua')


def main():
    bad = 0

    def check(n, c, x=''):
        nonlocal bad
        print(('ok   ' if c else 'FAIL ') + n + ('' if c else '  ' + str(x)))
        bad += not c

    d = tempfile.mkdtemp()
    env = dict(os.environ, ZCCCFG=CFG)
    subprocess.check_call(['zcc', '+mz800', '-m', '-o', d + '/dt.bin', HERE + '/disk_test.c'], env=env, cwd=d)
    sym = {m.group(1): int(m.group(2), 16) for m in re.finditer(r'^(\w+)\s+= \$([0-9A-F]+)', open(d + '/dt.map').read(), re.M)}
    # the disc: a 20 KB pattern program, sector k of it is logical sector 1 + k
    prog = bytearray((i * 7 + (i >> 8) * 13 + 5) & 0xff for i in range(20000))
    open(d + '/p.bin', 'wb').write(prog)
    subprocess.check_call(['z88dk-appmake', '+mz800', '-b', d + '/p.bin', '--org', '0x2000', '-o', d + '/p.d88'], env=env)
    code = open(d + '/dt.bin', 'rb').read()
    run = subprocess.run(['z88dk-ticks', '-b', 'lua', '-lua', MODEL, '-l', '0x2000', '-pc', '0x2000', '-counter', '120000000', '-output', d + '/mem.out', d + '/dt.bin'],
                         capture_output=True, text=True, cwd=d, env=dict(env, MZ800_DISC=d + '/p.d88', MZ800_OUTDIR=d))
    mem = open(d + '/mem.out', 'rb').read()
    rc = [int.from_bytes(mem[sym['_rc'] + 2 * i:sym['_rc'] + 2 * i + 2], 'little') for i in range(10)]
    buf = mem[sym['_buf']:sym['_buf'] + 9 * 256]
    check('finished', mem[sym['_finished']] == 1, run.stderr[-300:])
    check('all ten transfers return 0', rc == [0] * 10, rc)
    for i, s in enumerate([0, 1, 15, 16, 17, 33, 79, 80]):
        got = buf[i * 256:(i + 1) * 256]
        if s == 0:
            want = bytes([3]) + b'IPLPRO' + b'P' + b'\r'
            check('logical sector 0 is the IPL header', got[:9] == want, got[:12])
        elif s <= 79:
            want = bytes(prog[(s - 1) * 256:s * 256]).ljust(256, b'\0')
            check('logical sector %d (cylinder %d, side %d, ID %d) is program sector %d' % (s, s // 32, s // 16 % 2, s % 16 + 1, s - 1), got == want)
        else:
            check('logical sector 80 is past the program: blank', got == bytes([0xe5]) * 256 or got == bytes(256), got[:4].hex())
    pat = bytes((i * 3 + 1) & 0xff for i in range(256))
    check('the written sector reads back', buf[8 * 256:9 * 256] == pat)
    out = open(d + '/disk_out.txt').read().split()
    check('the write went to cylinder 6, head 1, record 9 (logical sector 200: track 12, side 0 = head 1)', out[:3] == ['6', '1', '9'] and bytes.fromhex(out[3]) == pat, out[:3])
    return bad


if __name__ == '__main__':
    sys.exit(1 if main() else 0)
