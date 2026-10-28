#!/usr/bin/env python3
"""The Multi 8 placer (target/multi8/plat_multi8.asm) under z88dk-ticks, with the machine's video paging modelled.

z88dk-ticks has flat memory, so the placer runs with its instruction trace on and this script replays the trace
against a model of the machine: port $2A (bits 0-3 active low: blue, red, green and the text page are paged over
$8000-$BFFF; bit 4 clear is the plain RAM underneath), where a read is the AND of the pages paged in and a write
goes to each.  The model is the same as MAME's (src/mame/mitsubishi/multi8.cpp).

The placer is called the way the game's C code calls it (five words on the stack, smallc) for corner, edge and random
cells in every colour combination, plain and inverse, and for text; then plat_init and plat_clear.  Each plane of the
screen is compared with a model of the cell (see the top of plat_multi8.asm), and so are the stack, the port left
behind, and that the placer touched nothing in $8000-$BFFF while a plane was paged in other than the screen.

  usage: test/multi8/run.py
"""
import os
import shutil
import random
import re
import subprocess
import sys
import tempfile

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
Z80ASM = 'z88dk-z80asm'
TICKS = 'z88dk-ticks'
ROWS, COLS = 25, 40
IDLE = 0x2F

CELLREC = 6                             # bytes in a cell's record: col, row, art (2), attr, inverse

HARNESS = '''        SECTION code_user
        org     $0100
        PUBLIC  _font_8x8_bbc_system, __port29_copy, _view_tile_art
        defc    _view_tile_art = art            ; picture n is at 8 * n from it (the placer only subtracts); the same address as the 1 bit art
        EXTERN  _plat_put_tile, _mp_tile1, _plat_put_overlay, _plat_put_bitmap, _plat_put, _plat_puts, _plat_clear, _plat_init
start:  ld      sp,$7000
        call    _plat_init
        ld      ix,cases
        call    tiles
        ld      ix,bcases
        call    btiles
        jp      ovdraw
tiles:
next:   ld      a,(ix+0)
        cp      255
        ret     z
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
        push    hl                      ; attr
        ld      l,(ix+5)
        push    hl                      ; inverse
        call    _mp_tile1
        ld      hl,10
        add     hl,sp
        ld      sp,hl
        ld      de,CELLREC
        add     ix,de
        jr      next
btiles:
bnext:   ld      a,(ix+0)
        cp      255
        ret     z
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
        push    hl                      ; attr
        ld      l,(ix+5)
        push    hl                      ; inverse
        call    _plat_put_tile
        ld      hl,10
        add     hl,sp
        ld      sp,hl
        ld      de,CELLREC
        add     ix,de
        jr      bnext
ovdraw: ld      ix,ovls
nextov: ld      a,(ix+0)
        cp      255
        jr      z,ovdone
        ld      h,0
        ld      l,a
        push    hl                      ; col
        ld      l,(ix+1)
        push    hl                      ; row
        ld      l,(ix+2)
        ld      h,(ix+3)
        push    hl                      ; art
        call    _plat_put_overlay
        ld      hl,6
        add     hl,sp
        ld      sp,hl
        ld      de,4
        add     ix,de
        jr      nextov
ovdone: jp      bitmapsdraw
bitmapsdraw: ld      ix,bitmaps
nextbm: ld      a,(ix+0)
        cp      255
        jr      z,bmdone
        ld      h,0
        ld      l,a
        push    hl                      ; col
        ld      l,(ix+1)
        push    hl                      ; row
        ld      l,(ix+2)
        ld      h,(ix+3)
        push    hl                      ; art
        call    _plat_put_bitmap
        ld      hl,6
        add     hl,sp
        ld      sp,hl
        ld      de,4
        add     ix,de
        jr      nextbm
bmdone: ld      ix,texts
nexttext:
        ld      a,(ix+0)
        cp      255
        jr      z,tail
        ld      h,0
        ld      l,a
        push    hl                      ; col
        ld      l,(ix+1)
        push    hl                      ; row
        ld      l,(ix+2)
        ld      h,(ix+3)
        push    hl                      ; the string, or the character
        ld      a,(ix+4)
        or      a
        jr      nz,onechar
        call    _plat_puts
        jr      textcalled
onechar:
        call    _plat_put
textcalled:
        ld      hl,6
        add     hl,sp
        ld      sp,hl
        ld      de,5
        add     ix,de
        jr      nexttext
tail:   ld      ix,cases2
        call    tiles
        ld      ix,bcases2
        call    btiles                   ; some tiles again: over text and a bitmap (drawn again), and one that is still there (skipped)
textdone:
        call    _plat_clear             ; the screen is cleared ...
        ld      hl,2
        push    hl                      ; col
        ld      hl,1
        push    hl                      ; row
        ld      hl,art
        push    hl
        ld      hl,$0D
        push    hl                      ; attr
        ld      hl,0
        push    hl                      ; inverse
        call    _mp_tile1               ; ... and then one cell is drawn (and a baked one, below)
        ld      hl,10
        add     hl,sp
        ld      sp,hl
        ld      hl,3
        push    hl                      ; col
        ld      hl,1
        push    hl                      ; row
        ld      hl,_view_tile_art + 5 * 8
        push    hl
        ld      hl,0
        push    hl                      ; attr
        push    hl                      ; inverse
        call    _plat_put_tile
        ld      hl,10
        add     hl,sp
        ld      sp,hl
        ld      (sp_end),sp
fin:    halt
__port29_copy:
        defb    $85
sp_end: defw    0
_font_8x8_bbc_system:
        BINARY  "font.bin"
bitmaps:
        BITMAPS
texts:
        TEXTS
ovls:
        OVERLAYS
bcases2:
        BCASES2
bcases:
        BCASES
cases2:
        CASES2
cases:
'''


