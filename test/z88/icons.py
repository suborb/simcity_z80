#!/usr/bin/env python3
"""Checks the Z88's tool icons (plat_icons in target/z88/plat_z88.asm): which are reversed (the selected tool) and which are greyed out
(the tools that cost more than the money).

The routine is cut out of the file and assembled with stubs of OZ's string output and the engine's money, and run under z88dk-ticks for
a number of sums of money and every selected tool; the strings it sends are compared with a model written here from the description:
two strings, one for each row of the icons, each the cursor position and then 14 icons of two user defined characters, with the toggles
for reverse video (1, 'R') around the selected one and grey (1, 'G') around those that cost more than the money.
"""
import os
import subprocess
import sys
import tempfile

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
COSTS = [1, 10, 5, 20, 10, 100, 100, 100, 500, 500, 3000, 3000, 5000, 10000]
TEXT_X = 2


def model(money, selected):
    out = b''
    for row in range(2):
        s = bytes([1, ord('3'), ord('@'), 32 + 1 + TEXT_X, 32 + 1 + 3 + row])
        for i in range(14):
            rev = i == selected
            grey = money < COSTS[i]
            s += b'\x01R' * rev + b'\x01G' * grey
            for c in range(2):
                s += bytes([1, ord('2'), ord('?'), 64 + i * 4 + row * 2 + c])
            s += b'\x01G' * grey + b'\x01R' * rev
        out += s + b'\x00'
    return out


def main():
    text = open(os.path.join(ROOT, 'target/z88/plat_z88.asm')).read()
    block = text[text.index('; void plat_demand'):]
    moneys = [0, 1, 4, 5, 9, 10, 19, 20, 99, 100, 499, 500, 2999, 3000, 4999, 5000, 9999, 10000, 65535, 65536, 0x1FFFF, 0xFFFFFF]
    cases = [(m, sel) for m in moneys for sel in (0, 5, 13)] + [(10000, s) for s in range(14)]
    calls = ''
    for m, sel in cases:
        calls += f'''        ld      hl,{m & 0xFFFF}
        ld      (_V_money),hl
        ld      a,{m >> 16}
        ld      (_V_money + 2),a
        ld      hl,{sel}
        push    hl
        call    _plat_icons
        pop     hl
'''
    src = f'''        org     $0000
        ld      sp,$9800
        ld      hl,$A000
        ld      (outp),hl
{calls}
done:   jr      done
outp:   defw    0
_V_money:       defb 0, 0, 0
_icons_ok:      defb 1
_define_icons:  ret
_z88_sop:
        ld      de,(outp)
cp_loop:
        ld      a,(hl)
        ld      (de),a
        inc     hl
        inc     de
        or      a
        jr      nz,cp_loop
        ld      (outp),de
        ret
{block}
'''
    with tempfile.TemporaryDirectory() as tmp:
        open(os.path.join(tmp, 't.asm'), 'w').write(src)
        r = subprocess.run(['z88dk-z80asm', '-b', '-m', os.path.join(tmp, 't.asm')], capture_output=True, text=True, cwd=tmp)
        if r.returncode:
            print(r.stdout + r.stderr)
            print('FAIL  the routine does not assemble')
            return 1
        sym = {}
        for line in open(os.path.join(tmp, 't.map')):
            parts = line.split()
            if len(parts) >= 3 and parts[1] == '=':
                sym[parts[0]] = int(parts[2].lstrip('$'), 16)
        subprocess.run(['z88dk-ticks', os.path.join(tmp, 't.bin'), '-end', f'{sym["done"]:x}', '-counter', '200000000', '-output', os.path.join(tmp, 'o.bin')],
                       capture_output=True)
        mem = open(os.path.join(tmp, 'o.bin'), 'rb').read()
        at, bad = 0xA000, []
        for case in cases:
            want = model(*case)
            got = mem[at:at + len(want)]
            if got != want:
                bad.append((case, got, want))
            at += len(want)
    for case, got, want in bad[:2]:
        print(f'  {case}: got {got!r}, wanted {want!r}')
    print(('PASS' if not bad else 'FAIL') + f'  plat_icons: {len(cases)} sums of money and selected tools: the reverse and grey toggles equal the model')
    return 1 if bad else 0


if __name__ == '__main__':
    sys.exit(main())
