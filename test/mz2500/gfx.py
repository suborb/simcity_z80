#!/usr/bin/env python3
"""z88dk's MZ-2500 graphics (libsrc/target/mz2500/graphics: plot, unplot, xorplot, point, fill, clg, mz2500_gfx_ink, mz2500_gfx_init) and generic_console
(stdio: printc with the font and UDGs, inverse and colours, cls, scrollup, vpeek) under z88dk-ticks.

The library's port instructions pass through thin assembly adapters into the Lua-owned memory model. Lua handles window paging, the CG registers ($BC/$BD), and the read-modify-write
page $30 (a byte written to it is applied to the four planes as PSET does, as in Takeda and MAME: plane = plane & ~byte | byte & register p, if registers 4 and 5 enable plane p;
a read of an address loads the latches that ports $BC-$BF return). The results are compared with a Python model of the
four planes: 40 bytes a line, 8 pixels a byte with bit 0 the leftmost, a pixel value B | R << 1 | G << 2 | I << 3.

  usage: test/mz2500/gfx.py [scenario]      MZ_WINDOW=2 or 3 selects the borrowed video window (default 2)
"""
import os
import random
import re
import subprocess
import sys
import tempfile

LIB = os.path.expanduser('~/z88dk/libsrc/target/mz2500')
WINDOW = int(os.environ.get('MZ_WINDOW', '2'))
CLASSIC = os.path.expanduser('~/z88dk/libsrc')
Z88DK = os.environ.get('Z88DK', os.path.expanduser('~/z88dk'))
os.environ.setdefault('ZCCCFG', os.path.join(Z88DK, 'lib', 'config'))
LUA_MODEL = 'mz2500.lua'
DI_FILES = ['l/sccz80/9-common/l_push_di.asm', 'l/sccz80/9-common/l_pop_ei.asm', 'arch/z80/z80/asm_z80_push_di.asm', 'arch/z80/z80/asm_z80_pop_ei.asm']      # the library's own
FILES = ['graphics/' + f for f in ('w_fill.asm', 'w_plotpixl.asm', 'w_respixl.asm', 'w_xorpixl.asm', 'w_pointxy.asm', 'getmaxx.asm', 'getmaxy.asm', 'clg.asm', 'mz2500_gfx.asm', 'mz2500_gwin.asm', 'w_pixel.inc')] + \
    ['stdio/' + f for f in ('conio_vars.asm', 'text_console.asm', 'generic_console_cls.asm', 'generic_console_glyph.asm', 'generic_console_printc.asm', 'generic_console_scrollup.asm', 'generic_console_vpeek.asm', 'generic_console_xypos.asm')] + \
    ['../../classic/stdio/conio/vpeek_screendollar.asm', '../../classic/stdio/conio/screendollar.asm']

