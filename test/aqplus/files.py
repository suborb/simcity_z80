#!/usr/bin/env python3
"""The Aquarius+ file lister (target/aqplus/aq_files.asm) under z88dk-ticks, with the ESP32's answers scripted.

The test assembles the real ESP port routines. Lua models the ESP32 control and data ports, logs writes, and hands out the scripted answers to OPENDIR, READDIR... as
the firmware gives them: result, date, time, attributes, a 32 bit size and a NUL-terminated name. Python checks the names, count and sent bytes.

  usage: test/aqplus/files.py
"""
import os
import re
import shutil
import subprocess
import sys
import tempfile

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
Z88DK_ROOT = os.path.abspath(os.path.join(os.environ.get('ZCCCFG', os.path.expanduser('~/z88dk/lib/config')), '../..'))
ESP = os.path.join(Z88DK_ROOT, 'libsrc/target/aquarius/fcntl/esp.asm')
Z88DK_LIB = os.path.join(Z88DK_ROOT, 'lib')
CITY = 31 + 96 * 96
ENTRY = 25
NAMES = 0x6000

HARNESS = '''        SECTION code_user
        org     $2000
        EXTERN  _plat_file_list
start:  ld      sp,$7000
        ld      hl,%NAMES%
        push    hl
        call    _plat_file_list
        pop     de
        ld      (count),hl
fin:    halt
count:  defw    0
'''


LUA = '''local stream = {%STREAM%}
local next_byte = 1
local command = false
local log = assert(io.open("io.log", "w"))

function io_in(port, cycles)
    port = port & 0xff
    if port == 0xf4 then return 1 end -- ESP ready for writes and reads
    if port == 0xf5 then
        local value = stream[next_byte]
        assert(value ~= nil, "ESP data read past scripted answer")
        next_byte = next_byte + 1
        return value
    end
    return -1
end

function io_out(port, value, cycles)
    port = port & 0xff
    if port == 0xf4 then
        assert(value == 0x83, "unexpected ESP control write")
        command = true
        return 0
    end
    if port == 0xf5 then
        log:write(command and "cmd " or "byte ", value, "\\n")
        log:flush()
        command = false
        return 0
    end
    return -1
end
'''

def entry(name, size=CITY, attr=0):
    return [0, 1, 2, 3, 4, attr] + list(size.to_bytes(4, 'little')) + list(name.encode()) + [0]


def run(title, files, want, extra_sent=None):
    stream = [5]                                      # the directory descriptor
    for f in files:
        stream += entry(*f) if isinstance(f, tuple) else entry(f)
    stream += [0xFC, 0]                               # ERR_EOF, and the answer to CLOSEDIR
    with tempfile.TemporaryDirectory() as tmp:
        src = HARNESS.replace('%NAMES%', str(NAMES))
        lua = LUA.replace('%STREAM%', ','.join(map(str, stream)))
        open(os.path.join(tmp, 'h.asm'), 'w').write(src)
        open(os.path.join(tmp, 'device.lua'), 'w').write(lua)
        aq_files = os.path.join(tmp, 'aq_files.asm')
        esp = os.path.join(tmp, 'esp.asm')
        shutil.copyfile(os.path.join(ROOT, 'target/aqplus/aq_files.asm'), aq_files)
        shutil.copyfile(ESP, esp)
        out = subprocess.run(['z88dk-z80asm', '-b', '-m', '-I' + Z88DK_LIB, 'h.asm', aq_files, esp], cwd=tmp, capture_output=True, text=True)
        if out.returncode or out.stderr.strip():
            print(out.stdout + out.stderr)
            print('FAIL  ' + title + ': does not assemble')
            return False
        syms = {}
        for line in open(os.path.join(tmp, 'h.map')):
            m = re.match(r'(\S+)\s+= \$([0-9A-F]+) ;', line)
            if m:
                syms[m.group(1)] = int(m.group(2), 16)
        img = bytearray(65536)
        for sec in ('code_user',):
            b = open(os.path.join(tmp, f'h_{sec}.bin'), 'rb').read()
            img[syms[f'__{sec}_head']:syms[f'__{sec}_head'] + len(b)] = b
        open(os.path.join(tmp, 'img.bin'), 'wb').write(img)
        ticks = subprocess.run(['z88dk-ticks', '-pc', '2000', '-end', f'{syms["fin"]:x}', '-counter', '10000000', '-lua', 'device.lua', '-output', 'mem.out', 'img.bin'],
                               cwd=tmp, capture_output=True, text=True)
        if ticks.returncode:
            print(ticks.stdout + ticks.stderr)
            print('FAIL  ' + title + ': ticks could not run the Lua ESP model')
            return False
        mem = open(os.path.join(tmp, 'mem.out'), 'rb').read()
        io_log = open(os.path.join(tmp, 'io.log')).read().splitlines()
    n = mem[syms['count']]
    got = [bytes(mem[NAMES + ENTRY * i:NAMES + ENTRY * (i + 1)]).split(b'\0')[0].decode() for i in range(n)]
    sent = [(kind, int(value)) for kind, value in (line.split() for line in io_log)]
    ok = got == want
    msgs = [] if ok else [f'listed {got}, wanted {want}']
    if sent[:3] != [('cmd', 0x16), ('byte', 0), ('cmd', 0x18)] or ('cmd', 0x17) not in sent:
        ok = False
        msgs.append(f'sent {sent}')
    if ok and sent[-2:] != [('cmd', 0x17), ('byte', 5)]:
        ok = False
        msgs.append(f'the directory was not closed last: {sent[-4:]}')
    print(('PASS' if ok else 'FAIL') + '  ' + title + ('' if ok else '  ' + '; '.join(msgs)))
    return ok


def main():
    ok = True
    ok &= run('no files', [], [])
    ok &= run('city files are listed in order', ['ALPHA', 'beta.sav', 'C'], ['ALPHA', 'beta.sav', 'C'])
    ok &= run('files of other sizes, directories and names too long are left out',
              [('NOTES.TXT', 500), 'KEEP', ('SUBDIR', CITY, 1), ('NEARLY', CITY + 1), ('THIS_NAME_IS_25_CHARS_LONG_', CITY), ('FITS_IN_24_CHARACTERS_', CITY), ('BIG', CITY + 65536)],
              ['KEEP', 'FITS_IN_24_CHARACTERS_'])
    ok &= run('a name of exactly 24 characters fits', [('X' * 24, CITY), ('Y' * 25, CITY), 'Z'], ['X' * 24, 'Z'])
    many = [f'F{i}' for i in range(12)]
    ok &= run('at most eight, and the directory is closed', many, many[:8])
    return 0 if ok else 1


if __name__ == '__main__':
    sys.exit(main())
