#!/usr/bin/env python3
"""plat_file_save / plat_file_load / plat_file_list (target/fp1100/plat_fp1100_files.asm) over the pack model, with the real driver: a round trip of a city with a
map of 9000 bytes, a second city, a missing name and the list."""
import os, subprocess, sys, tempfile
ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
HERE = os.path.dirname(os.path.abspath(__file__))
with tempfile.TemporaryDirectory() as tmp:
    src = open(os.path.join(HERE, 'files_harness.asm')).read()
    open(os.path.join(tmp, 'h.asm'), 'w').write(src)
    r = subprocess.run(['z88dk-z80asm', '-b', '-m', '-I' + ROOT, os.path.join(tmp, 'h.asm'), os.path.join(ROOT, 'target/fp1100/plat_fp1100_files.asm'), '-L' + os.environ.get('ZCCCFG', os.path.expanduser('~/z88dk/lib/config/')) + '/../clibs', '-lfp1100_clib'], capture_output=True, text=True, cwd=ROOT)
    if r.returncode:
        sys.exit(r.stdout + r.stderr)
    img = b''.join(open(os.path.join(tmp, f), 'rb').read() for f in ('h_code_user.bin', 'h_code_clib.bin') if os.path.exists(os.path.join(tmp, f)))
    open(os.path.join(tmp, 'img.bin'), 'wb').write(bytes(0x2000) + img)
    out = os.path.join(tmp, 'mem.out')
    r = subprocess.run(['z88dk-ticks', '-lua', os.path.join(HERE, 'fdc_model.lua'), '-pc', '2000', '-end', '2000', '-counter', '400000000', '-output', out, os.path.join(tmp, 'img.bin')],
                       capture_output=True, text=True, cwd=tmp, env=dict(os.environ, PACK_SLOT='5'))
    mem = open(out, 'rb').read()
    log = open(os.path.join(tmp, 'fdc_log.txt')).read() if os.path.exists(os.path.join(tmp, 'fdc_log.txt')) else ''
w = lambda a: mem[a] | mem[a + 1] << 8
bad = 0
def check(n, c, x=''):
    global bad
    print(('ok   ' if c else 'FAIL ') + n + ('' if c else '  ' + str(x)))
    bad += not c
check('save MYCITY returns 0', w(0x7F00) == 0, w(0x7F00))
check('save OTHER returns 0', w(0x7F02) == 0, w(0x7F02))
check('load MYCITY returns 0', w(0x7F04) == 0, w(0x7F04))
check('header block back (OTHER was saved last, so its key is at $8000: compare the rest)', mem[0xC00C:0xC064] == mem[0x800C:0x8064] and mem[0xC000:0xC00C] == b'MYCITY      ')
check('map back (9000 bytes)', mem[0xD000:0xD000 + 9000] == mem[0x9000:0x9000 + 9000])
check('load of a missing name returns 1', w(0x7F06) == 1, w(0x7F06))
n = w(0x7F08)
names = [bytes(mem[0x7800 + 13 * i:0x7800 + 13 * i + 13]).split(b'\0')[0] for i in range(n)]
check('list: MYCITY and OTHER', names == [b'MYCITY', b'OTHER'], (n, names))
check('no model errors', 'ERROR' not in log, log[-400:])
print('FAILED' if bad else 'all ok')
sys.exit(bad)
