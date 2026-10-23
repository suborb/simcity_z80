#!/usr/bin/env python3
"""The PC-8801 placer (target/pc88/plat_pc88.asm) under z88dk-ticks.

z88dk-ticks has flat memory, so the placer runs with its instruction trace on and this script replays the trace against a
model of the machine's plane paging and ALU (Takeda's, src/vm/pc8801/pc88.cpp), as the V1 (plane by plane) and the V2 (ALU)
build.  The placer is called as the game's C code calls it for cells in every colour combination, baked pictures, sprites,
text, plat_init, plat_clear, the mini map rows and scrolling; the planes are compared with a model of each cell, and so are
the stack and the paging state left behind.

  usage: test/pc88/run.py
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
SCREEN = 0xC000

CELLREC = 6                             # bytes in a cell's record: col, row, art (2), attr, inverse

HARNESS = '''        SECTION code_user
        org     $0100
        PUBLIC  _font_8x8_bbc_system, __CLIB_PC8800_V2_ENABLED, _view_tile_art, _mm_row
        defc    __CLIB_PC8800_V2_ENABLED = V2FLAG
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
sp_end: defw    0
_mm_row: defs   432
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
    """The video memory behind $C000-$FFFF and the ports that page it (Takeda's pc88.cpp)."""

    def __init__(self):
        self.plane = 0                                          # ports $5C-$5F: 0 the RAM, 1 blue, 2 red, 3 green
        self.p32 = 0x98                                         # bit 6: the ALU
        self.p35 = 0                                            # bit 7: the screen is paged in (with the ALU)
        self.alu = 0                                            # port $34
        self.planes = [bytearray(0x4000) for _ in range(3)]     # blue, red, green
        self.ram_writes = 0                                     # stores to the RAM underneath
        self.alu_reads = 0                                      # reads through the ALU (only plat_scroll reads)
        self.latch = [0, 0, 0]                                  # what the last read through the ALU found in each plane
        self.snapshot = None
        self.low = {}                                           # the stores to the low RAM that a block copy to the screen reads

    def sel(self):
        if self.p32 & 0x40:
            return 8 if self.p35 & 0x80 else 0
        return self.plane

    def out(self, port, val):
        if port in (0x5C, 0x5D, 0x5E):
            self.plane = port - 0x5B
        elif port == 0x5F:
            self.plane = 0
        elif port == 0x32:
            self.p32 = val
        elif port == 0x35:
            self.p35 = val
        elif port == 0x34:
            self.alu = val
        if self.p32 & 0x40:
            self.plane = 0                                      # (from M88, as Takeda has it)

    def write(self, addr, val):
        off = addr - SCREEN
        s = self.sel()
        if s in (1, 2, 3):
            self.planes[s - 1][off] = val
        elif s == 8 and (self.p35 & 0x30) == 0x10:              # a store puts the latches back in all three planes
            for i in range(3):
                self.planes[i][off] = self.latch[i]
        elif s == 8:
            for i in range(3):
                op = (self.alu >> i) & 0x11
                if op == 0x00:
                    self.planes[i][off] &= ~val & 0xFF
                elif op == 0x01:
                    self.planes[i][off] |= val
                elif op == 0x10:
                    self.planes[i][off] ^= val
        else:
            self.ram_writes += 1

    def read(self, addr):
        off = addr - SCREEN
        s = self.sel()
        if s in (1, 2, 3):
            return self.planes[s - 1][off]
        if s == 8:
            self.alu_reads += 1
            self.latch = [self.planes[i][off] for i in range(3)]
        return 0


def replay(trace_path, m, snap_pc):
    """Replay the trace: only the instructions that write to the screen or the ports matter."""
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
                bc, de, hl, af = (int(g.group(k), 16) for k in (2, 3, 4, 5))
                regs = {'pc': int(g.group(1), 16), 'bc': bc, 'de': de, 'hl': hl, 'a': af >> 8,
                        'b': bc >> 8, 'c': bc & 255, 'd': de >> 8, 'e': de & 255, 'h': hl >> 8, 'l': hl & 255}
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
            if text == 'out (c),a':
                m.out(regs['c'], a)
                out_log.append((regs['c'], a))
            elif text.startswith('out ('):
                port = int(text[5:text.index(')')].replace('$', ''), 16)
                m.out(port, a)
                out_log.append((port, a))
            elif text == 'or (hl)' and m.sel() in (1, 2, 3) and SCREEN <= hl:
                or_mask = a                                  # the flat memory the tracer runs in has no planes: a is worked out here
            elif text.startswith('ld (hl),') and hl >= SCREEN:
                src = text[len('ld (hl),'):]
                val = int(src[1:], 16) if src.startswith('$') else (int(src) if src.isdigit() else regs[src])
                if m.sel() == 0:
                    m.ram_writes += 1
                elif or_mask is not None:
                    m.write(hl, or_mask | m.read(hl))
                else:
                    m.write(hl, val)
                or_mask = None
            elif text.startswith('ld (hl),') and hl < SCREEN:
                src = text[len('ld (hl),'):]
                m.low[hl] = int(src[1:], 16) if src.startswith('$') else (int(src) if src.isdigit() else regs[src])
            elif text in ('ldir', 'lddr'):
                if de >= SCREEN and m.sel():
                    m.write(de, m.read(hl) if hl >= SCREEN else m.low.get(hl, 0))
    return out_log, n


def main():
    ok = True
    ok &= table_test()
    for v2 in (1, 0):
        for steps in ([(1, 0), (0, 1), (-1, 0), (0, -1), (8, 0), (-8, 0), (0, 8), (0, -8), (1, 1), (-2, 3), (3, -2), (-2, -2)],
                      [(39, 0)], [(-39, 0)], [(0, 18)], [(0, -18)], [(-5, -7)], [(5, 7), (-6, 2)]):
            ok &= scroll_test(v2, steps)
    for v2 in (1, 0):
        ok &= run(v2) == 0
    for v2 in (1, 0):
        ok &= text_attr_test(v2)
    ok &= minirow_art_test(True)
    ok &= minirow_art_test(False)
    return 0 if ok else 1


def table_test():
    """The doubling table is read while a plane is paged in: it must be below the screen window."""
    src = open(os.path.join(ROOT, 'target/pc88/plat_pc88.asm')).read()
    g = re.search(r'ELSE\n\s*defc\s+DBL\s*=\s*\$([0-9A-Fa-f]+)', src)
    addr = int(g.group(1), 16) if g else 0xFFFF
    ok = addr + 0x200 <= SCREEN and addr % 256 == 0
    print(('PASS' if ok else 'FAIL') + f'  the doubling table (${addr:04X}-${addr + 0x1FF:04X}) is in the low RAM, not under the screen window')
    return ok


HARNESS_SCROLL = '''        SECTION code_user
        org     $0100
        PUBLIC  _font_8x8_bbc_system, __CLIB_PC8800_V2_ENABLED, _view_tile_art, _mm_row
        defc    __CLIB_PC8800_V2_ENABLED = V2FLAG
        defc    _view_tile_art = art
        EXTERN  _plat_put_tile, _plat_scroll, _plat_init
start:  ld      sp,$7000
        call    _plat_init
        ld      c,6                     ; the map: rows 6 to 24, every cell a different picture
nextrow:
        ld      b,0
nextcol:
        push    bc
        ld      h,0
        ld      l,b
        push    hl                      ; col
        ld      l,c
        push    hl                      ; row
        ld      hl,(idx)
        ld      d,h
        ld      e,l
        inc     de
        ld      (idx),de
        add     hl,hl
        add     hl,hl
        add     hl,hl
        ld      de,art
        add     hl,de
        push    hl                      ; art: picture idx
        ld      hl,0
        push    hl
        push    hl
        call    _plat_put_tile
        ld      hl,10
        add     hl,sp
        ld      sp,hl
        pop     bc
        inc     b
        ld      a,b
        cp      40
        jr      nz,nextcol
        inc     c
        ld      a,c
        cp      25
        jr      nz,nextrow
        ld      ix,scrolls
nextscroll:
        ld      a,(ix+0)
        cp      $7F
        jr      z,scrolled
        ld      hl,6
        push    hl                      ; row
        ld      hl,19
        push    hl                      ; rows
        ld      l,a
        ld      h,0
        push    hl                      ; dx (the low byte is the number)
        ld      a,(ix+1)
        ld      l,a
        push    hl                      ; dy
        call    _plat_scroll
        ld      hl,8
        add     hl,sp
        ld      sp,hl
        inc     ix
        inc     ix
        jr      nextscroll
scrolled:
        ld      (sp_end),sp
fin:    halt
idx:    defw    0
sp_end: defw    0
_mm_row: defs   432
_font_8x8_bbc_system:
        BINARY  "font.bin"
scrolls:
        SCROLLS
art:
'''


def scroll_test(v2, steps):
    """plat_scroll: the map (rows 6 to 24, a different picture in every cell) is scrolled by a series of steps.  Each cell that is
    not exposed must show the picture of the cell it came from, in the planes and in the cache; the exposed ones are marked."""
    NPIC = 760
    rng = random.Random(5)
    blob = bytes(rng.randrange(256) for _ in range(NPIC * 24))
    src = HARNESS_SCROLL.replace('V2FLAG', str(v2)).replace('        SCROLLS\n', ''.join(f'        defb {dx & 255},{dy & 255}\n' for dx, dy in steps) + '        defb $7F,0\n')
    # the model: cell (x, y) of the map holds picture n or None (not known)
    cells = [[y * 40 + x for x in range(40)] for y in range(19)]
    for dx, dy in steps:
        new = [[None] * 40 for _ in range(19)]
        for y in range(19):
            for x in range(40):
                if 0 <= x + dx < 40 and 0 <= y + dy < 19:
                    new[y][x] = cells[y + dy][x + dx]
        cells = new
    with tempfile.TemporaryDirectory() as tmp:
        open(os.path.join(tmp, 'h.asm'), 'w').write(src)
        open(os.path.join(tmp, 'font.bin'), 'wb').write(bytes(96 * 8))
        os.makedirs(os.path.join(tmp, 'build', 'common'))
        open(os.path.join(tmp, 'build', 'common', 'tiles_640x200_3bpp.bin'), 'wb').write(blob)
        out = subprocess.run([Z80ASM, '-b', '-m', '-DDBL_AT=0x8000', '-I' + ROOT, '-oh.bin', 'h.asm',
                              os.path.join(ROOT, 'target/pc88/plat_pc88.asm')], cwd=tmp, capture_output=True, text=True)
        if out.returncode or out.stderr.strip():
            print(out.stdout + out.stderr)
            print('FAIL  the scroll test does not assemble')
            return False
        syms = {}
        for line in open(os.path.join(tmp, 'h.map')):
            g = re.match(r'(\S+)\s+= \$([0-9A-F]+) ;', line)
            if g:
                syms[g.group(1)] = int(g.group(2), 16)
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
            subprocess.run([TICKS, '-pc', '100', '-end', f'{syms["fin"]:x}', '-counter', '4000000000', '-trace',
                            '-output', 'mem.out', 'img.bin'], cwd=tmp, stdout=tf, stderr=subprocess.DEVNULL)
        mem = open(os.path.join(tmp, 'mem.out'), 'rb').read()
        m = Machine()
        replay(os.path.join(tmp, 'trace.txt'), m, -1)
    def double(b):
        w = 0
        for i in range(7, -1, -1):
            w = w << 2 | (3 if b >> i & 1 else 0)
        return w >> 8, w & 0xFF
    bad_px, bad_cache = [], []
    art = syms['art']
    cache = syms['mp_cache']
    for y in range(19):
        for x in range(40):
            n = cells[y][x]
            row = 6 + y
            ent = cache + ((row - 6) * 40 + x) * 2
            word = mem[ent] | mem[ent + 1] << 8
            if n is None:
                if word != 0xFFFF:
                    bad_cache.append((x, y, 'exposed, word', hex(word)))
                continue
            if word != art + 8 * n:
                bad_cache.append((x, y, hex(word), hex(art + 8 * n)))
            for p in range(3):
                for r in range(8):
                    for half, px in enumerate(double(blob[n * 24 + p * 8 + r])):
                        if m.planes[p][row * 640 + r * 80 + x * 2 + half] != px:
                            bad_px.append((x, y, p))
    sp = mem[syms['sp_end']] | mem[syms['sp_end'] + 1] << 8
    paged = m.sel() == 0 and m.plane == 0 and not (m.p35 & 0x80)
    ok = not bad_px and not bad_cache and sp == 0x7000 and paged
    known = sum(c is not None for r in cells for c in r)
    print(('PASS' if ok else 'FAIL') + f'  [{"V2 (ALU)" if v2 else "V1"}] plat_scroll: {len(steps)} steps; the {known} cells left in the map show the picture they came from, '
          f'in the planes and in the cache, and the rest are marked; the stack is balanced and the RAM is paged back in'
          + (f' (pixels: {sorted(set(bad_px))[:6]}; cache: {bad_cache[:4]}; sp ${sp:04X}; paged {paged})' if not ok else ''))
    return ok



def run(v2):
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
    src = HARNESS.replace('V2FLAG', str(v2)).replace('CELLREC', str(CELLREC)).replace('        CASES2\n', c2).replace('        OVERLAYS\n', ov).replace('        BCASES2\n', bk(baked2)).replace('        BCASES\n', bk(baked)).replace('        BITMAPS\n', bspec).replace('        TEXTS\n', tspec)
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
        out = subprocess.run([Z80ASM, '-b', '-m', '-DDBL_AT=0x8000', '-I' + ROOT, '-oh.bin', 'h.asm',
                              os.environ.get('MP_ASM', os.path.join(ROOT, 'target/pc88/plat_pc88.asm'))],
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
    tag = 'V2 (ALU)' if v2 else 'V1'
    bad = [(p, i) for p in range(3) for i in range(80 * 200) if m.snapshot[p][i] != before_clear[p][i]]
    bad_after = [(p, i) for p in range(3) for i in range(80 * 200) if m.planes[p][i] != model[p][i]]
    print(('PASS' if not bad else 'FAIL') + f'  {len(spec)} cells (all 64 colour pairs; plain and inverse) through mp_tile1, {len(baked)} baked pictures through plat_put_tile, '
          f'{len(bitmaps)} bitmaps and text through plat_put_bitmap, plat_puts and plat_put: the three planes equal the model'
          + (f' ({len(bad)} bytes differ, first plane {bad[0][0]} at offset {bad[0][1]}; cells (col,row): {sorted({((i % 80) // 2, i // 640) for _, i in bad})[:12]})' if bad else ''))
    ok &= not bad
    if bad and os.environ.get('PC_DEBUG'):
        cs = sorted({((i % 80) // 2, i // 640) for _, i in bad})
        print('FAILCELLS', len(cs), cs, 'baked', [(c, r) for c, r, _, _ in baked], 'baked2', [(c, r) for c, r, _, _ in baked2], 'spec', [(c, r) for c, r, *_ in spec][:10])
        for p_, i in bad[:24]:
            print('plane', p_, 'cell', ((i % 80) // 2, i // 640), 'line', (i // 80) % 8, 'byte', i % 2, 'got', hex(m.snapshot[p_][i]), 'want', hex(before_clear[p_][i]))
    print(('PASS' if not bad_after else 'FAIL') + '  then plat_clear and one more cell: the planes are clear but for that cell'
          + (f' ({len(bad_after)} bytes differ; cells (col,row): {sorted({((i % 80) // 2, i // 640) for _, i in bad_after})[:12]})' if bad_after else ''))
    ok &= not bad_after
    sp = mem[syms['sp_end']] | mem[syms['sp_end'] + 1] << 8
    print(('PASS' if sp == 0x7000 else 'FAIL') + f'  [{tag}] the stack is balanced (sp ends at ${sp:04X})')
    ok &= sp == 0x7000
    paged = m.sel() == 0 and m.plane == 0 and not (m.p35 & 0x80) and not (m.p32 & 0x40)
    print(('PASS' if paged else 'FAIL') + f'  [{tag}] the RAM under the screen is paged back in afterwards (plane {m.plane}, port $32 ${m.p32:02X}, port $35 ${m.p35:02X})')
    ok &= paged
    want = ([(0x32, 0x98)] if v2 else []) + [(0x53, 1), (0x52, 0)] + [(0x54 + n, n) for n in range(8)]
    ports = [p for p in ports if p[0] in (0x53, 0x52, 0x32) or 0x54 <= p[0] <= 0x5B][:len(want)]
    print(('PASS' if ports == want else 'FAIL') + f'  [{tag}] plat_init turns the text off and sets the palette (entry n is colour n) {[(hex(a), hex(b)) for a, b in ports]}')
    ok &= ports == want
    noalu = not m.alu_reads
    print(('PASS' if noalu else 'FAIL') + f'  [{tag}] the placer never reads through the ALU ({m.alu_reads} reads)')
    ok &= noalu
    print(f'      ({count} instructions replayed, {m.ram_writes} stores went to the RAM under the screen)')
    return 0 if ok else 1


HARNESS_ART = '''        SECTION code_user
        org     $0100
        PUBLIC  _font_8x8_bbc_system, __CLIB_PC8800_V2_ENABLED, _view_tile_art, _mm_row
        defc    __CLIB_PC8800_V2_ENABLED = V2FLAG
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
sp_end: defw    0
_mm_row: defs   432
_font_8x8_bbc_system:
        BINARY  "font.bin"
rows:
        ROWS
'''


HARNESS_FLAT = '''        SECTION code_user
        org     $0100
        PUBLIC  _font_8x8_bbc_system, __CLIB_PC8800_V2_ENABLED, _view_tile_art
        defc    __CLIB_PC8800_V2_ENABLED = V2FLAG
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
        ld      l,(ix+0)
        push    hl                      ; sy
        ld      e,(ix+1)
        ld      d,(ix+2)
        push    de                      ; the colours
        call    _plat_put_minirow
        pop     de
        pop     hl
        inc     ix
        inc     ix
        inc     ix
        jr      nextrow
rowsdone:
        ld      (sp_end),sp
fin:    halt
sp_end: defw    0
_font_8x8_bbc_system:
        BINARY  "font.bin"
rows:
        ROWS
'''


HARNESS_ATTR = '''        SECTION code_user
        org     $0100
        PUBLIC  _font_8x8_bbc_system, __CLIB_PC8800_V2_ENABLED, _view_tile_art
        defc    __CLIB_PC8800_V2_ENABLED = V2FLAG
        defc    _view_tile_art = 0
        EXTERN  _plat_put, _plat_text_attr, _plat_init
start:  ld      sp,$7000
        call    _plat_init
        ld      ix,ops
next:   ld      a,(ix+0)
        cp      255
        jr      z,done
        ld      h,0
        ld      l,(ix+1)
        push    hl                      ; col
        ld      l,(ix+2)
        push    hl                      ; row
        ld      l,(ix+3)
        push    hl                      ; the character, or the count
        ld      a,(ix+0)
        or      a
        jr      nz,attr
        call    _plat_put
        pop     hl
        pop     hl
        pop     hl
        jr      advance
attr:   ld      l,(ix+4)
        push    hl                      ; the attribute
        call    _plat_text_attr
        pop     hl
        pop     hl
        pop     hl
        pop     hl
advance:
        ld      de,5
        add     ix,de
        jr      next
done:   ld      (sp_end),sp
fin:    halt
sp_end: defw    0
_font_8x8_bbc_system:
        BINARY  "font.bin"
ops:
        OPS
'''


def text_attr_test(v2):
    """plat_text_attr: text is drawn (white on black), recoloured, drawn again as a screen of tables does and recoloured again: the
    planes are what each cell would be drawn as in its last attribute."""
    rng = random.Random(7)
    font = bytes(rng.randrange(256) for _ in range(96 * 8))
    ops = []
    state = {}                                             # (col, row) -> [char, attr]

    def put(col, row, ch):
        ops.append((0, col, row, ord(ch), 0))
        state[(col, row)] = [ch, 7]

    def attr(col, row, n, a):
        ops.append((1, col, row, n, a))
        for c in range(col, col + n):                      # (a cell with nothing drawn is a blank glyph, in the paper colour)
            state.setdefault((c, row), [None, 7])[1] = a
    text = 'FISCAL BUDGET AND SO ON'
    for row in (0, 2, 9, 23):                              # drawn plain, then coloured over more than the text
        for i, ch in enumerate(text):
            put(i + 4, row, ch)
        attr(4, row, 32, 0x0F)                             # white on blue
    for row in (3, 4):                                     # coloured in pieces, as a row of labels and figures is
        for i, ch in enumerate(text):
            put(i + 4, row, ch)
        attr(4, row, 6, 0x06)                              # yellow on black
        attr(10, row, 9, 0x2D)
        attr(19, row, 8, 0x3A)
    for row in (0, 2, 3):                                  # the screen drawn again, as a step does: plain, then coloured again
        for i, ch in enumerate(text):
            put(i + 4, row, ch)
        attr(4, row, 12, 0x12 if row == 0 else 0x07)
    attr(0, 5, 3, 0x0F)
    src = HARNESS_ATTR.replace('V2FLAG', str(v2)).replace('        OPS\n', ''.join(f'        defb {k},{c},{r},{a},{b}\n' for k, c, r, a, b in ops) + '        defb 255\n')
    model = [bytearray(0x4000) for _ in range(3)]

    def double(b):
        w = 0
        for i in range(7, -1, -1):
            w = w << 2 | (3 if b >> i & 1 else 0)
        return w >> 8, w & 0xFF
    for (col, row), (ch, a) in state.items():
        glyph = bytes(8) if ch is None else font[(ord(ch) - 32) * 8:(ord(ch) - 32) * 8 + 8]
        for p in range(3):
            ink = 0xFF if a >> p & 1 else 0
            paper = 0xFF if a >> (3 + p) & 1 else 0
            for r in range(8):
                for half, px in enumerate(double(glyph[r])):
                    model[p][row * 640 + r * 80 + col * 2 + half] = (px & ink) | (~px & 0xFF & paper)
    with tempfile.TemporaryDirectory() as tmp:
        open(os.path.join(tmp, 'h.asm'), 'w').write(src)
        open(os.path.join(tmp, 'font.bin'), 'wb').write(font)
        os.makedirs(os.path.join(tmp, 'build', 'common'))
        open(os.path.join(tmp, 'build', 'common', 'tiles_640x200_3bpp.bin'), 'wb').write(bytes(345 * 24))
        out = subprocess.run([Z80ASM, '-b', '-m', '-DDBL_AT=0x8000', '-I' + ROOT, '-oh.bin', 'h.asm',
                              os.path.join(ROOT, 'target/pc88/plat_pc88.asm')], cwd=tmp, capture_output=True, text=True)
        if out.returncode or out.stderr.strip():
            print(out.stdout + out.stderr)
            print('FAIL  the text recolour test does not assemble')
            return False
        syms = {}
        for line in open(os.path.join(tmp, 'h.map')):
            m = re.match(r'(\S+)\s+= \$([0-9A-F]+) ;', line)
            if m:
                syms[m.group(1)] = int(m.group(2), 16)
        img = bytearray(65536)
        for sec in ('code_user', 'data_user', 'rodata_user', 'data_fcntl'):
            pth = os.path.join(tmp, f'h_{sec}.bin')
            if os.path.exists(pth):
                b = open(pth, 'rb').read()
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
    if os.environ.get('DUMPBAD'):
        print(sorted({(i % 80 // 2, i // 640) for p, i in bad})[:40])
    sp = mem[syms['sp_end']] | mem[syms['sp_end'] + 1] << 8
    ok = not bad and sp == 0x7000 and m.sel() == 0 and m.plane == 0
    print(('PASS' if ok else 'FAIL') + f'  [{"V2" if v2 else "V1"}] plat_text_attr: {len(ops)} operations (text, recoloured, drawn again, recoloured again): the planes equal the model, '
          f'the stack is balanced and the RAM under the screen is paged back in'
          + (f' ({len(bad)} bytes differ, first plane {bad[0][0]} at offset {bad[0][1]}, line {bad[0][1] // 80}, byte {bad[0][1] % 80}; sp ${sp:04X})' if not ok else ''))
    return ok


def minirow_art_test(art=True):
    """plat_put_minirow: for each plane, the row's three lines of 48 bytes (mm_row: plane k line j at 144 k + 48 j) go to lines
    52 + 3 sy, 53 + 3 sy and 54 + 3 sy of that plane, 16 bytes in."""
    rng = random.Random(11)
    sel = [0, 1, 47, 23, 24, 5, 5, 0]
    model = [bytearray(0x4000) for _ in range(3)]
    if art:
        data = [bytes(rng.randrange(256) for _ in range(432)) for _ in sel]
        src = HARNESS_ART.replace('V2FLAG', '1').replace('        ROWS\n', ''.join(f'        defb {sy}\n        defw d{i}\n' for i, sy in enumerate(sel)) + '        defb 255\n'
                                  + ''.join(f'd{i}:     defb {",".join(str(c) for c in d)}\n' for i, d in enumerate(data)))
        for sy, d in zip(sel, data):
            for k in range(3):
                for line in range(3):
                    for i in range(48):
                        model[k][(52 + 3 * sy + line) * 80 + 16 + i] = d[k * 144 + line * 48 + i]
    else:                                   # flat colours: 96 a row (0..7), blocks of 4 pixels by 3 lines in the three planes
        data = [[rng.randrange(16) for _ in range(96)] for _ in sel]
        data[1] = [7] * 96
        data[2] = [0] * 96
        src = HARNESS_FLAT.replace('V2FLAG', '1').replace('        ROWS\n', ''.join(f'        defb {sy}\n        defw d{i}\n' for i, sy in enumerate(sel)) + '        defb 255\n'
                                  + ''.join(f'd{i}:     defb {",".join(str(c) for c in d)}\n' for i, d in enumerate(data)))
        for sy, d in zip(sel, data):
            for x, c in enumerate(d):
                for line in range(52 + 3 * sy, 52 + 3 * sy + 3):
                    for k in range(3):
                        byte = line * 80 + 16 + x // 2
                        mask = 0xF0 if x % 2 == 0 else 0x0F
                        if c & 8:                   # the base map's tile: a checker of its colour, the other way round on the middle line
                            mask &= 0x55 if (line - 52 - 3 * sy) == 1 else 0xAA
                            full = 0xF0 if x % 2 == 0 else 0x0F
                            model[k][byte] = (model[k][byte] & ~full & 0xFF) | (mask if (c >> k) & 1 else 0)
                        else:
                            model[k][byte] = (model[k][byte] & ~mask & 0xFF) | (mask if (c >> k) & 1 else 0)
    with tempfile.TemporaryDirectory() as tmp:
        open(os.path.join(tmp, 'h.asm'), 'w').write(src)
        open(os.path.join(tmp, 'font.bin'), 'wb').write(bytes(96 * 8))
        os.makedirs(os.path.join(tmp, 'build', 'common'))
        open(os.path.join(tmp, 'build', 'common', 'tiles_640x200_3bpp.bin'), 'wb').write(bytes(345 * 24))
        out = subprocess.run([Z80ASM, '-b', '-m', '-DDBL_AT=0x8000'] + (['-DHAVE_MINIMAP_ART'] if art else []) + ['-I' + ROOT, '-oh.bin', 'h.asm',
                              os.path.join(ROOT, 'target/pc88/plat_pc88.asm')], cwd=tmp, capture_output=True, text=True)
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
    bad = [(p, i) for p in range(3) for i in range(80 * 200) if m.planes[p][i] != model[p][i]]
    sp = mem[syms['sp_end']] | mem[syms['sp_end'] + 1] << 8
    paged = m.sel() == 0 and m.plane == 0
    ok = not bad and sp == 0x7000 and paged
    print(('PASS' if ok else 'FAIL') + f'  plat_put_minirow ({"art" if art else "flat colours"}): {len(sel)} rows, each plane\'s three lines written to the right lines of that plane (a row drawn again is '
          f'overwritten), the stack is balanced and the RAM under the screen is paged back in'
          + (f' ({len(bad)} bytes differ, first plane {bad[0][0]} at offset {bad[0][1]}, line {bad[0][1] // 80}, byte {bad[0][1] % 80}; sp ${sp:04X}; plane {m.plane})' if not ok else ''))
    return ok


if __name__ == '__main__':
    sys.exit(main())
