#!/usr/bin/env python3
"""z88dk's PC-8801 disk routines (pc88_disk_write, pc88_disk_read) against a real disk unit: MAME runs the unit's own ROM.

test/pc88/disktest.c is built as a bootable disk, run in MAME with its Lua hook, and the result bytes it leaves in memory are
read back.  Needs MAME (MAME_DIR, default ~/emu/mame0283-arm64) and a rom path with the pc8801mk2sr set (PC88_ROMS); the test
is skipped without them.

  usage: test/pc88/disk.py
"""
import os
import re
import subprocess
import sys
import tempfile

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
MAME_DIR = os.environ.get('MAME_DIR', os.path.expanduser('~/emu/mame0283-arm64'))
ROMS = os.environ.get('PC88_ROMS', '')

LUA = '''
local frames = 0
local cpu = manager.machine.devices[":z80"]
local mem = cpu.spaces["program"]
local addr = tonumber(os.getenv("RESADDR"))
emu.register_frame_done(function()
  frames = frames + 1
  if frames % 100 == 0 then
    local s = ""
    for i = 0, 7 do s = s .. string.format(" %02x", mem:read_u8(addr + i)) end
    print("RESULT" .. s)
    if mem:read_u8(addr) == 0x55 or frames >= 3000 then manager.machine:exit() end
  end
end)
'''


def main():
    if not ROMS or not os.path.exists(os.path.join(MAME_DIR, 'mame')):
        print('SKIP  the disk routines (set PC88_ROMS to a MAME rom path with the pc8801mk2sr set; MAME_DIR for MAME)')
        return 0
    with tempfile.TemporaryDirectory() as tmp:
        src = os.path.join(tmp, 'disktest.c')
        open(src, 'w').write(open(os.path.join(ROOT, 'test/pc88/disktest.c')).read())
        subprocess.run(['zcc', '+pc88', '-subtype=disk', '-create-app', '-m', 'disktest.c', '-o', 'disktest.bin'], cwd=tmp,
                       check=True, capture_output=True)
        syms = {}
        for line in open(os.path.join(tmp, 'disktest.map')):
            m = re.match(r'(\S+)\s+= \$([0-9A-F]+) ;', line)
            if m:
                syms[m.group(1)] = int(m.group(2), 16)
        open(os.path.join(tmp, 'hook.lua'), 'w').write(LUA)
        out = subprocess.run([os.path.join(MAME_DIR, 'mame'), '-rompath', ROMS, 'pc8801mk2sr', '-flop1', os.path.join(tmp, 'disktest.d88'),
                              '-video', 'soft', '-window', '-nothrottle', '-seconds_to_run', '120',
                              '-autoboot_script', os.path.join(tmp, 'hook.lua'), '-skip_gameinfo'],
                             cwd=MAME_DIR, capture_output=True, text=True, env=dict(os.environ, RESADDR=str(syms['_result'])))
    rows = [l for l in out.stdout.splitlines() if l.startswith('RESULT')]
    if not rows:
        print('FAIL  MAME gave no result\n' + out.stdout[-400:] + out.stderr[-400:])
        return 1
    r = [int(x, 16) for x in rows[-1].split()[1:]]
    ok = r[0] == 0x55 and r[1] == 0 and r[2] == 0 and r[3] | r[4] << 8 == 0 and r[5] == 0 and r[6] | r[7] << 8 == 0
    print(('PASS' if ok else 'FAIL') + '  pc88_disk_write and pc88_disk_read: 40 sectors across three tracks come back as written, and the start of '
          'the program reads back as it was loaded' + ('' if ok else f'  (result bytes {r})'))
    return 0 if ok else 1


if __name__ == '__main__':
    sys.exit(main())
