#!/usr/bin/env python3
"""The Aquarius+ text layer's assembler (aq_font_in, aq_txt_set, aq_text_blank, aq_tcell, aq_tcolour, aq_defchar, aq_mm_enter, aq_mm_leave in
target/aqplus/plat_aqplus.asm) under z88dk-ticks.

ticks has no banking: the video RAM (page 20 at $C000), the character RAM (page 21, also at $C000 when it is paged in) and the text layer (the overlay
window at $F000, colours at $F400) are all plain memory, so this checks what can be checked there: what the routines write where, in what order, the
state variables, and that the stack is balanced.  The ports (the video mode, the pages) are not seen.

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
        EXTERN  _aq_mm_enter, _aq_mm_leave, _aq_tcell, _aq_tcolour, _aq_defchar, _aq_txt_set, aq_font_in
start:  ld      sp,$7000
        call    aq_font_in
after_font:
        ld      l,1
        call    _aq_txt_set
after_txt1:
CALLS
after_calls:
        ld      l,2
        call    _aq_txt_set
after_txt2:
        ld      l,0
        call    _aq_txt_set
after_txt0:
        call    _aq_mm_enter
after_mm:
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


def call4(name, a, b, c, d):
    return push(a) + push(b) + push(c) + push(d) + f'        call    {name}\n        ld      hl,8\n        add     hl,sp\n        ld      sp,hl\n'


def main():
    rng = random.Random(7)
    font = bytes(rng.randrange(256) for _ in range(96 * 8))
    cells = [(0, 0, 160, 0), (28, 6, 96, 0xB0), (39, 24, 255, 0x70), (31, 14, 200, 0x12), (5, 9, 65 + 128, 0x7F)]
    runs = [(4, 3, 6, 0x4F), (0, 24, 40, 0x1F), (30, 5, 10, 0x2F), (7, 7, 0, 0x55)]       # aq_tcolour(col, row, n, colour), after the cells
    calls = ''.join(call4('_aq_tcell', *c) for c in cells) + ''.join(call4('_aq_tcolour', *r) for r in runs)
    calls += push(130) + '        ld      hl,art\n        push    hl\n        call    _aq_defchar\n        ld      hl,4\n        add     hl,sp\n        ld      sp,hl\n'
    src = HARNESS.replace('CALLS\n', calls)
    start_mem = bytearray(rng.randrange(256) for _ in range(0x10000))
    ok = True
    with tempfile.TemporaryDirectory() as tmp:
        open(os.path.join(tmp, 'h.asm'), 'w').write(src)
        open(os.path.join(tmp, 'font.bin'), 'wb').write(font)
        r = subprocess.run([Z80ASM, '-b', '-m', '-I' + ROOT, '-DTARGET_AQPLUS', '-oh.bin', 'h.asm', os.path.join(ROOT, 'target/aqplus/plat_aqplus.asm')],
                           cwd=tmp, capture_output=True, text=True)
        if r.returncode or r.stderr.strip():
            print(r.stdout + r.stderr)
            print('FAIL  the text layer routines do not assemble')
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

        def run(label):
            subprocess.run([TICKS, '-pc', '2000', '-end', f'{syms[label]:x}', '-counter', '400000000', '-output', 'm.out', 'img.bin'], cwd=tmp, capture_output=True)
            return open(os.path.join(tmp, 'm.out'), 'rb').read()
        dumps = {l: run(l) for l in ('after_font', 'after_txt1', 'after_calls', 'after_txt2', 'after_txt0', 'after_mm', 'after_leave')}

    def check(name, cond):
        nonlocal ok
        print(('PASS' if cond else 'FAIL') + '  ' + name)
        ok &= bool(cond)
    ram = 0xC000
    blank_chars, blank_cols = bytes([160]) * 1024, bytes(1024)
    f = dumps['after_font']
    box = bytes(f[syms['aq_box']:syms['aq_box'] + 48])
    glyphs = bytes(f[syms['aq_glyphs']:syms['aq_glyphs'] + 72])
    check('font in: the font is characters 160 to 255 (ASCII + 128)', f[ram + 160 * 8:ram + 256 * 8] == font)
    check('font in: the frame pieces are characters 132 to 137, our nine pictures 96 to 104, the rest of 96 to 159 blank',
          f[ram + 132 * 8:ram + 138 * 8] == box and f[ram + 96 * 8:ram + 105 * 8] == glyphs and
          f[ram + 105 * 8:ram + 132 * 8] == bytes(27 * 8) and f[ram + 138 * 8:ram + 160 * 8] == bytes(22 * 8))
    check('font in: the solid cell is solid, the bar\'s full cell is its middle six lines, and 1 to 7 pixels are from the left',
          glyphs[:8] == bytes([255] * 8) and glyphs[8:16] == bytes([0] + [255] * 6 + [0]) and
          all(glyphs[16 + 8 * (n - 1):24 + 8 * (n - 1)] == bytes([0] + [(0xFF << (8 - n)) & 0xFF] * 6 + [0]) for n in range(1, 8)))
    t = dumps['after_txt1']
    check('text screen 1: the text layer is blank (character 160, colour 0) and the state is 1',
          t[0xF000:0xF000 + 1024] == blank_chars and t[0xF400:0xF400 + 1024] == blank_cols and t[syms['_aq_txt']] == 1)
    c = dumps['after_calls']
    for col, row, ch, colour in cells:
        want = colour
        for rc, rr, n, rcolour in runs:
            if rr == row and rc <= col < rc + n:
                want = rcolour                                              # (a colour run after the cell recolours it)
        check(f'aq_tcell({col},{row},{ch},{colour:#x}): the character and the colour byte', c[0xF000 + row * 40 + col] == ch and c[0xF400 + row * 40 + col] == want)
    for col, row, n, colour in runs:
        run_ok = all(c[0xF400 + row * 40 + col + i] == colour for i in range(n))
        edge_ok = col + n >= 40 or c[0xF400 + row * 40 + col + n] != colour or any(cc[1] == row and cc[0] == col + n for cc in cells)
        check(f'aq_tcolour({col},{row},{n},{colour:#x}): n colour bytes and no more', run_ok and edge_ok)
    check('aq_defchar: the 8 bytes are in the character RAM', c[ram + 130 * 8:ram + 130 * 8 + 8] == bytes([1, 2, 3, 4, 5, 6, 7, 8]))
    check('text screens 2 and 0: the state follows, and the layer is blank when it is closed',
          dumps['after_txt2'][syms['_aq_txt']] == 2 and dumps['after_txt0'][syms['_aq_txt']] == 0 and
          dumps['after_txt0'][0xF000:0xF000 + 1024] == blank_chars and dumps['after_txt0'][0xF400:0xF400 + 1024] == blank_cols)
    m = dumps['after_mm']
    check('mini map enter: the flag is set and the 4bpp bitmap is cleared (up to $F000: above it the flat memory is the text layer)',
          m[syms['_aq_mm4']] == 1 and m[0xC000:0xF000] == bytes(0x3000))
    check('mini map enter: the text layer is blank', m[0xF000:0xF000 + 1024] == blank_chars and m[0xF400:0xF400 + 1024] == blank_cols)
    d = dumps['after_leave']
    check('mini map leave: the flag is clear, the 1bpp screen is cleared (bitmap 0, colour RAM white on black)',
          d[syms['_aq_mm4']] == 0 and d[0xC000:0xC000 + 8000] == bytes(8000) and d[0xE000:0xE000 + 1000] == bytes([0x70]) * 1000)
    sp = d[syms['sp_end']] | d[syms['sp_end'] + 1] << 8
    check(f'the stack is balanced (sp ends at ${sp:04X})', sp == 0x7000)
    return 0 if ok else 1


if __name__ == '__main__':
    sys.exit(main())