class Machine:
    """The video memory behind $8000-$BFFF and the port that pages it."""

    def __init__(self):
        self.port = IDLE
        self.planes = [bytearray(0x4000) for _ in range(4)]     # blue, red, green, text
        self.wram_writes = 0                                    # stores to the RAM underneath
        self.stray = []                                         # accesses a placer must not make while paged in
        self.ports = {}
        self.snapshot = None
        self.low = {}                                           # the stores to the low RAM that a block copy to the screen reads

    def paged(self):
        return bool(self.port & 0x10)

    def write(self, addr, val):
        off = addr - 0x8000
        if not self.paged():
            self.wram_writes += 1
            return
        for p in range(4):
            if not self.port & (1 << p):
                self.planes[p][off] = val

    def read(self, addr):
        off = addr - 0x8000
        if not self.paged():
            return 0
        res = 0xFF
        for p in range(4):
            if not self.port & (1 << p):
                res &= self.planes[p][off]
        return res


def replay(trace_path, m, snap_pc):
    """Replay the trace: only the instructions that write to the screen or the port matter."""
    regs = {}
    or_mask = None
    reg_re = re.compile(r'pc=(\w+), \[pc\]=\w+,\s+bc=(\w+),\s+de=(\w+),\s+hl=(\w+),\s+af=(\w+)')
    ins_re = re.compile(r'^\s+(\S.*?)\s+;\[(\w+)\]')
    out_log = []
    n = 0
    with open(trace_path, errors='replace') as f:
        for line in f:
            if line.startswith('pc='):
                g = reg_re.match(line)
                regs = {'pc': int(g.group(1), 16), 'bc': int(g.group(2), 16), 'de': int(g.group(3), 16), 'hl': int(g.group(4), 16),
                        'a': int(g.group(5), 16) >> 8}
                continue
            if not line.startswith(' '):
                continue
            g = ins_re.match(line)
            if not g:
                continue
            n += 1
            if regs['pc'] == snap_pc and m.snapshot is None:
                m.snapshot = [bytearray(pl) for pl in m.planes]      # the screen before plat_clear
            text = re.sub(r'\s+', ' ', g.group(1))
            hl, de, a = regs['hl'], regs['de'], regs['a']
            if text.startswith('out ('):
                port = int(text[5:text.index(')')].replace('$', ''), 16)
                if port == 0x2A:
                    m.port = a
                else:
                    out_log.append((port, a))
            elif text == 'or (hl)' and m.paged() and 0x8000 <= hl < 0xC000:
                or_mask = a                                  # the flat memory the tracer runs in has no planes: a is worked out here
            elif text == 'ld (hl),a' and hl >= 0x8000 and hl < 0xC000:
                m.write(hl, a if or_mask is None else or_mask | m.read(hl))
                or_mask = None
            elif text == 'ld (hl),a' and hl < 0x8000:
                m.low[hl] = a
            elif text.startswith('ld (hl),$') and 0x8000 <= hl < 0xC000:
                m.write(hl, int(text[len('ld (hl),$'):], 16))
            elif text == 'ldir':
                if 0x8000 <= de < 0xC000:
                    m.write(de, m.read(hl) if 0x8000 <= hl < 0xC000 else m.low.get(hl, 0))
            elif m.paged() and re.search(r'\((?:hl|de|bc)\)', text) and 0x8000 <= (hl if '(hl)' in text else de) < 0xC000:
                pass
    return out_log, n


