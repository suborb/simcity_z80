#!/usr/bin/env python3
"""Checks the Z88's demand indicator (plat_demand in target/z88/plat_z88.asm) for every level, -27 to 27.

The routine is cut out of the file and assembled with a stub of OZ's string output (it copies the string to a buffer) and run under
z88dk-ticks.  The model is written here from the description: the letter, then three cells to the left of the zero mark, the mark and
three to the right, between a - and a +; the level is 0 to 18 pixels each side (1.5 zones a pixel, rounded up, so any demand shows); a cell with no bar is the track; a cell is 6 pixels: a
bar of 1 to 5 pixels from its left edge is a character, a full cell is a space in reverse video, and a bar to the left is the bar of
the other 6 - n pixels in reverse video.
"""
import os
import subprocess
import sys
import tempfile

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
FIRST = 120
TEXT_X = 2


def model(col, row, name, level):
    total = (abs(level) * 2 + 1) // 3
    s = bytes([1, ord('3'), ord('@'), 32 + 1 + TEXT_X + col, 32 + 1 + row, ord(name)]) + b'-'
    for i in range(7):
        if i == 3:
            s += bytes([1, ord('2'), ord('?'), FIRST])        # the zero mark
            continue
        left = i < 3
        before = 6 * ((2 - i) if left else (i - 4))
        px = min(6, max(0, total - before))
        if px and left == (level < 0):
            if left:
                px = 6 - px                              # the bar of the rest, in reverse
                s += b'\x01R' + (b' ' if px == 0 else bytes([1, ord('2'), ord('?'), FIRST + px])) + b'\x01R'
            elif px == 6:
                s += b'\x01R \x01R'
            else:
                s += bytes([1, ord('2'), ord('?'), FIRST + px])
        else:
            s += bytes([1, ord('2'), ord('?'), FIRST + 6])        # the track
    return s + b'+'


def main():
    text = open(os.path.join(ROOT, 'target/z88/plat_z88.asm')).read()
    a = text.index('; void plat_demand')
    block = text[a:text.index('; void plat_icons')]
    cases = [(c, r, n, lv) for lv in range(-27, 28) for (c, r, n) in ((0, 1, 'R'), (10, 1, 'C'), (20, 2, 'I'))]
    calls = ''
    for c, r, n, lv in cases:
        calls += f'''        ld      hl,{c}
        push    hl
        ld      hl,{r}
        push    hl
        ld      hl,{ord(n)}
        push    hl
        ld      hl,{lv & 0xFFFF}
        push    hl
        call    _plat_demand
        pop     hl
        pop     hl
        pop     hl
        pop     hl
'''
    src = f'''        org     $0000
        ld      sp,$F000
        ld      hl,$A000
        ld      (outp),hl
{calls}
done:   jr      done
outp:   defw    0
_icons_ok:      defb 1
_define_icons:  ret
; the stub of GN_Sop: copy the string at HL to the next place in the output, with a 0 after it
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
        defc    ASMPC_ = 0
{block}
'''
    ok = True
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
        subprocess.run(['z88dk-ticks', os.path.join(tmp, 't.bin'), '-end', f'{sym["done"]:x}', '-counter', '50000000', '-output', os.path.join(tmp, 'o.bin')],
                       capture_output=True)
        mem = open(os.path.join(tmp, 'o.bin'), 'rb').read()
        at = 0xA000
        bad = []
        for case in cases:
            want = model(*case) + b'\x00'
            got = mem[at:at + len(want)]
            if got != want:
                bad.append((case, got, want))
            at += len(want)
    for case, got, want in bad[:3]:
        print(f'  {case}: got {got!r}, wanted {want!r}')
    print(('PASS' if not bad else 'FAIL') + f'  plat_demand: {len(cases)} indicators (every level from -27 to 27, three places) equal the model')
    return 1 if bad else 0


if __name__ == '__main__':
    sys.exit(main())