HARNESS = '''        SECTION code_user
        org     $0100
        EXTERN  w_plotpixel, w_respixel, w_xorpixel, w_pointxy, clg, mz2500_gfx_init, fill
        EXTERN  __mz2500_gfxcon_printc, __mz2500_gfxcon_cls, __mz2500_gfxcon_scrollup, __mz2500_gfxcon_vpeek, __mz2500_textcon_printc, __mz2500_textcon_cls, __mz2500_textcon_scrollup, __mz2500_textcon_vpeek, __mz2500_text_ink, __mz2500_textcon_load_pcg, __mz2500_textcon_rom, __mz2500_con_ink, __mz2500_con_paper
        PUBLIC  __console_font_h, __console_w, generic_console_flags, generic_console_font32, generic_console_udg32, __MZ2500_GFX_WINDOW, __MZ2500_GFX_BASE, __MZ2500_GFX_PAGE, __MZ2500_TEXT_COLUMNS
        defc    __MZ2500_TEXT_COLUMNS = 40
        defc    __MZ2500_GFX_WINDOW = %WIN%
        defc    __MZ2500_GFX_BASE = %BASE%
        defc    __MZ2500_GFX_PAGE = $20
        EXTERN  __mz2500_gfx_ink, __mz2500_gfx_paper, l_cmp
        PUBLIC  p_o4, p_o5, p_i5, p_nop, p_palw, p_f4, p_f5, p_inc9, p_obc, p_obd, p_lat0, p_lat1, p_lat2, p_lat3, fin, __gfx_coords, mz2500_set_mode, conio_map_colour
start:  ld      sp,$3ff0
        ld      a,8
        ld      hl,%BASE%                ; page 8 (the original window 2) holds a pattern
        ld      de,%BASE1%
        ld      bc,$1fff
        ld      (hl),$a5
        ldir
        ld      ix,ops
        ld      iy,results
next:   ld      a,(ix+0)
        cp      255
        jp      z,finish
        ld      l,(ix+1)
        ld      h,(ix+2)
        ld      e,(ix+3)
        ld      d,(ix+4)
        cp      8
        jp      nc,conop
        cp      7
        jr      z,dofill
        cp      4
        jr      c,pixop
        jr      z,doclg
        cp      5
        jr      z,doink
        call    mz2500_gfx_init
        jp      step
doink:  ld      a,l
        xor     15
        ld      (__mz2500_gfx_ink),a
        ld      a,e
        ld      (__mz2500_gfx_paper),a
        jp      step
doclg:  call    clg
        jp      step
dofill: push    hl
        push    de
        call    fill
        pop     de
        pop     hl
        jp      step
pixop:  or      a
        jr      nz,not0
        call    w_plotpixel
        jp      step
not0:   cp      1
        jr      nz,not1
        call    w_respixel
        jp      step
not1:   cp      2
        jr      nz,not2
        call    w_xorpixel
        jp      step
not2:   call    w_pointxy
        push    af
        pop     bc
        ld      (iy+0),a
        ld      a,c
        and     $40
        ld      (iy+1),a
        inc     iy
        inc     iy
        jp      step
conop:  sub     8
        jp      z,doprint
        dec     a
        jp      z,docls
        dec     a
        jp      z,doscroll
        dec     a
        jp      z,dovpeek
        dec     a
        jp      z,docolour
        dec     a
        jp      z,doflags
        dec     a
        jp      z,dotprint
        dec     a
        jp      z,dotcls
        dec     a
        jp      z,dotscroll
        dec     a
        jp      z,dotvpeek
        dec     a
        jp      z,dotink
        dec     a
        jp      z,dopcg
        call    __mz2500_textcon_rom    ; 20
        jp      step
dotink: ld      a,l                     ; 18: the text colour
        ld      (__mz2500_text_ink),a
        jp      step
dopcg:  call    __mz2500_textcon_load_pcg
        jp      step
doflags: ld     a,l
        ld      (generic_console_flags),a
        jp      step
dotprint: ld    c,l
        ld      b,h
        ld      d,e
        call    __mz2500_textcon_printc
        jp      step
dotcls: call    __mz2500_textcon_cls
        jp      step
dotscroll: call __mz2500_textcon_scrollup
        jp      step
dotvpeek: ld    c,l
        ld      b,h
        call    __mz2500_textcon_vpeek
        push    af
        pop     bc
        ld      (iy+0),a
        ld      a,c
        and     1
        ld      (iy+1),a
        inc     iy
        inc     iy
        jp      step
doprint: ld     c,l
        ld      b,h
        ld      d,e
        ld      e,0
        call    __mz2500_gfxcon_printc
        jp      step
docls:  call    __mz2500_gfxcon_cls
        jp      step
doscroll: call  __mz2500_gfxcon_scrollup
        jp      step
dovpeek: ld     c,l
        ld      b,h
        ld      e,0
        call    __mz2500_gfxcon_vpeek
        push    af
        pop     bc
        ld      (iy+0),a
        ld      a,c
        and     1
        ld      (iy+1),a
        inc     iy
        inc     iy
        jp      step
docolour: ld    a,l
        ld      (__mz2500_con_ink),a
        ld      a,e
        ld      (__mz2500_con_paper),a
        jp      step
step:   ld      bc,5
        add     ix,bc
        jp      next
finish: ld      a,2
        out     ($ee),a                 ; export Lua-owned planes and logical RAM
fin:    halt
; Thin instruction adapters let transformed library I/O reach the real Lua model.
p_o4:   out     ($b4),a
        ret
p_o5:   out     ($b5),a
        ret
p_i5:   in      a,($b5)
        ret
p_obc:  out     ($bc),a
        ret
p_obd:  out     ($bd),a
        ret
p_lat0: in      a,($bc)
        ret
p_lat1: in      a,($bd)
        ret
p_lat2: in      a,($be)
        ret
p_lat3: in      a,($bf)
        ret
p_nop:  ret
p_inc9: xor     a
        ret
p_palw: ret
p_f4:   ret
p_f5:   ret
mz2500_set_mode:
        ld      hl,0
        ret
conio_map_colour: ret
__gfx_coords: defs 4
ops:    %OPS%
        defb    255
results: defs   800
generic_console_flags: defb 0
__console_w: defw 40
__console_font_h: defb 8
generic_console_font32: defw font
generic_console_udg32: defw udg
font:   defs    768
udg:    defs    1024
'''


