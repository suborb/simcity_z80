#!/usr/bin/env python3
"""The Aquarius+ 4bpp mini map's assembler (aq_mm_enter, aq_mm_leave, aq_tcell, aq_defchar in target/aqplus/plat_aqplus.asm) under z88dk-ticks.

ticks has no banking: the video RAM (page 20 at $C000), the character RAM (page 21, also at $C000 when it is paged in) and the text layer
(the overlay window at $F000, colours at $F400) are all plain memory, so this checks what can be checked there: what the routines write where, in
what order, and that the stack is balanced.  The ports (the video mode, the pages) are not seen.

  usage: test/aqplus/text4.py
"""
import os
import random
import re
import subprocess
import sys
import tempfile

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
TICKS = 'z88dk-ticks'
Z80ASM = 'z88dk-z80asm'

HARNESS = '''        SECTION code_user
        org     $2000
        PUBLIC  _font_8x8_bbc_system, set_default_palette
        EXTERN  _aq_mm_enter, _aq_mm_leave, _aq_tcell, _aq_defchar, _aq_mm4
start:  ld      sp,$7000
        call    _aq_mm_enter
after_enter:
CALLS
        call    _aq_mm_leave
        ld      (sp_end),sp
after_leave:
        halt
set_default_palette:
        ret
sp_end: defw    0
_font_8x8_bbc_system:
        BINARY  "font.bin"
art:    defb    1,2,3,4,5,6,7,8
'''


def push(v):
    return f'        ld      hl,{v}\n        push    hl\n'


def main():
    rng = random.Random(7)
    font = bytes(rng.randrange(256) for _ in range(96 * 8))
    cells = [(0, 0, 160, 0), (28, 6, 128, 0xB0), (39, 24, 255, 0x70), (31, 14, 200, 0x12), (5, 9, 65 + 128, 0x70)]
    defs = [(130, 'art'), (150, 'art'), (255, 'art')]
    calls = ''
    for col, row, ch, colour in cells:
        calls += push(col) + push(row) + push(ch) + push(colour) + '        call    _aq_tcell\n        ld      hl,8\n        add     hl,sp\n        ld      sp,hl\n'
    for ch, name in defs:
        calls += push(ch) + f'        ld      hl,{name}\n        push    hl\n        call    _aq_defchar\n        ld      hl,4\n        add     hl,sp\n        ld      sp,hl\n'
    src = HARNESS.replace('CALLS\n', calls)
    start_mem = bytearray(rng.randrange(256) for _ in range(0x10000))
    chars_before = bytes(start_mem[0xC400:0xC800])
    ok = True
    with tempfile.TemporaryDirectory() as tmp:
        open(os.path.join(tmp, 'h.asm'), 'w').write(src)
        open(os.path.join(tmp, 'font.bin'), 'wb').write(font)
        r = subprocess.run([Z80ASM, '-b', '-m', '-I' + ROOT, '-DTARGET_AQPLUS', '-oh.bin', 'h.asm', os.path.join(ROOT, 'target/aqplus/plat_aqplus.asm')],
                           cwd=tmp, capture_output=True, text=True)
        if r.returncode or r.stderr.strip():
            print(r.stdout + r.stderr)
            print('FAIL  the 4bpp routines do not assemble')
            return 1
        code = open(os.path.join(tmp, 'h_code_user.bin'), 'rb').read()
        syms = {}
        for line in open(os.path.join(tmp, 'h.map')):
            m = re.match(r'(\S+)\s+= \$([0-9A-F]+) ;', line)
            if m:
                syms[m.group(1)] = int(m.group(2), 16)
        img = bytearray(start_mem)
        img[0x2000:0x2000 + len(code)] = code
        open(os.path.join(tmp, 'img.bin'), 'wb').write(img)

        def run(label, name):
            subprocess.run([TICKS, '-pc', '2000', '-end', f'{syms[label]:x}', '-counter', '400000000', '-output', name, 'img.bin'], cwd=tmp, capture_output=True)
            return open(os.path.join(tmp, name), 'rb').read()
        entered = run('aq_mm_clear', 'm0.out')              # up to the clearing: the characters are saved, ours are in
        after = run('after_enter', 'm1.out')
        done = run('after_leave', 'm2.out')

    def check(name, cond, detail=''):
        nonlocal ok
        print(('PASS' if cond else 'FAIL') + '  ' + name + ('' if cond else ' ' + detail))
        ok &= bool(cond)
    save = syms['aq_chr_save']
    check('enter: characters 128 to 255 of the character RAM are saved', entered[save:save + 1024] == chars_before)
    check('enter: characters 128 to 159 are blank and 160 up are the font (ASCII + 128)', entered[0xC400:0xC500] == bytes(256) and entered[0xC500:0xC800] == font)
    check('enter: the 4bpp bitmap is cleared (up to $F000: above it the flat memory is the text layer)', after[0xC000:0xF000] == bytes(0x3000))
    check('enter: the text layer is blanks (160) and colour 0', after[0xF000:0xF000 + 1000] == bytes([160]) * 1000 and after[0xF400:0xF400 + 1000] == bytes(1000))
    check('enter: the mode flag is set', after[syms['_aq_mm4']] == 1)
    chars_after = bytearray(after[0xF000:0xF000 + 1000]), bytearray(after[0xF400:0xF400 + 1000])
    # after the calls (the leave has run by after_leave, so the text layer and character RAM are as the calls left them)
    for col, row, ch, colour in cells:
        check(f'aq_tcell({col},{row},{ch},{colour:#x}): the character and the colour byte', done[0xF000 + row * 40 + col] == ch and done[0xF400 + row * 40 + col] == colour)
    check('aq_defchar writes nothing in the text layer', done[0xF000 + 40 * 24 + 38] == 160 and done[0xF400 + 40 * 24 + 38] == 0)
    check('leave: the mode flag is clear', done[syms['_aq_mm4']] == 0)
    check('leave: the 1bpp screen is cleared (bitmap 0, colour RAM white on black)', done[0xC000:0xC000 + 8000] == bytes(8000) and done[0xE000:0xE000 + 1000] == bytes([0x70]) * 1000)
    sp = done[syms['sp_end']] | done[syms['sp_end'] + 1] << 8
    check(f'the stack is balanced (sp ends at ${sp:04X})', sp == 0x7000)
    return 0 if ok else 1


if __name__ == '__main__':
    sys.exit(main())
