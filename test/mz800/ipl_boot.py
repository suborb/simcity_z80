#!/usr/bin/env python3
"""Boots a disc image on the real MZ-800 IPL ROM (the 16 KB 9Z-504M dump) under z88dk-ticks with lib/ticks/memory/mz800.lua and checks what arrives.
The ROM is found through MZ800_ROM or ~/emu/sord/binary/binary/mz800/.  boot() and ppm() are the other tests' way in.  Run as a test it boots a 20 KB program on a disc made by appmake +mz800:
the model's MB8876 and the IPL's own code are the check of the disc layout (the header sector, the sector order, the complemented data, the side numbering, tracks on both heads).
"""
import os, subprocess, sys, tempfile

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
CFG = os.environ.get('ZCCCFG', os.path.expanduser('~/z88dk/lib/config'))
MODEL = os.path.join(CFG, '..', 'ticks', 'memory', 'mz800.lua')
ROM = os.environ.get('MZ800_ROM', os.path.expanduser('~/emu/sord/binary/binary/mz800/Sharp MZ-800 BIOS (19xx)(Sharp).bin'))


def boot(disc, cycles, snaps='', extra=None):
    tmp = tempfile.mkdtemp()
    stub = os.path.join(tmp, 'reset.bin')
    open(stub, 'wb').write(b'\x00')
    env = dict(os.environ, ZCCCFG=CFG, MZ800_ROM=ROM, MZ800_DISC=disc, MZ800_OUTDIR=tmp, MZ800_SNAP=snaps)
    env.update(extra or {})
    r = subprocess.run(['z88dk-ticks', '-b', 'lua', '-lua', MODEL, '-pc', '0', '-counter', str(cycles), '-output', os.path.join(tmp, 'mem.out'), stub],
                       capture_output=True, text=True, cwd=tmp, env=env)
    return tmp, r


def ppm(path):
    d = open(path, 'rb').read()
    hdr = d.index(b'255\n') + 4
    w = int(d.split()[1])
    return w, d[hdr:]


def multitrack():
    """A 20 KB program (five logical tracks: both heads, three cylinders) loaded by the IPL: the memory after the boot must equal the file."""
    d = tempfile.mkdtemp()
    prog = bytearray(b'\xf3\x18\xfe' + b'\x5a' * 19992)         # di; jr $; then a pattern
    for i in range(7, len(prog), 7):            # make every sector different
        prog[i] = (i // 256) & 0xff
    open(d + '/mt.bin', 'wb').write(prog)
    subprocess.check_call(['z88dk-appmake', '+mz800', '-b', d + '/mt.bin', '--org', '0x1200', '-o', d + '/mt.d88'])
    tmp = tempfile.mkdtemp()
    open(os.path.join(tmp, 'reset.bin'), 'wb').write(b'\x00')
    env = dict(os.environ, ZCCCFG=CFG, MZ800_ROM=ROM, MZ800_DISC=d + '/mt.d88', MZ800_OUTDIR=tmp)
    r = subprocess.run(['z88dk-ticks', '-b', 'lua', '-lua', MODEL, '-pc', '0', '-end', '1202', '-counter', '60000000', '-output', os.path.join(tmp, 'mem.out'),
                        os.path.join(tmp, 'reset.bin')], capture_output=True, text=True, cwd=tmp, env=env)
    mem = open(os.path.join(tmp, 'mem.out'), 'rb').read()
    log = open(os.path.join(tmp, 'fdc_log.txt')).read().splitlines()
    return prog, mem, log


def main():
    bad = 0

    def check(n, c, x=''):
        nonlocal bad
        print(('ok   ' if c else 'FAIL ') + n + ('' if c else '  ' + str(x)))
        bad += not c

    prog, mem, log = multitrack()
    reads = [l for l in log if 'read sector' in l]
    check('the IPL reads the header sector first, from head 1 of cylinder 0, then the program', 'sector 1 (track register 0, heads at 0, side 1)' in reads[0] and 'sector 2 (track register 0, heads at 0, side 1)' in reads[1], reads[:2])
    check('multi-track program: the IPL loads it all (%d bytes), memory equals the file' % len(prog), mem[0x1200:0x1200 + len(prog)] == bytes(prog), (len(mem), mem[0x1200:0x1210].hex()))
    check('it reads both heads and several cylinders: %d read commands' % len(reads), len(reads) > 2 and len({l.split('side ')[1] for l in log if 'side ' in l}) == 2, reads[:6])
    check('no controller errors', not any('ERROR' in l for l in log), [l for l in log if 'ERROR' in l][:3])
    return bad


if __name__ == '__main__':
    sys.exit(1 if main() else 0)