def transform(text):
    text = re.sub(r'out\s+\(\$b4\),\s*a', 'call p_o4', text)
    text = re.sub(r'out\s+\(\$b5\),\s*a', 'call p_o5', text)
    text = re.sub(r'in\s+a,\s*\(\$b5\)', 'call p_i5', text)
    for n, port in enumerate(('bc', 'bd', 'be', 'bf')):
        text = re.sub(r'in\s+a,\s*\(\$%s\)' % port, 'call p_lat%d' % n, text)
    text = re.sub(r'in\s+a,\s*\(\$\w+\)', 'call p_inc9', text)
    text = re.sub(r'out\s+\(\$bc\),\s*a', 'call p_obc', text)
    text = re.sub(r'out\s+\(\$bd\),\s*a', 'call p_obd', text)
    text = re.sub(r'out\s+\(\$f4\),\s*a', 'call p_f4', text)
    text = re.sub(r'out\s+\(\$f5\),\s*a', 'call p_f5', text)
    text = re.sub(r'out\s+\(\$\w+\),\s*a', 'call p_nop', text)
    text = re.sub(r'out\s+\(c\),\s*e', 'call p_palw', text)
    text = re.sub(r'SECTION \w+', 'SECTION code_user', text)
    return '        EXTERN  p_o4, p_o5, p_i5, p_nop, p_palw, p_f4, p_f5, p_inc9, p_obc, p_obd, p_lat0, p_lat1, p_lat2, p_lat3\n' + text


def pixel(planes, x, y):
    i, m = y * 40 + x // 8, 1 << (x % 8)
    return sum(1 << p for p in range(4) if planes[p][i] & m)


def flood(planes, ink, x, y):
    """fill(x, y): the 4-connected area of colour 0 pixels round (x, y) becomes the ink colour (nothing if (x, y) is off the screen or not colour 0, or the ink is 0)"""
    if not (0 <= x < 320 and 0 <= y < 200) or ink == 0 or pixel(planes, x, y) != 0:
        return
    todo = [(x, y)]
    seen = {(x, y)}
    while todo:
        cx, cy = todo.pop()
        i, m = cy * 40 + cx // 8, 1 << (cx % 8)
        for p in range(4):
            if ink >> p & 1:
                planes[p][i] |= m
        for nx, ny in ((cx + 1, cy), (cx - 1, cy), (cx, cy + 1), (cx, cy - 1)):
            if 0 <= nx < 320 and 0 <= ny < 200 and (nx, ny) not in seen and pixel(planes, nx, ny) == 0:
                seen.add((nx, ny))
                todo.append((nx, ny))


def model_ops(planes, ink, paper, op):
    kind, x, y = op
    if kind in (0, 1, 2, 3):
        if not (0 <= x < 320 and 0 <= y < 200):
            return 'off' if kind == 3 else None
        i, m = y * 40 + x // 8, 1 << (x % 8)
        if kind == 3:
            return sum(1 << p for p in range(4) if planes[p][i] & m)
        for p in range(4):
            c = (ink if kind in (0, 2) else paper) >> p & 1
            if kind == 2:
                if c:
                    planes[p][i] ^= m
            elif c:
                planes[p][i] |= m
            else:
                planes[p][i] &= ~m & 255
        return None
    if kind == 7:
        flood(planes, ink, x, y)
        return None
    if kind == 4:
        for p in range(4):
            for i in range(8000):
                planes[p][i] = 255 if paper >> p & 1 else 0
    return None


_frnd = random.Random(99)
FONT = [bytes(8)] + [bytes(_frnd.randrange(1, 256) for _ in range(8)) for _ in range(95)]      # characters 32-127 (space is blank)
UDG = [bytes(_frnd.randrange(1, 256) for _ in range(8)) for _ in range(128)]                   # characters 128-255


