#!/usr/bin/env python3
"""The Aquarius+ file lister (target/aqplus/aq_files.asm) under z88dk-ticks, with the ESP32's answers scripted.

The ESP routines are stubs: they log the commands and bytes sent, and hand out the bytes of the script (the answers to OPENDIR, READDIR... as
the firmware gives them: the result, date, time, attributes, a 32 bit size and the NUL terminated name).  Python then looks at the names, the
count and what was sent.

  usage: test/aqplus/files.py
"""
import os
import re
import subprocess
import sys
import tempfile

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
CITY = 31 + 96 * 96
ENTRY = 25
NAMES = 0x6000

HARNESS = '''        SECTION code_user
        org     $2000
        EXTERN  _plat_file_list
        PUBLIC  __esp_send_cmd, __esp_send_byte, __esp_read_byte
start:  ld      sp,$7000
        ld      hl,%NAMES%
        push    hl
        call    _plat_file_list
        pop     de
        ld      (count),hl
fin:    halt
__esp_send_cmd:
        push    hl
        ld      hl,(lp)
        ld      (hl),$C0
        inc     hl
        ld      (hl),a
        inc     hl
        ld      (lp),hl
        pop     hl
        ret
__esp_send_byte:
        push    hl
        ld      hl,(lp)
        ld      (hl),$B0
        inc     hl
        ld      (hl),a
        inc     hl
        ld      (lp),hl
        pop     hl
        ret
__esp_read_byte:
        push    hl
        ld      hl,(script)
        ld      a,(hl)
        inc     hl
        ld      (script),hl
        pop     hl
        ret
lp:     defw    log
script: defw    stream
count:  defw    0
stream: %STREAM%
        defs    16
log:    defs    256
'''


def entry(name, size=CITY, attr=0):
    return [0, 1, 2, 3, 4, attr] + list(size.to_bytes(4, 'little')) + list(name.encode()) + [0]


def run(title, files, want, extra_sent=None):
    stream = [5]                                      # the directory descriptor
    for f in files:
        stream += entry(*f) if isinstance(f, tuple) else entry(f)
    stream += [0xFC, 0]                               # ERR_EOF, and the answer to CLOSEDIR
    with tempfile.TemporaryDirectory() as tmp:
        src = HARNESS.replace('%NAMES%', str(NAMES)).replace('%STREAM%', 'defb ' + ','.join(map(str, stream)))
        open(os.path.join(tmp, 'h.asm'), 'w').write(src)
        out = subprocess.run(['z88dk-z80asm', '-b', '-m', 'h.asm', os.path.join(ROOT, 'target/aqplus/aq_files.asm')], cwd=tmp, capture_output=True, text=True)
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
        subprocess.run(['z88dk-ticks', '-pc', '2000', '-end', f'{syms["fin"]:x}', '-counter', '10000000', '-output', 'mem.out', 'img.bin'],
                       cwd=tmp, capture_output=True)
        mem = open(os.path.join(tmp, 'mem.out'), 'rb').read()
    n = mem[syms['count']]
    got = [bytes(mem[NAMES + ENTRY * i:NAMES + ENTRY * (i + 1)]).split(b'\0')[0].decode() for i in range(n)]
    log = mem[syms['log']:syms['log'] + 64]
    sent = []
    for i in range(0, 64, 2):
        if log[i] in (0xC0, 0xB0):
            sent.append(('cmd' if log[i] == 0xC0 else 'byte', log[i + 1]))
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
