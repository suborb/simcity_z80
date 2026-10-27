#!/usr/bin/env python3
"""The Next's engine bank (PORTING.md "a larger map"): the code in BANK_6 runs with $4000 to $7FFF mapped to the bank, so an address in that range that is
past the end of the bank's code is the program's own, which is not there while the bank is.  This disassembles the bank (z88dk-dis) and lists every
instruction whose 16 bit operand is such an address: a call or jump to it, a load of it or from it.  Each is a bug (or a table the disassembler took for code,
which the symbol it names will show).  Also an operand in the bank's own range that is no symbol of the bank's but is a program symbol's address.  Exit status 1 if there are any.

    python3 tools/check_bank_refs.py [build/zxn/simcity]"""
import os
import re
import subprocess
import sys

base = sys.argv[1] if len(sys.argv) > 1 else 'build/zxn/simcity'
syms, inbank = {}, set()
for line in open(base + '.map'):
    m = re.match(r'^(\S+)\s*= \$([0-9A-Fa-f]+) ; addr, \w+, [^,]*, [^,]*, ([^,]+),', line)
    if m and m.group(3) == 'BANK_6':
        inbank.add(int(m.group(2), 16) & 0xFFFF)
    elif m and int(m.group(2), 16) < 0x10000:
        syms.setdefault(int(m.group(2), 16), []).append(m.group(1))
size = os.path.getsize(base + '_BANK_6.bin')
end = 0x4000 + size
dis = subprocess.run(['z88dk-dis', '-o', '0x4000', base + '_BANK_6.bin'], capture_output=True, text=True).stdout
# opcodes (first byte, or ED + second) followed by a 16 bit address
ABS = {0xC3, 0xCD, 0xC2, 0xCA, 0xD2, 0xDA, 0xE2, 0xEA, 0xF2, 0xFA, 0xC4, 0xCC, 0xD4, 0xDC, 0xE4, 0xEC, 0xF4, 0xFC,
       0x01, 0x11, 0x21, 0x31, 0x22, 0x2A, 0x32, 0x3A}
ED = {0x43, 0x4B, 0x53, 0x5B, 0x73, 0x7B}
found = {}
for line in dis.splitlines():
    m = re.search(r';\[([0-9a-f]{4})\]((?: [0-9a-f]{2})+)', line)
    if not m:
        continue
    b = [int(x, 16) for x in m.group(2).split()]
    if b[0] in (0xDD, 0xFD) and len(b) >= 4 and b[1] in (0x21, 0x22, 0x2A):
        b = b[1:]
    elif b[0] == 0xED and len(b) == 4 and b[1] in ED:
        b = [b[0]] + b[2:]
    elif b[0] in ABS and len(b) == 3:
        pass
    else:
        continue
    if len(b) != 3:
        continue
    t = b[1] | b[2] << 8
    # past the bank's code, or inside it at an address that is a program symbol and no symbol of the bank's (a call to the program's routine that happens
    # to be at the same address): both are the program's
    if end <= t < 0x8000 or (0x4000 <= t < end and t in syms and t not in inbank):
        found.setdefault(t, []).append(line.split(';')[0].strip())
for t, lines in sorted(found.items()):
    print(f'${t:04X} {"/".join(syms.get(t, ["?"]))[:60]}: {len(lines)}x, e.g. {lines[0]}')
print(('FAIL' if found else 'PASS') + f'  the engine bank (${0x4000:04X}-${end - 1:04X}) refers to {len(found)} addresses in ${end:04X}-$7FFF')
sys.exit(1 if found else 0)