def text_model(t, con, kind, a, b):
    """The text VRAM (planes[3] stands for it, and for the PCG page): 14 printc, 15 cls, 16 scrollup, 17 vpeek (returns the character), 18 text colour,
    19 load the PCG font, 20 back to the ROM's glyphs.  With the ROM's glyphs a character c is the code $8C00 + 4 * c: low byte at +0, attribute at +$800,
    high byte at +$1000, and a blank cell is $80 / $07 / $8C; with the PCG font the code is c (high byte 0) and a blank cell is 0 / $07 / 0"""
    pcg = con['pcg']
    blank = ((0, 0 if pcg else 0x80), (0x800, 0x07), (0x1000, 0 if pcg else 0x8c))
    if kind == 14:
        off = (a >> 8) * 40 + (a & 255)
        code = b if pcg else 0x8c00 + 4 * b
        t[off], t[0x800 + off], t[0x1000 + off] = code & 255, con['tink'] | (0x40 if con['flags'] & 0x80 else 0), code >> 8
    elif kind == 15:
        for base, v in blank:
            t[base:base + 0x800] = bytes([v]) * 0x800
    elif kind == 16:
        for base, v in blank:
            t[base:base + 960] = t[base + 40:base + 1000]
            t[base + 960:base + 1000] = bytes([v]) * 40
    elif kind == 17:
        off = (a >> 8) * 40 + (a & 255)
        code = t[0x1000 + off] << 8 | t[off]
        if pcg:
            return code if code < 256 else 'none'
        return (code - 0x8c00) >> 2 if 0x8c00 <= code < 0x9000 and code & 3 == 0 else 'none'
    elif kind == 18:
        con['tink'] = a
    elif kind == 19:
        t[0:0x800] = bytes(0x800)
        t[256:1024] = b''.join(FONT)
        t[1024:2048] = b''.join(UDG)
        con['pcg'] = 1
    elif kind == 20:
        con['pcg'] = 0
    return None


def console_model(planes, con, kind, a, b):
    """generic_console on the planes.  Kinds: 8 printc (a = x | y << 8, b = character), 9 cls, 10 scrollup, 11 vpeek (returns the character expected, or None for
    a cell that is not comparable), 12 colours (ink a, paper b), 13 flags (a)"""
    ink, paper = con['ink'], con['paper']
    if con['flags'] & 0x80:
        ink, paper = paper, ink
    if kind == 8:
        x, y, ch = a & 255, a >> 8, b
        glyph = FONT[ch - 32] if ch < 128 else UDG[ch - 128]
        for r in range(8):
            for px in range(8):
                c = ink if glyph[r] >> (7 - px) & 1 else paper
                X, Y = x * 8 + px, y * 8 + r
                i, m = Y * 40 + X // 8, 1 << (X % 8)
                for p in range(4):
                    if c >> p & 1:
                        planes[p][i] |= m
                    else:
                        planes[p][i] &= ~m & 255
        con['cells'][(x, y)] = (ch, con['ink'], con['paper'], con['flags'])
    elif kind == 9:
        for p in range(4):
            planes[p][:8000] = bytes([255 if con['paper'] >> p & 1 else 0]) * 8000
        con['cells'] = {(x, y): (32, con['ink'], con['paper'], 0) for x in range(40) for y in range(25)}
    elif kind == 10:
        for p in range(4):
            planes[p][0:7680] = planes[p][320:8000]
            planes[p][7680:8000] = bytes([255 if con['paper'] >> p & 1 else 0]) * 320
        con['cells'] = {(x, y - 1): v for (x, y), v in con['cells'].items() if y > 0}
        for x in range(40):
            con['cells'][(x, 24)] = (32, con['ink'], con['paper'], 0)
    elif kind == 11:
        cell = con['cells'].get((a & 255, a >> 8))
        if cell and cell[1:] == (con['ink'], con['paper'], con['flags']) and con['ink'] != con['paper']:
            return cell[0]
        return None
    elif kind in (14, 15, 16, 17, 18, 19, 20):
        return text_model(planes[3], con, kind, a, b)
    elif kind == 12:
        con['ink'], con['paper'] = a, b
    elif kind == 13:
        con['flags'] = a
    return None


