#!/usr/bin/env python3
"""The boot sector of build/lynx/simcity.ldf (z88dk's lynx bootstrap.asm, made by appmake +lynx --disc) under z88dk-ticks, against the WD1793 model reading that disc image: the DOS ROM's
EXT BOOT reads the sector to an address of its own and jumps to its offset 2 with HL = that address; the bootstrap must copy itself to $CF00, read the program (as many sectors as
__DATA_END_tail needs) to $0000 and jump there.  Checked for two load addresses (one inside where the program goes, one above it): the program is in RAM as simcity.bin, the
control port is set up ($80 = 0, $82 = $08), the motor is stopped, the art after the program is not touched (it is for the game to load), and the model saw no error.
"""
import os, subprocess, sys, tempfile

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
HERE = os.path.dirname(os.path.abspath(__file__))
CFG = os.environ.get('ZCCCFG', os.path.expanduser('~/z88dk/lib/config'))
MODEL = os.path.join(CFG, '..', 'ticks', 'memory', 'lynx.lua')        # z88dk's Lynx 128K model
DISC = os.path.join(ROOT, 'build/lynx/simcity.ldf')
PROG = os.path.join(ROOT, 'build/lynx/simcity.bin')

bad = 0
def check(n, c, x=''):
    global bad
    print(('ok   ' if c else 'FAIL ') + n + ('' if c else '  ' + str(x)))
    bad += not c

disc, prog = open(DISC, 'rb').read(), open(PROG, 'rb').read()
for base in (0x4633, 0xE000):
    with tempfile.TemporaryDirectory() as tmp:
        # what the ROM leaves: HL = base + 2, the boot sector at base, run from base + 2
        stub = bytes([0x21, (base + 2) & 255, (base + 2) >> 8, 0xE9])           # ld hl,base+2 ; jp (hl)
        img = bytearray(0x10000)
        img[0x2000:0x2000 + len(stub)] = stub
        img[base:base + 512] = disc[:512]
        open(os.path.join(tmp, 'img.bin'), 'wb').write(img)
        r = subprocess.run(['z88dk-ticks', '-b', 'lua', '-lua', MODEL, '-pc', '2000', '-end', '0000', '-counter', '2000000000', '-output', os.path.join(tmp, 'mem.out'),
                            os.path.join(tmp, 'img.bin')], capture_output=True, text=True, cwd=tmp, env=dict(os.environ, ZCCCFG=CFG, LYNX_OUTDIR=tmp, LYNX_DISC=DISC, LYNX_EAGER='1'))
        out = os.path.join(tmp, 'mem.out')
        if not os.path.exists(out):
            sys.exit('no memory dump:\n' + r.stdout + r.stderr)
        mem = open(out, 'rb').read()
        check('load at $%04X: the program is in RAM from $0000 as appmake wrote it (%d bytes)' % (base, len(prog)), mem[:len(prog)] == prog,
              'first difference at %s' % next((i for i in range(len(prog)) if mem[i] != prog[i]), None))
        check('load at $%04X: the bootstrap copied itself to $CF00' % base, mem[0xCF00:0xCF00 + 512] == disc[:512] or mem[0xCF14:0xCF14 + 42] == disc[0x14:0x14 + 42])
        ports = open(os.path.join(tmp, 'ports_log.txt')).read().split()
        errs = open(os.path.join(tmp, 'fdc_errors.txt')).read().strip()
        check('load at $%04X: the control port is cleared ($80 = 00) and the user RAM selected ($82 = 08)' % base, '$80=00' in ports and '$82=08' in ports, ports[:6])
        check('load at $%04X: the motor was started and is stopped again at the end' % base, [p for p in ports if p.startswith('$58=')][0] == '$58=00' and [p for p in ports if p.startswith('$58=')][-1] == '$58=08')
        check('load at $%04X: the model saw no error' % base, errs == '', errs)
print('FAILED' if bad else 'all ok')
sys.exit(bad)
