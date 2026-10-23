#!/usr/bin/env python3
"""The Aquarius+ glyph placer (aq_blit8 in target/aqplus/plat_aqplus.asm) under z88dk-ticks.

The placer is called the way the game's C code calls it (five words on the stack, smallc) for corner, edge and
random cells, with and without the inverse flag, and the whole of bank 3 (the bitmap at $C000 and the colour RAM
at $E000) is compared with a model written here.  Also checks that the stack is balanced, that nothing outside
the cell is written, and that the Aquarius+ colour tables in assets/ are what tools/make_aq_assets.py makes.

  usage: test/aqplus/run.py
"""
import os
import random
import re
import subprocess
import sys
import tempfile

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
sys.path.insert(0, os.path.join(ROOT, 'tools'))
import make_aq_assets

TICKS = 'z88dk-ticks'
Z80ASM = 'z88dk-z80asm'
ROWS, COLS = 25, 40

HARNESS = '''        SECTION code_user
        org     $2000
        PUBLIC  _font_8x8_bbc_system, set_default_palette
        EXTERN  _aq_blit8, _plat_put_tile, _plat_aq_printc, _plat_puts, _plat_clear, _aq_colours, _aq_vcopy
start:  ld      sp,$7000
        ld      ix,cases
next:   ld      a,(ix+0)
        cp      255
        jr      z,done
        ld      h,0
        ld      l,a
        push    hl                      ; col
        ld      l,(ix+1)
        push    hl                      ; row
        ld      l,(ix+2)
        ld      h,(ix+3)
        push    hl                      ; art
        ld      l,(ix+4)
        ld      h,0
        push    hl                      ; colour
        ld      l,(ix+5)
        push    hl                      ; inverse
        ld      a,(ix+6)
        or      a
        jr      nz,viatile
        call    _aq_blit8
        jr      called
viatile:
        call    _plat_put_tile          ; the same routine under the name the game's C code uses
called:
        ld      hl,10
        add     hl,sp
        ld      sp,hl
        ld      de,7
        add     ix,de
        jr      next
done:   ld      ix,texts
nexttext:
        ld      a,(ix+0)
        cp      255
        jr      z,textdone
        ld      h,0
        ld      l,a
        push    hl                      ; col
        ld      l,(ix+1)
        push    hl                      ; row
        ld      l,(ix+2)
        ld      h,(ix+3)
        push    hl                      ; the string, or the character
        ld      a,(ix+4)
        cp      2
        jr      z,colourrun
        cp      3
        jr      z,vcopyrun
        or      a
        jr      nz,onechar
        call    _plat_puts
        jr      textcalled
colourrun:                              ; aq_colours(col, row, n, colour): the word is n | colour << 8
        pop     hl
        ld      a,h
        ld      h,0
        push    hl                      ; n
        ld      l,a
        push    hl                      ; colour
        call    _aq_colours
        ld      hl,8
        add     hl,sp
        ld      sp,hl
        jr      textadvance
onechar:
        call    _plat_aq_printc
        jr      textcalled
vcopyrun:                               ; aq_vcopy(offset, vsrc, n): the record's col is n and its word the offset
        pop     hl                      ; offset
        pop     de                      ; (the row: not used)
        pop     bc                      ; n in c
        push    hl
        ld      hl,vsrc
        push    hl
        push    bc
        call    _aq_vcopy
        ld      hl,6
        add      hl,sp
        ld      sp,hl
        jr      textadvance
textcalled:
        ld      hl,6
        add     hl,sp
        ld      sp,hl
textadvance:
        ld      de,5
        add     ix,de
        jr      nexttext
textdone:
        call    _plat_clear             ; the screen is cleared ...
        ld      hl,2
        push    hl                      ; col
        ld      hl,1
        push    hl                      ; row
        ld      hl,art
        push    hl
        ld      hl,$25
        push    hl                      ; colour
        ld      hl,0
        push    hl                      ; inverse
        call    _aq_blit8               ; ... and then one cell is drawn
        ld      hl,10
        add     hl,sp
        ld      sp,hl
        ld      (sp_end),sp
        halt
set_default_palette:
        ret
_font_8x8_bbc_system:
        BINARY  "font.bin"
vsrc:   defb    0x11,0x22,0x33,0x44,0x55,0x66,0x77,0x88,0x99,0xAA,0xBB,0xCC,0xDD,0xEE,0xF1,0xF2,0xF3,0xF4,0xF5,0xF6,0xF7,0xF8,0xF9,0xFA
sp_end: defw    0
texts:
        TEXTS
cases:
'''


def make_cases(rng):
    cases = []
    for row in (0, 1, 12, 23, 24):
        for col in (0, 1, 20, 38, 39):
            cases.append((col, row))
    while len(cases) < 150:
        cases.append((rng.randrange(COLS), rng.randrange(ROWS)))
    return cases


TEXT_COLOUR = 0x70