def console_scenario(rnd, clean, count=330):
    """Characters at random cells in random colours (and inverse), with scrolls, a cls and vpeeks of the cells that were printed"""
    ops = [(9, 0, 0)] if clean else []
    ink, paper, flags = 15, 0, 0
    if clean:
        ops.append((12, ink, paper))
    printed = []
    scrolls = 0
    for n in range(count):
        r = rnd.random()
        if r < 0.08:
            ink, paper = rnd.sample(range(16), 2)
            ops.append((12, ink, paper))
        elif r < 0.12:
            flags = rnd.choice([0, 0x80, 0x81, 0x7f])
            ops.append((13, flags, 0))
        elif r < 0.14 and clean and scrolls < 4:
            scrolls += 1
            ops.append((10, 0, 0))
            printed = [(x, y - 1) for (x, y) in printed if y > 0]
        elif r < 0.15 and clean:
            ops.append((9, 0, 0))
            printed = []
        elif r < 0.30 and printed:
            x, y = rnd.choice(printed)
            ops.append((11, x | y << 8, 0))
        else:
            x, y = rnd.choice([0, 39, rnd.randrange(40)]), rnd.choice([0, 24, rnd.randrange(25)])
            ops.append((8, x | y << 8, rnd.choice([32, 127, 128, 255, rnd.randrange(32, 256)])))
            printed.append((x, y))
    for (x, y) in printed[-20:]:
        ops.append((11, x | y << 8, 0))
    return ops, [bytearray(rnd.randrange(256) for _ in range(8000)) + bytearray(192) for _ in range(4)]


def text_scenario(rnd, count=300):
    """The text console: characters, colours, inverse, scrolls and a cls over a random text VRAM (kept in the place of plane 3: no pixel operations)"""
    ops = []
    flags = 0
    for n in range(count):
        r = rnd.random()
        if r < 0.1:
            ops.append((18, rnd.randrange(8), 0))
        elif r < 0.15:
            flags = rnd.choice([0, 0x80, 0x81])
            ops.append((13, flags, 0))
        elif r < 0.19:
            ops.append((16, 0, 0))
        elif r < 0.20:
            ops.append((15, 0, 0))
        elif r < 0.22:
            ops.append((rnd.choice([19, 19, 20]), 0, 0))
        elif r < 0.35:
            ops.append((17, rnd.randrange(40) | rnd.randrange(25) << 8, 0))
        else:
            x, y = rnd.choice([0, 39, rnd.randrange(40)]), rnd.choice([0, 24, rnd.randrange(25)])
            ops.append((14, x | y << 8, rnd.randrange(256)))
    init = [bytearray(8192) for _ in range(3)] + [bytearray(rnd.randrange(256) for _ in range(8192))]
    return ops, init