def main():
    rng = random.Random(2026)
    font = bytes(rng.randrange(256) for _ in range(96 * 8))
    art = [bytes(rng.randrange(256) for _ in range(8)) for _ in range(40)]

    cells = []
    for row in (0, 1, 12, 23, 24):
        for col in (0, 1, 20, 38, 39):
            cells.append((col, row))
    while len(cells) < 60:
        cells.append((rng.randrange(COLS), rng.randrange(ROWS)))
    spec = []
    for i, (col, row) in enumerate(cells):
        attr = i % 64 if i < 64 else rng.randrange(256)        # every ink and paper pair appears; bright and flash are ignored
        spec.append((col, row, rng.randrange(len(art)), attr, rng.randrange(2)))
    for c in range(64):                                          # all 64 attributes, plain and inverse
        spec.append((c % COLS, 2 + c // COLS, c % len(art), c, c & 1))
    spec += [(24, 5, 0, 0, 0),                              # black on black, at the address a baked picture is drawn from next
             (2, 1, 0, 0x0D, 0), (6, 13, 1, 7, 0), (0, 15, 3, 7, 0)]   # cells that text or a bitmap or plat_clear overwrites
    # drawn again later: over the text and the bitmap (so drawn), the same again (skipped), the same picture inverted, another picture
    cases2 = [(6, 13, 1, 7, 0), (0, 15, 3, 7, 0), (0, 15, 3, 7, 0), (2, 1, 0, 0x0D, 0), (2, 1, 0, 0x0D, 0), (2, 1, 0, 0x0D, 1), (2, 1, 1, 0x0D, 1),
              (2, 1, 1, 0x0D, 1), (2, 1, 0, 0x0D, 0),
              (12, 10, 0, 9, 0), (12, 10, 32, 9, 0),                    # art addresses that differ only in the high byte
              (10, 10, 0, 9, 0), (11, 10, 1, 9, 0), (10, 10, 1, 9, 0), (11, 10, 1, 9, 0), (13, 10, 2, 9, 0), (10, 10, 1, 9, 0)]  # neighbours
    bitmaps = [(0, 15, 3), (39, 16, 9), (17, 17, 21)]
    texts = [(0, 0, 'SIMCITY'), (0, 24, 'JAN 1902  FUNDS $20000  POP 12345'), (30, 5, 'RUNS OFF THE RIGHT EDGE'),
             (39, 7, 'XY'), (40, 8, 'NOTHING'), (12, 9, ''), (3, 10, ' '), (38, 11, '!?'),
             (10, 12, 'abcdefghijklmnopqrstuvwxyz{|}~'), (0, 13, '0123456789')]
    chars = [(5, 14, 'A'), (39, 24, '~'), (0, 0, ' '), (20, 20, '@')]
    strings, tspec, n = '', '', 0
    for col, row, t in texts:
        strings += f's{n}:      defm "{t}"\n        defb 0\n'
        tspec += f'        defb {col},{row}\n        defw s{n}\n        defb 0\n'
        n += 1
    for col, row, ch in chars:
        tspec += f'        defb {col},{row}\n        defw {ord(ch)}\n        defb 1\n'
    tspec += '        defb 255\n' + strings
    bspec = ''.join(f'        defb {c},{r}\n        defw art+{a * 8}\n' for c, r, a in bitmaps) + '        defb 255\n'

    c2 = ''.join(f'        defb {c},{r}\n        defw art+{a * 8}\n        defb {at},{iv}\n' for c, r, a, at, iv in cases2) + '        defb 255\n'

    # the baked pictures (plat_put_tile): picture n's 24 bytes are in mp_tiles, which the test makes
    NPIC = 345
    blob = bytes(rng.randrange(256) for _ in range(NPIC * 24))
    baked = [(24, 5, 0, 0), (3, 1, 5, 0), (6, 13, 7, 0), (0, 15, 9, 1), (0, 0, 0, 0), (39, 24, NPIC - 1, 1), (25, 21, 31, 0), (26, 21, 32, 1)]
    seen = {(c, r) for c, r, _, _ in baked}
    while len(baked) < 60:
        c, r = rng.randrange(COLS), rng.randrange(ROWS)
        if (c, r) not in seen:
            seen.add((c, r)); baked.append((c, r, rng.randrange(NPIC), rng.randrange(2)))
    # again later: over the text and the bitmap (drawn), the same (skipped), inverted, another picture, and a neighbour
    baked2 = [(6, 13, 7, 0), (0, 15, 9, 1), (0, 15, 9, 1), (6, 13, 7, 0), (6, 13, 7, 1), (6, 13, 8, 1), (6, 13, 8, 1), (7, 13, 8, 1),
              (6, 13, 8, 0), (25, 21, 31, 0), (22, 3, 300, 0), (22, 3, 300 - 256, 0)]      # pictures that differ in the high byte of the art address
    # sprite pixels over cells: two baked ones (one inverted), a cell with nothing drawn, and one overlaid twice
    overlays = [(25, 21, 3), (26, 21, 7), (30, 22, 11), (31, 22, 12), (31, 22, 13), (27, 21, 5)]
    ov = ''.join(f'        defb {c},{r}\n        defw art+{a * 8}\n' for c, r, a in overlays) + '        defb 255\n'
    bk = lambda cs: ''.join(f'        defb {c},{r}\n        defw _view_tile_art+{n * 8}\n        defb 0,{iv}\n' for c, r, n, iv in cs) + '        defb 255\n'
    src = HARNESS.replace('CELLREC', str(CELLREC)).replace('        CASES2\n', c2).replace('        OVERLAYS\n', ov).replace('        BCASES2\n', bk(baked2)).replace('        BCASES\n', bk(baked)).replace('        BITMAPS\n', bspec).replace('        TEXTS\n', tspec)
    for col, row, a, attr, inv in spec:
        src += f'        defb {col},{row}\n        defw art+{a * 8}\n        defb {attr},{inv}\n'
    src += '        defb 255\nart:\n'
    for a in art:
        src += '        defb ' + ','.join(str(b) for b in a) + '\n'

    # the model: the three planes (80 bytes to a pixel row)
    model = [bytearray(0x4000) for _ in range(3)]

    def double(b):
        """the 8 pixels of b across 16: every bit twice, as the left and right bytes"""
        w = 0
        for i in range(7, -1, -1):
            w = w << 2 | (3 if b >> i & 1 else 0)
        return w >> 8, w & 0xFF

    def cell(col, row, pic, attr, inv):
        for p in range(3):
            ink = 0xFF if attr >> p & 1 else 0
            paper = 0xFF if attr >> (3 + p) & 1 else 0
            for r in range(8):
                for half, px in enumerate(double(pic[r] ^ (0xFF if inv else 0))):
                    model[p][row * 640 + r * 80 + col * 2 + half] = (px & ink) | (~px & 0xFF & paper)

    def bake(col, row, n, inv):
        for p in range(3):
            for r in range(8):
                for half, px in enumerate(double(blob[n * 24 + p * 8 + r] ^ (0xFF if inv else 0))):
                    model[p][row * 640 + r * 80 + col * 2 + half] = px

    for col, row, a, attr, inv in spec:
        cell(col, row, art[a], attr, inv)
    for col, row, n, inv in baked:
        bake(col, row, n, inv)
    for col, row, a in overlays:                                # white where set: or into each plane
        for p in range(3):
            for r in range(8):
                for half, px in enumerate(double(art[a][r])):
                    model[p][row * 640 + r * 80 + col * 2 + half] |= px
    for col, row, a in bitmaps:
        cell(col, row, art[a], 7, 0)
    glyph = lambda ch: font[(ord(ch) - 32) * 8:(ord(ch) - 32) * 8 + 8]
    for col, row, t in texts:
        for ch in t:
            if col >= COLS:
                break
            cell(col, row, glyph(ch), 7, 0)
            col += 1
    for col, row, ch in chars:
        cell(col, row, glyph(ch), 7, 0)
    for col, row, a, attr, inv in cases2:
        cell(col, row, art[a], attr, inv)
    for col, row, n, inv in baked2:
        bake(col, row, n, inv)

    with tempfile.TemporaryDirectory() as tmp:
        open(os.path.join(tmp, 'h.asm'), 'w').write(src)
        open(os.path.join(tmp, 'font.bin'), 'wb').write(font)
        os.makedirs(os.path.join(tmp, 'build', 'common'))
        open(os.path.join(tmp, 'build', 'common', 'tiles_640x200_3bpp.bin'), 'wb').write(blob)
        out = subprocess.run([Z80ASM, '-b', '-m', '-I' + ROOT, '-oh.bin', 'h.asm',
                              os.environ.get('MP_ASM', os.path.join(ROOT, 'target/multi8/plat_multi8.asm'))],
                             cwd=tmp, capture_output=True, text=True)
        if out.returncode or out.stderr.strip():
            print(out.stdout + out.stderr)
            print('FAIL  the placer does not assemble')
            return 1
        syms = {}
        for line in open(os.path.join(tmp, 'h.map')):
            m = re.match(r'(\S+)\s+= \$([0-9A-F]+) ;', line)
            if m:
                syms[m.group(1)] = int(m.group(2), 16)
        img = bytearray(65536)
        for sec in ('code_user', 'data_user', 'rodata_user', 'data_fcntl'):
            p = os.path.join(tmp, f'h_{sec}.bin')
            if os.path.exists(p):
                b = open(p, 'rb').read()
                img[syms[f'__{sec}_head']:syms[f'__{sec}_head'] + len(b)] = b
        first = os.path.join(tmp, 'h.bin')
        if os.path.exists(first) and os.path.getsize(first):
            b = open(first, 'rb').read()
            img[0x100:0x100 + len(b)] = b
        if syms.get('__code_user_head', 0x100) != 0x100:
            print('FAIL  the harness is not at $0100'); return 1
        open(os.path.join(tmp, 'img.bin'), 'wb').write(img)
        with open(os.path.join(tmp, 'trace.txt'), 'w') as tf:
            subprocess.run([TICKS, '-pc', '100', '-end', f'{syms["fin"]:x}', '-counter', '400000000', '-trace',
                            '-output', 'mem.out', 'img.bin'], cwd=tmp, stdout=tf, stderr=subprocess.DEVNULL)
        if os.environ.get('MP_SYMS'):
            print({k: hex(v) for k, v in syms.items() if k in ('mp_tiles', 'mp_cache', 'mp_pix3', 'mp_scr', '_view_tile_art', '__data_fcntl_head', '__data_user_head', '__bss_user_head', '__code_user_head', '__rodata_user_head', 'start', 'art', 'cases', 'bcases')})
        if os.environ.get('MP_KEEP'):
            shutil.copy(os.path.join(tmp, 'trace.txt'), os.environ['MP_KEEP'])
        mem = open(os.path.join(tmp, 'mem.out'), 'rb').read()
        m = Machine()
        ports, count = replay(os.path.join(tmp, 'trace.txt'), m, syms['textdone'])

    before_clear = [bytearray(pl) for pl in model]
    # plat_clear: all three planes are 0, then the one cell drawn after it
    for p in range(3):
        for i in range(0x4000):
            model[p][i] = 0
    cell(2, 1, art[0], 0x0D, 0)
    bake(3, 1, 5, 0)

    ok = True
    if os.environ.get('MP_DEBUG'):
        print('DBL[0x0f], [0xf0], [0x10], [0x01], low [0x0f], [0xf0]:', [hex(mem[0xF800 + k]) for k in (0x0f, 0xf0, 0x10, 0x01, 0x10f, 0x1f0)])
        exp=[ ( [0,3,0xc,0xf,0x30,0x33,0x3c,0x3f,0xc0,0xc3,0xcc,0xcf,0xf0,0xf3,0xfc,0xff][x>>4] ) for x in range(256)]+[[0,3,0xc,0xf,0x30,0x33,0x3c,0x3f,0xc0,0xc3,0xcc,0xcf,0xf0,0xf3,0xfc,0xff][x&15] for x in range(256)]
        badd=[(hex(k),hex(mem[0xF800+k]),hex(exp[k])) for k in range(512) if mem[0xF800+k]!=exp[k]]
        print('DBL entries wrong:',len(badd),badd[:12])
        print('mp_nibbles in memory (rodata):', [hex(x) for x in mem[syms['mp_nibbles']:syms['mp_nibbles'] + 16]] if 'mp_nibbles' in syms else 'n/a')
        for p in range(3):
            for i in range(80 * 200):
                if m.planes[p][i] != model[p][i] and (i % 80) // 2 in (2, 3) and i // 640 == 1:
                    print('after-clear plane', p, 'offset', i, 'row', (i // 80) % 8, 'byte', i % 2, 'got', hex(m.planes[p][i]), 'want', hex(model[p][i]))
    bad = [(p, i) for p in range(3) for i in range(80 * 200) if m.snapshot[p][i] != before_clear[p][i]]
    bad_after = [(p, i) for p in range(3) for i in range(80 * 200) if m.planes[p][i] != model[p][i]]
    print(('PASS' if not bad else 'FAIL') + f'  {len(spec)} cells (all 64 colour pairs; plain and inverse) through mp_tile1, {len(baked)} baked pictures through plat_put_tile, '
          f'{len(bitmaps)} bitmaps and text through plat_put_bitmap, plat_puts and plat_put: the three planes equal the model'
          + (f' ({len(bad)} bytes differ, first plane {bad[0][0]} at offset {bad[0][1]}; cells (col,row): {sorted({((i % 80) // 2, i // 640) for _, i in bad})[:12]})' if bad else ''))
    ok &= not bad
    print(('PASS' if not bad_after else 'FAIL') + '  then plat_clear and one more cell: the planes are clear but for that cell'
          + (f' ({len(bad_after)} bytes differ; cells (col,row): {sorted({((i % 80) // 2, i // 640) for _, i in bad_after})[:12]})' if bad_after else ''))
    ok &= not bad_after
    sp = mem[syms['sp_end']] | mem[syms['sp_end'] + 1] << 8
    print(('PASS' if sp == 0x7000 else 'FAIL') + f'  the stack is balanced (sp ends at ${sp:04X})')
    ok &= sp == 0x7000
    print(('PASS' if m.port == IDLE else 'FAIL') + f'  the RAM under the screen is paged back in afterwards (port $2A is ${m.port:02X}; want ${IDLE:02X})')
    ok &= m.port == IDLE
    text_ok = all(m.planes[3][i] == 32 for i in range(80 * 25)) and all(m.planes[3][0x800 + i] == 7 for i in range(80 * 25))
    print(('PASS' if text_ok else 'FAIL') + '  plat_init blanks the text page (spaces, attribute 7)')
    ok &= text_ok
    want = [(0x29, 0x45), (0x1C, 6), (0x1D, 25), (0x1C, 9), (0x1D, 7)]
    print(('PASS' if ports == want else 'FAIL') + f'  plat_init sets the colour 80 column display and the CRT controller {[(hex(a), hex(b)) for a, b in ports]}')
    ok &= ports == want
    print(f'      ({count} instructions replayed, {m.wram_writes} stores went to the RAM under the screen)')
    ok &= minirow_test()
    ok &= minirow_art_test()
    return 0 if ok else 1


HARNESS_ROWS = '''        SECTION code_user
        org     $0100
        PUBLIC  _font_8x8_bbc_system, __port29_copy, _view_tile_art
        defc    _view_tile_art = 0
        EXTERN  _plat_put_minirow, _plat_init
start:  ld      sp,$7000
        call    _plat_init
        ld      ix,rows
nextrow:
        ld      a,(ix+0)
        cp      255
        jr      z,rowsdone
        ld      h,0
        ld      l,a
        push    hl                      ; ty
        ld      l,(ix+1)
        ld      h,(ix+2)
        push    hl                      ; the colours
        ld      hl,0
        push    hl                      ; base: not used
        push    hl                      ; view
        call    _plat_put_minirow
        pop     hl
        pop     hl
        pop     hl
        pop     hl
        ld      de,3
        add     ix,de
        jr      nextrow
rowsdone:
        ld      (sp_end),sp
fin:    halt
__port29_copy:
        defb    $85
sp_end: defw    0
_font_8x8_bbc_system:
        BINARY  "font.bin"
rows:
        ROWS
'''


HARNESS_ART = '''        SECTION code_user
        org     $0100
        PUBLIC  _font_8x8_bbc_system, __port29_copy, _view_tile_art, _mm_row
        defc    _view_tile_art = 0
        EXTERN  _plat_put_minirow, _plat_init
start:  ld      sp,$7000
        call    _plat_init
        ld      ix,rows
nextrow:
        ld      a,(ix+0)
        cp      255
        jr      z,rowsdone
        ld      e,(ix+1)
        ld      d,(ix+2)                ; the row's data: into mm_row a byte at a time (the replay sees only these stores)
        ld      hl,_mm_row
        ld      bc,432
fill:   ld      a,(de)
        ld      (hl),a
        inc     de
        inc     hl
        dec     bc
        ld      a,b
        or      c
        jr      nz,fill
        ld      h,0
        ld      l,(ix+0)
        push    hl                      ; sy
        call    _plat_put_minirow
        pop     hl
        inc     ix
        inc     ix
        inc     ix
        jr      nextrow
rowsdone:
        ld      (sp_end),sp
fin:    halt
__port29_copy:
        defb    $85
sp_end: defw    0
_mm_row: defs   432
_font_8x8_bbc_system:
        BINARY  "font.bin"
rows:
        ROWS
'''


def minirow_art_test():
    """plat_put_minirow with HAVE_MINIMAP_ART: for each plane the row's three lines of 48 bytes (mm_row: plane k line j at 144 k +
    48 j) go to lines 52 + 3 sy, 53 + 3 sy and 54 + 3 sy of that plane, 16 bytes in."""
    rng = random.Random(11)
    sel = [0, 1, 47, 23, 24, 5, 5, 0]
    data = [bytes(rng.randrange(256) for _ in range(432)) for _ in sel]
    src = HARNESS_ART.replace('        ROWS\n', ''.join(f'        defb {sy}\n        defw d{i}\n' for i, sy in enumerate(sel)) + '        defb 255\n'
                              + ''.join(f'd{i}:     defb {",".join(str(c) for c in d)}\n' for i, d in enumerate(data)))
    model = [bytearray(0x4000) for _ in range(3)]
    for sy, d in zip(sel, data):
        for k in range(3):
            for line in range(3):
                for i in range(48):
                    model[k][(52 + 3 * sy + line) * 80 + 16 + i] = d[k * 144 + line * 48 + i]
    with tempfile.TemporaryDirectory() as tmp:
        open(os.path.join(tmp, 'h.asm'), 'w').write(src)
        open(os.path.join(tmp, 'font.bin'), 'wb').write(bytes(96 * 8))
        os.makedirs(os.path.join(tmp, 'build', 'common'))
        open(os.path.join(tmp, 'build', 'common', 'tiles_640x200_3bpp.bin'), 'wb').write(bytes(345 * 24))
        out = subprocess.run([Z80ASM, '-b', '-m', '-DHAVE_MINIMAP_ART', '-I' + ROOT, '-oh.bin', 'h.asm',
                              os.path.join(ROOT, 'target/multi8/plat_multi8.asm')], cwd=tmp, capture_output=True, text=True)
        if out.returncode or out.stderr.strip():
            print(out.stdout + out.stderr)
            print('FAIL  the art mini map row test does not assemble')
            return False
        syms = {}
        for line in open(os.path.join(tmp, 'h.map')):
            m = re.match(r'(\S+)\s+= \$([0-9A-F]+) ;', line)
            if m:
                syms[m.group(1)] = int(m.group(2), 16)
        img = bytearray(65536)
        for sec in ('code_user', 'data_user', 'rodata_user', 'data_fcntl'):
            p = os.path.join(tmp, f'h_{sec}.bin')
            if os.path.exists(p):
                b = open(p, 'rb').read()
                img[syms[f'__{sec}_head']:syms[f'__{sec}_head'] + len(b)] = b
        first = os.path.join(tmp, 'h.bin')
        if os.path.exists(first) and os.path.getsize(first):
            b = open(first, 'rb').read()
            img[0x100:0x100 + len(b)] = b
        open(os.path.join(tmp, 'img.bin'), 'wb').write(img)
        with open(os.path.join(tmp, 'trace.txt'), 'w') as tf:
            subprocess.run([TICKS, '-pc', '100', '-end', f'{syms["fin"]:x}', '-counter', '400000000', '-trace',
                            '-output', 'mem.out', 'img.bin'], cwd=tmp, stdout=tf, stderr=subprocess.DEVNULL)
        mem = open(os.path.join(tmp, 'mem.out'), 'rb').read()
        m = Machine()
        replay(os.path.join(tmp, 'trace.txt'), m, -1)
    bad = [(p, i) for p in range(3) for i in range(80 * 200) if m.planes[p][i] != model[p][i]]
    sp = mem[syms['sp_end']] | mem[syms['sp_end'] + 1] << 8
    ok = not bad and sp == 0x7000 and m.port == IDLE
    print(('PASS' if ok else 'FAIL') + f'  plat_put_minirow (art): {len(sel)} rows, each plane\'s three lines written to the right lines of that plane (a row drawn again is '
          f'overwritten), the stack is balanced and the RAM under the screen is paged back in'
          + (f' ({len(bad)} bytes differ, first plane {bad[0][0]} at offset {bad[0][1]}, line {bad[0][1] // 80}, byte {bad[0][1] % 80}; sp ${sp:04X}; port ${m.port:02X})' if bad or sp != 0x7000 or m.port != IDLE else ''))
    return ok


def minirow_test():
    """plat_put_minirow: each of a row's 96 colours is a block of four pixels by two lines (tile row ty is lines 2 ty and 2 ty + 1), in the right bytes of the planes."""
    rng = random.Random(7)
    sel = [0, 1, 2, 47, 48, 94, 95, 5, 5, 0]                       # the last rows again with other colours (they must overwrite)
    data = [[rng.randrange(16) for _ in range(96)] for _ in sel]
    data[1] = [7] * 96
    data[2] = [0] * 96
    data[8] = [x ^ 7 for x in data[7]]                              # (colour bit 3 is a tile of the base map: a checker)
    src = HARNESS_ROWS.replace('        ROWS\n', ''.join(f'        defb {sy}\n        defw d{i}\n' for i, sy in enumerate(sel)) + '        defb 255\n'
                                + ''.join(f'd{i}:     defb {",".join(str(c) for c in d)}\n' for i, d in enumerate(data)))
    model = [bytearray(0x4000) for _ in range(3)]
    for sy, d in zip(sel, data):
        for x, c in enumerate(d):
            for line in range(2 * sy, 2 * sy + 2):
                for p in range(3):
                    byte = line * 80 + 8 + x // 2
                    full = 0xF0 if x % 2 == 0 else 0x0F
                    mask = full & ((0x55 if line == 2 * sy + 1 else 0xAA) if c & 8 else 0xFF)
                    model[p][byte] = (model[p][byte] & ~full & 0xFF) | (mask if (c >> p) & 1 else 0)
    with tempfile.TemporaryDirectory() as tmp:
        open(os.path.join(tmp, 'h.asm'), 'w').write(src)
        open(os.path.join(tmp, 'font.bin'), 'wb').write(bytes(96 * 8))
        os.makedirs(os.path.join(tmp, 'build', 'common'))
        open(os.path.join(tmp, 'build', 'common', 'tiles_640x200_3bpp.bin'), 'wb').write(bytes(345 * 24))
        out = subprocess.run([Z80ASM, '-b', '-m', '-I' + ROOT, '-oh.bin', 'h.asm', os.path.join(ROOT, 'target/multi8/plat_multi8.asm')],
                             cwd=tmp, capture_output=True, text=True)
        if out.returncode or out.stderr.strip():
            print(out.stdout + out.stderr)
            print('FAIL  the mini map row test does not assemble')
            return False
        syms = {}
        for line in open(os.path.join(tmp, 'h.map')):
            m = re.match(r'(\S+)\s+= \$([0-9A-F]+) ;', line)
            if m:
                syms[m.group(1)] = int(m.group(2), 16)
        img = bytearray(65536)
        for sec in ('code_user', 'data_user', 'rodata_user', 'data_fcntl'):
            p = os.path.join(tmp, f'h_{sec}.bin')
            if os.path.exists(p):
                b = open(p, 'rb').read()
                img[syms[f'__{sec}_head']:syms[f'__{sec}_head'] + len(b)] = b
        first = os.path.join(tmp, 'h.bin')
        if os.path.exists(first) and os.path.getsize(first):
            b = open(first, 'rb').read()
            img[0x100:0x100 + len(b)] = b
        open(os.path.join(tmp, 'img.bin'), 'wb').write(img)
        with open(os.path.join(tmp, 'trace.txt'), 'w') as tf:
            subprocess.run([TICKS, '-pc', '100', '-end', f'{syms["fin"]:x}', '-counter', '400000000', '-trace',
                            '-output', 'mem.out', 'img.bin'], cwd=tmp, stdout=tf, stderr=subprocess.DEVNULL)
        mem = open(os.path.join(tmp, 'mem.out'), 'rb').read()
        m = Machine()
        replay(os.path.join(tmp, 'trace.txt'), m, -1)
        top = mem[syms['mm_msk'] - 1:syms['mm_msk']]               # (the buffer's variables are in the low RAM: no check needed)
    bad = [(p, i) for p in range(3) for i in range(80 * 200) if m.planes[p][i] != model[p][i]]
    sp = mem[syms['sp_end']] | mem[syms['sp_end'] + 1] << 8
    ok = not bad and sp == 0x7000 and m.port == IDLE
    print(('PASS' if ok else 'FAIL') + f'  plat_put_minirow: {len(sel)} rows of 96 colours are blocks of 4x2 pixels in the three planes (a row drawn again is overwritten), '
          f'the stack is balanced and the RAM under the screen is paged back in'
          + (f' ({len(bad)} bytes differ, first plane {bad[0][0]} at offset {bad[0][1]}, line {bad[0][1] // 80}, byte {bad[0][1] % 80}; sp ${sp:04X}; port ${m.port:02X})' if bad or sp != 0x7000 or m.port != IDLE else ''))
    return ok


if __name__ == '__main__':
    sys.exit(main())