def main():
    rng = random.Random(2026)
    font = bytes(rng.randrange(256) for _ in range(96 * 8))     # glyphs of characters 32..127
    art = [bytes(rng.randrange(256) for _ in range(8)) for _ in range(40)]
    cells = make_cases(rng)
    spec = []
    for col, row in cells:
        spec.append((col, row, rng.randrange(len(art)), rng.randrange(256), rng.randrange(2), rng.randrange(2)))

    # text: plat_puts strings (including ones that run off the right edge, an empty one, one starting off the edge)
    # and single characters through plat_aq_printc; each is (col, row, string or character)
    texts = [(0, 0, 'SIMCITY'), (0, 24, 'JAN 1902  FUNDS $20000  POP 12345'), (30, 5, 'RUNS OFF THE RIGHT EDGE'),
             (39, 7, 'XY'), (40, 8, 'NOTHING'), (12, 9, ''), (3, 10, ' '), (38, 11, '!?'),
             (10, 12, 'abcdefghijklmnopqrstuvwxyz{|}~'), (0, 13, '0123456789'),
             (2, 15, '\x01\x05\x05\x02'), (2, 16, '\x06  \x06'), (2, 17, '\x03\x05\x05\x04')]     # a frame: the line pieces are codes 1 to 6
    runs = [(4, 0, 12, 0x31), (0, 24, 40, 0x6A), (30, 5, 10, 0x2F), (39, 7, 1, 0x15), (10, 12, 0, 0x77), (2, 15, 4, 0x4E), (7, 3, 33, 0xB1)]   # (col, row, n, colour)
    vcopies = [(24, 4), (24, 320 * 3 + 40 * 5 + 4), (24, 0x2000 + 40 * 2 + 4), (1, 0x1F3F), (7, 0x0100)]   # aq_vcopy(offset, vsrc, n)
    chars = [(5, 14, 'A'), (39, 24, '~'), (0, 0, ' '), (20, 20, '@'), (9, 19, '\x04'), (10, 19, '\x06')]
    strings = ''
    tspec = ''
    n = 0
    for col, row, t in texts:
        strings += f's{n}:      defb {"".join(str(ord(c)) + "," for c in t)}0\n'
        tspec += f'        defb {col},{row}\n        defw s{n}\n        defb 0\n'
        n += 1
    for col, row, ch in chars:
        tspec += f'        defb {col},{row}\n        defw {ord(ch)}\n        defb 1\n'
    for col, row, n_cells, colour in runs:                     # the colour of cells already drawn (aq_colours, kind 2)
        tspec += f'        defb {col},{row}\n        defw {n_cells | colour << 8}\n        defb 2\n'
    for n_bytes, offset in vcopies:                           # aq_vcopy, kind 3: col is n, the word the offset
        tspec += f'        defb {n_bytes},0\n        defw {offset}\n        defb 3\n'
    tspec += '        defb 255\n' + strings

    src = HARNESS.replace('        TEXTS\n', tspec)
    for col, row, a, colour, inv, tile in spec:
        src += f'        defb {col},{row}\n        defw art+{a * 8}\n        defb {colour},{inv},{tile}\n'
    src += '        defb 255\nart:\n'
    for a in art:
        src += '        defb ' + ','.join(str(b) for b in a) + '\n'

    # the model: what the video RAM holds afterwards (the line pieces of the frames, which are not in the font)
    BOX = [[0x00, 0x00, 0x00, 0x0F, 0x1F, 0x18, 0x18, 0x18], [0x00, 0x00, 0x00, 0xF0, 0xF8, 0x18, 0x18, 0x18],
           [0x18, 0x18, 0x18, 0x1F, 0x0F, 0x00, 0x00, 0x00], [0x18, 0x18, 0x18, 0xF8, 0xF0, 0x00, 0x00, 0x00],
           [0x00, 0x00, 0x00, 0xFF, 0xFF, 0x00, 0x00, 0x00], [0x18, 0x18, 0x18, 0x18, 0x18, 0x18, 0x18, 0x18]]

    def glyph(ch, r):
        return BOX[ord(ch) - 1][r] if ord(ch) < 32 else font[(ord(ch) - 32) * 8 + r]
    bank = bytearray(0x4000)
    for col, row, a, colour, inv, tile in spec:
        for r in range(8):
            bank[row * 320 + r * 40 + col] = art[a][r] ^ (0xFF if inv else 0)
        bank[0x2000 + row * 40 + col] = colour
    for col, row, t in texts:
        for ch in t:
            if col >= COLS:
                break
            for r in range(8):
                bank[row * 320 + r * 40 + col] = glyph(ch, r)
            bank[0x2000 + row * 40 + col] = TEXT_COLOUR
            col += 1
    for col, row, ch in chars:
        for r in range(8):
            bank[row * 320 + r * 40 + col] = glyph(ch, r)
        bank[0x2000 + row * 40 + col] = TEXT_COLOUR
    vsrc = [0x11, 0x22, 0x33, 0x44, 0x55, 0x66, 0x77, 0x88, 0x99, 0xAA, 0xBB, 0xCC, 0xDD, 0xEE, 0xF1, 0xF2, 0xF3, 0xF4, 0xF5, 0xF6, 0xF7, 0xF8, 0xF9, 0xFA]
    for n_bytes, offset in vcopies:                            # (after the colour runs, as the harness does them: the order of the records)
        pass
    for col, row, n_cells, colour in runs:                     # only the colour bytes change
        for c in range(col, col + n_cells):
            bank[0x2000 + row * 40 + c] = colour
    for n_bytes, offset in vcopies:
        bank[offset:offset + n_bytes] = bytes(vsrc[:n_bytes])

    with tempfile.TemporaryDirectory() as tmp:
        open(os.path.join(tmp, 'h.asm'), 'w').write(src)
        open(os.path.join(tmp, 'font.bin'), 'wb').write(font)
        out = subprocess.run([Z80ASM, '-b', '-m', '-I' + ROOT, '-DTARGET_AQPLUS', '-oh.bin', 'h.asm',
                              os.path.join(ROOT, 'target/aqplus/plat_aqplus.asm')],
                             cwd=tmp, capture_output=True, text=True)
        if out.returncode or out.stderr.strip():
            print(out.stdout + out.stderr)
            print('FAIL  the placer does not assemble')
            return 1
        code = open(os.path.join(tmp, 'h_code_user.bin'), 'rb').read()
        syms = {}
        for line in open(os.path.join(tmp, 'h.map')):
            m = re.match(r'(\S+)\s+= \$([0-9A-F]+) ;', line)
            if m:
                syms[m.group(1)] = int(m.group(2), 16)
        img = bytearray(65536)
        img[0x2000:0x2000 + len(code)] = code
        open(os.path.join(tmp, 'img.bin'), 'wb').write(img)
        # first up to the clear (everything the cells and the text drew), then on through it and the one cell after it
        subprocess.run([TICKS, '-pc', '2000', '-end', f'{syms["textdone"]:x}', '-counter', '400000000',
                        '-output', 'mem0.out', 'img.bin'], cwd=tmp, capture_output=True)
        mem0 = open(os.path.join(tmp, 'mem0.out'), 'rb').read()
        subprocess.run([TICKS, '-pc', '2000', '-end', f'{syms["textdone"] + 4:x}', '-counter', '400000000',
                        '-output', 'mem.out', 'img.bin'], cwd=tmp, capture_output=True)
        mem = open(os.path.join(tmp, 'mem.out'), 'rb').read()
    before = bytes(bank)

    # plat_clear: the bitmap (8000 bytes) is 0 and the colour RAM (1000 bytes) white on black; the rest of the page
    # is left alone (so what was drawn there, beyond the cells, stays), then the one cell drawn after it
    for i in range(40 * 25 * 8):
        bank[i] = 0
    for i in range(40 * 25):
        bank[0x2000 + i] = TEXT_COLOUR
    for r in range(8):
        bank[1 * 320 + r * 40 + 2] = art[0][r]
    bank[0x2000 + 1 * 40 + 2] = 0x25

    ok = True
    bad0 = [i for i in range(0x4000) if mem0[0xC000 + i] != before[i]]
    print(('PASS' if not bad0 else 'FAIL') + f'  the cells and the text (and the frame pieces) as drawn, before the clear: bitmap and colour RAM equal the model'
          + (f' ({len(bad0)} bytes differ, first at ${0xC000 + bad0[0]:04X})' if bad0 else ''))
    ok &= not bad0
    bad = [i for i in range(0x4000) if mem[0xC000 + i] != bank[i]]
    print(('PASS' if not bad else 'FAIL') + f'  {len(spec)} cells (corners, edges, random; inverse and plain) and text through plat_puts and plat_aq_printc, then plat_clear and one more cell: '
          f'bitmap and colour RAM equal the model' + (f' ({len(bad)} bytes differ, first at ${0xC000 + bad[0]:04X})' if bad else ''))
    ok &= not bad
    sp = mem[syms['sp_end']] | mem[syms['sp_end'] + 1] << 8
    print(('PASS' if sp == 0x7000 else 'FAIL') + f'  the stack is balanced (sp ends at ${sp:04X})')
    ok &= sp == 0x7000

    # the converted assets are what the tool makes
    art_src = bytearray(open(os.path.join(ROOT, 'assets', 'map_art.bin'), 'rb').read())
    for i in range(2760, 2854 + 251):
        art_src[i] = make_aq_assets.colour_byte(art_src[i])
    same = art_src == open(os.path.join(ROOT, 'assets', 'map_art_aq.bin'), 'rb').read()
    print(('PASS' if same else 'FAIL') + '  assets/map_art_aq.bin is map_art.bin with the attributes converted (run tools/make_aq_assets.py)')
    ok &= same
    udgs = open(os.path.join(ROOT, 'assets', 'udgs.bin'), 'rb').read()
    icons = udgs[:448] + bytes(make_aq_assets.colour_byte(a & 0x7F) for a in udgs[3240:3296])
    same = icons == open(os.path.join(ROOT, 'assets', 'icons.bin'), 'rb').read()
    print(('PASS' if same else 'FAIL') + '  assets/icons.bin is the icons with converted colour bytes (run tools/make_aq_assets.py)')
    ok &= same
    return 0 if ok else 1


if __name__ == '__main__':
    sys.exit(main())