def run_scenario(name, ops, init):
    """Runs the operations on the planes init (4 bytearrays of 8192) under ticks and compares with the model; returns True if they agree."""
    wb = WINDOW * 0x2000
    src = HARNESS
    for k, v in (('%BASE1%', '$%04x' % (wb + 1)), ('%BASE%', '$%04x' % wb), ('%WIN%', str(WINDOW))):
        src = src.replace(k, v)
    wbase = wb
    src = src.replace('%OPS%', '\n        '.join('defb %d\n        defw %d, %d' % (k, a & 0xFFFF, b & 0xFFFF) for k, a, b in ops))
    with tempfile.TemporaryDirectory() as tmp:
        open(os.path.join(tmp, 'h.asm'), 'w').write(src)
        names = []
        for path in FILES:
            f = os.path.basename(path)
            t = transform(open(os.path.join(LIB, path)).read())
            open(os.path.join(tmp, f), 'w').write(t)
            if f.endswith('.asm'):
                names.append(f)
        for f in DI_FILES:
            n = os.path.basename(f)
            open(os.path.join(tmp, n), 'w').write(re.sub(r'SECTION \w+', 'SECTION code_user', open(os.path.join(CLASSIC, f)).read()))
            names.append(n)
        out = subprocess.run(['z88dk-z80asm', '-mz80', '-I' + os.path.join(CLASSIC, 'classic'), '-b', '-m', 'h.asm'] + names, cwd=tmp, capture_output=True, text=True)
        if out.returncode or out.stderr.strip():
            print(out.stdout + out.stderr)
            print('FAIL  does not assemble')
            return False
        syms = {}
        for line in open(os.path.join(tmp, 'h.map')):
            m = re.match(r'(\S+)\s+= \$([0-9A-F]+) ;', line)
            if m:
                syms[m.group(1)] = int(m.group(2), 16)
        code = open(os.path.join(tmp, 'h_code_user.bin'), 'rb').read()
        if os.environ.get('MZ_SIZE'): print('image ends at', hex(0x100 + len(code)))
        img = bytearray(65536)
        for p in range(4):
            img[0x8000 + 0x2000 * p:0xA000 + 0x2000 * p] = init[p]
        img[0x100:0x100 + len(code)] = code
        for sym, glyphs in (('font', FONT), ('udg', UDG)):
            img[syms[sym]:syms[sym] + 8 * len(glyphs)] = b''.join(glyphs)
        open(os.path.join(tmp, 'img.bin'), 'wb').write(img)
        env = os.environ.copy()
        env['MZ_WINDOW'] = str(WINDOW)
        env['MZ_W2'] = '8' if WINDOW == 2 else '2'
        env['MZ_W3'] = '8' if WINDOW == 3 else '3'
        run = subprocess.run(['z88dk-ticks', '-b', 'lua', '-lua', LUA_MODEL, '-pc', '100', '-end', f'{syms["fin"]:x}',
                             '-counter', '3000000000', '-output', 'mem.out', 'img.bin'],
                            cwd=tmp, env=env, capture_output=True, text=True)
        if run.returncode:
            print('FAIL  z88dk-ticks:', run.stdout, run.stderr)
            return False
        mem = open(os.path.join(tmp, 'mz-memory.bin'), 'rb').read()
        lua_planes = [bytearray(open(os.path.join(tmp, f'mz-plane{p}.bin'), 'rb').read()) for p in range(4)]
        state = dict(line.strip().split('=') for line in open(os.path.join(tmp, 'mz-state.txt')))
    planes = [bytearray(p) for p in init]
    ink, paper = 15, 0
    con = {'ink': 15, 'paper': 0, 'flags': 0, 'cells': {}, 'tink': 7, 'pcg': 0}
    want = []
    for kind, a, b in ops:
        if kind == 5:
            ink, paper = a, b
        elif kind == 6:
            pass
        elif kind >= 8:
            r = console_model(planes, con, kind, a, b)
            if kind in (11, 17):
                want.append(r)
        else:
            r = model_ops(planes, ink, paper, (kind, a, b))
            if kind == 3:
                want.append(r)
    ok = True
    base = syms['results']
    pi = 0
    for kind, a, b in ops:
        if kind not in (3, 11, 17):
            continue
        w = want[pi]
        got = mem[base + 2 * pi]
        z = mem[base + 2 * pi + 1]
        if kind == 17:
            if w == 'none':
                if not z:
                    ok = False
                    print(f'FAIL  text vpeek({a & 255},{a >> 8}): expected failure, got {got}')
            elif got != w or z:
                ok = False
                print(f'FAIL  text vpeek({a & 255},{a >> 8}): got {got} (carry {z}), expected {w}')
        elif kind == 11:
            if w is not None and (got != w or z):
                ok = False
                print(f'FAIL  vpeek({a & 255},{a >> 8}): got character {got} (carry {z}), expected {w}')
        elif w == 'off':
            pass                                    # (nothing is promised for a point off the screen)
        elif got != w or (z != 0) != (w == 0):
            ok = False
            print(f'FAIL  point({a},{b}): got colour {got} (zero flag {bool(z)}), expected {w}')
        pi += 1
    for p in range(4):
        got = lua_planes[p][:8000]
        if bytes(got) != bytes(planes[p][:8000]):
            ok = False
            bad = [i for i in range(8000) if got[i] != planes[p][i]][:4]
            print(f'FAIL  {name}: plane {p}: first differing bytes {bad}')
    if int(state[f'window{WINDOW}']) != 8 or mem[wbase:wbase + 8192] != bytes([0xA5]) * 8192:
        # the window must be put back to what it was, with its contents
        ok = False
        print(f'FAIL  {name}: the window is not back at its page (or its page was changed)')
    if state['badmode'] != '0':
        ok = False
        print(f'FAIL  {name}: RMW write outside PSET (regs {state["r4"]}/{state["r5"]}, first {state["first_badmode"]} at {state["first_badaddr"]} value {state["first_badvalue"]}; windows {[state[f"window{i}"] for i in range(8)]})')
    print(('PASS' if ok else 'FAIL') + f'  {name}: {len(ops)} operations match the model; the window restored')
    return ok


