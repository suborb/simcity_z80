#!/usr/bin/env python3
"""z88dk's Aquarius+ mouse (in_MouseAQPlus and its SetPos, libsrc/target/aquarius/input) under z88dk-ticks, with the ESP32's answers scripted.

The ESP32 answers GETMOUSE with its own position, or an error: the driver must keep a position of its own that the mouse's movement is added to, limited to
0..319 by 0..199, that SetPos can move, and with no mouse must give no buttons and leave the position alone.  The two ESP routines are stubs here that
hand out the bytes of the script.

  usage: test/aqplus/mouse.py
"""
import os
import re
import subprocess
import sys
import tempfile

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
Z88DK = os.environ.get('ZCCCFG', os.path.expanduser('~/z88dk/lib/config')) + '/../../libsrc/target/aquarius/input'
FILES = ['INMouseAQPlus.asm', 'in_MouseAQPlus_callee.asm', 'in_MouseAQPlusInit.asm', 'in_MouseAQPlusSetPos_callee.asm']

HARNESS = '''        SECTION code_user
        org     $2000
        EXTERN  in_MouseAQPlus_callee, in_MouseAQPlusInit, in_MouseAQPlusSetPos_callee
        PUBLIC  __esp_send_cmd, __esp_read_byte
start:  ld      sp,$7000
        ld      ix,ops
        ld      iy,results
next:   ld      a,(ix+0)
        cp      255
        jr      z,fin
        inc     ix
        or      a
        jr      z,read
        cp      1
        jr      z,init
        ld      l,(ix+0)                ; setpos(x, y)
        ld      h,(ix+1)
        push    hl
        ld      l,(ix+2)
        ld      h,(ix+3)
        push    hl
        ld      de,4
        add     ix,de
        call    in_MouseAQPlusSetPos_callee
        jr      next
init:   call    in_MouseAQPlusInit
        jr      next
read:   ld      hl,buttons
        push    hl
        ld      hl,xcoord
        push    hl
        ld      hl,ycoord
        push    hl
        call    in_MouseAQPlus_callee
        ld      a,(buttons)
        ld      (iy+0),a
        ld      hl,(xcoord)
        ld      (iy+1),l
        ld      (iy+2),h
        ld      hl,(ycoord)
        ld      (iy+3),l
        ld      (iy+4),h
        ld      de,5
        add     iy,de
        jr      next
fin:    halt
__esp_send_cmd:
        ret
__esp_read_byte:
        push    hl
        ld      hl,(script)
        ld      a,(hl)
        inc     hl
        ld      (script),hl
        pop     hl
        ret
script: defw    stream
buttons: defb   0
xcoord: defw    0
ycoord: defw    0
ops:    %OPS%
        defb    255
stream: %STREAM%
        defs    16
results: defs   200
'''

READ, INIT, SETPOS = 0, 1, 2


def answer(x, y, buttons=0):
    return [0, x & 255, x >> 8, y, buttons, 0]


def main():
    # (op, esp answer, expected (buttons, x, y))
    steps = [
        (INIT, answer(100, 50), None),                       # the first answer is where the mouse is: no movement
        (READ, answer(100, 50), (0, 0, 0)),
        (READ, answer(110, 55, 1), (1, 10, 5)),              # moved right and down, the left button
        (READ, answer(105, 40, 6), (6, 5, 0)),
        (SETPOS, (160, 100), None),                          # the pointer is moved by something else (keys): the mouse's movement is added to it
        (READ, answer(106, 41), (0, 161, 101)),
        (READ, answer(0, 0), (0, 55, 60)),                   # a long way, to the left and up: 106 left, 41 up
        (READ, answer(0, 0), (0, 55, 60)),
        (READ, answer(300, 199), (0, 319, 199)),             # limited at the right and bottom edges
        (READ, answer(0, 0), (0, 19, 0)),                    # ... and 300 back left, 199 up: 319 - 300 = 19, 199 - 199 = 0
        (SETPOS, (5000, 5000), None),
        (READ, answer(0, 0), (0, 319, 199)),                 # SetPos limits too
        (READ, [0xFF], (0, 319, 199)),                       # no mouse (ERR_NOT_FOUND): no buttons, the position left alone
        (READ, [0xFF], (0, 319, 199)),
        (READ, answer(200, 100, 5), (5, 319, 199)),          # it is back: this answer is only where it is
        (READ, answer(190, 90), (0, 309, 189)),
    ]
    ops, stream, expect = [], [], []
    for op, arg, want in steps:
        if op == SETPOS:
            ops.append(f'defb 2\n        defw {arg[0]}, {arg[1]}')
        else:
            ops.append(f'defb {op}')
            stream += arg
        if op == READ:
            expect.append(want)
    src = HARNESS.replace('%OPS%', '\n        '.join(ops)).replace('%STREAM%', 'defb ' + ','.join(map(str, stream)) if stream else '')
    ok = True
    with tempfile.TemporaryDirectory() as tmp:
        open(os.path.join(tmp, 'h.asm'), 'w').write(src)
        out = subprocess.run(['z88dk-z80asm', '-b', '-m', 'h.asm'] + [os.path.join(Z88DK, f) for f in FILES],
                             cwd=tmp, capture_output=True, text=True)
        if out.returncode or out.stderr.strip():
            print(out.stdout + out.stderr)
            print('FAIL  the driver does not assemble')
            return 1
        syms = {}
        for line in open(os.path.join(tmp, 'h.map')):
            m = re.match(r'(\S+)\s+= \$([0-9A-F]+) ;', line)
            if m:
                syms[m.group(1)] = int(m.group(2), 16)
        code = open(os.path.join(tmp, 'h_code_user.bin'), 'rb').read()
        img = bytearray(65536)
        img[0x2000:0x2000 + len(code)] = code
        open(os.path.join(tmp, 'img.bin'), 'wb').write(img)
        subprocess.run(['z88dk-ticks', '-pc', '2000', '-end', f'{syms["fin"]:x}', '-counter', '10000000', '-output', 'mem.out', 'img.bin'],
                       cwd=tmp, capture_output=True)
        mem = open(os.path.join(tmp, 'mem.out'), 'rb').read()
    base = syms['results']
    for i, want in enumerate(expect):
        got = (mem[base + 5 * i], mem[base + 5 * i + 1] | mem[base + 5 * i + 2] << 8, mem[base + 5 * i + 3] | mem[base + 5 * i + 4] << 8)
        good = got == want
        ok &= good
        if not good:
            print(f'FAIL  read {i}: buttons, x, y are {got}, expected {want}')
    print(('PASS' if ok else 'FAIL') + f'  {len(expect)} reads and SetPos: the position is kept by adding the mouse\'s movement, limited, and a missing mouse changes nothing')
    return 0 if ok else 1


if __name__ == '__main__':
    sys.exit(main())