def pixels_scenario(rnd):
    ink, paper = 15, 0
    ops = []
    edge = [(0, 0), (319, 0), (0, 199), (319, 199), (160, 100), (7, 7), (8, 8), (-1, 5), (5, -1), (320, 5), (5, 200), (-32768, 5), (5, 32767), (0xFFFF - 65536, 0xFFFF - 65536)]
    for (x, y) in edge:
        for kind in (0, 1, 2, 3):
            ops.append((kind, x, y))
    for n in range(500):
        r = rnd.random()
        if r < 0.05:
            ink, paper = rnd.randrange(16), rnd.randrange(16)
            ops.append((5, ink, paper))
        elif r < 0.06:
            ops.append((4, 0, 0))
        else:
            ops.append((rnd.randrange(4), rnd.randrange(-3, 324), rnd.randrange(-3, 204)))
    ops.append((6, 0, 0))                          # mz2500_gfx_init: runs without hanging
    return ops, [bytearray(rnd.randrange(256) for _ in range(8000)) + bytearray(192) for _ in range(4)]


def fill_scenario(rnd, walls, fills, hlines=True):
    """A clear screen, some walls (plots) and fills at random places, and the edge and error cases"""
    ops = [(4, 0, 0)]                              # (the harness keeps its operations below $3000: about 1800 of them)
    for n in range(walls):
        x, y = rnd.randrange(320), rnd.randrange(200)
        ops.append((5, rnd.randrange(1, 16), 0))
        horizontal = rnd.random() < 0.5
        for k in range(rnd.randrange(10, 100)):
            ops.append((0, x + k if horizontal else x, y if horizontal else y + k))
    for n in range(fills):
        ops.append((5, rnd.choice([0, 1, 2, 4, 7, 8, 15, rnd.randrange(16)]), 0))
        ops.append((7, rnd.randrange(-2, 322), rnd.randrange(-2, 202)))
    for (x, y) in ((0, 0), (319, 199), (0, 199), (319, 0), (160, 100)):
        ops.append((5, rnd.randrange(1, 16), 0))
        ops.append((7, x, y))
    ops.append((6, 0, 0))
    return ops, [bytearray(8192) for _ in range(4)]


def main():
    rnd = random.Random(7)
    if len(sys.argv) > 1:                          # one scenario: a filter on the name
        names = {'pixels': lambda: pixels_scenario(rnd), 'open': lambda: fill_scenario(rnd, 0, 3), 'few': lambda: fill_scenario(rnd, 12, 10), 'many': lambda: fill_scenario(rnd, 22, 8),
                 'text': lambda: text_scenario(random.Random(5)), 'console': lambda: console_scenario(random.Random(3), False), 'console2': lambda: console_scenario(random.Random(4), True),
                 'one': lambda: ([(4, 0, 0), (5, 7, 0), (7, 100, 100), (6, 0, 0)], [bytearray(8192) for _ in range(4)])}
        return 0 if run_scenario(sys.argv[1], *names[sys.argv[1]]()) else 1
    ok = run_scenario('console, over a random screen', *console_scenario(random.Random(3), False))
    ok &= run_scenario('console, from a cleared screen (scroll, cls)', *console_scenario(random.Random(4), True))
    ok &= run_scenario('text console', *text_scenario(random.Random(5)))
    ok &= run_scenario('pixels', *pixels_scenario(rnd))
    ok &= run_scenario('fill, an open screen', *fill_scenario(rnd, 0, 3))
    ok &= run_scenario('fill, a few walls', *fill_scenario(rnd, 12, 10))
    ok &= run_scenario('fill, many walls', *fill_scenario(rnd, 22, 8))
    for seed in range(1, 9):
        ok &= run_scenario('fill, random scene %d' % seed, *fill_scenario(random.Random(seed), 14 + seed, 9))
    return 0 if ok else 1


if __name__ == '__main__':
    sys.exit(main())
