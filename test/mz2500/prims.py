#!/usr/bin/env python3
"""Host test of target/mz2500/plat_mz2500.asm: each drawing routine runs under z88dk-ticks with the Lua-owned MZ paging model on random plane contents and is compared
with a Python model of the screen: 4 planes of 40 bytes a line, 8 pixels a byte with bit 0 the leftmost, the game's cells at byte column 4.  (The checks are on what is displayed:
bytes 4-35 of lines 0-191.)"""
import os, random, re, struct, subprocess, sys, tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, '..', '..'))
Z88DK = os.environ.get('Z88DK', os.path.expanduser('~/z88dk'))
TICKS = os.environ.get('TICKS', 'z88dk-ticks')
Z80ASM = os.environ.get('Z80ASM', 'z88dk-z80asm')
os.environ.setdefault('ZCCCFG', os.path.join(Z88DK, 'lib', 'config'))
LUA_MODEL = 'mz2500.lua'
WORK = tempfile.TemporaryDirectory(prefix='mz2500-prims-')
WORKDIR = WORK.name
XB0 = 4


def build():
    source = open(os.path.join(HERE, 'prims_h.asm')).read()
    source = source.replace('../../target/mz2500/plat_mz2500.asm', os.path.join(ROOT, 'target/mz2500/plat_mz2500.asm'))
    open(os.path.join(WORKDIR, 'prims_h.asm'), 'w').write(source)
    subprocess.check_call([Z80ASM, '-mz80', '-b', '-m', '-I' + os.path.join(ROOT, 'target/mz2500'), 'prims_h.asm'],
                          cwd=WORKDIR, stdout=subprocess.DEVNULL)
    syms = {}
    for line in open(os.path.join(WORKDIR, 'prims_h.map')):
        m = re.match(r'(\w+)\s+= \$([0-9A-Fa-f]+)', line)
        if m:
            syms[m.group(1)] = int(m.group(2), 16)
    return syms, open(os.path.join(WORKDIR, 'prims_h_code_user.bin'), 'rb').read()


SYMS, CODE = build()


def run(func, args, planes, state=(0, 0), atlas=None):
    """Runs a routine through the Lua-owned MZ windows; planes are updated from physical page snapshots."""
    mem = bytearray(65536)
    mem[0x100:0x100 + len(CODE)] = CODE
    block = struct.pack('<HB', SYMS[func], len(args)) + b''.join(struct.pack('<H', a & 0xFFFF) for a in args)
    mem[0x3000:0x3000 + len(block)] = block
    for p in range(4):
        mem[0x8000 + 0x2000 * p:0xA000 + 0x2000 * p] = planes[p]
    if atlas is not None:
        mem[0x4000:0x6000] = atlas
    img, out = os.path.join(WORKDIR, 'prims.img'), os.path.join(WORKDIR, 'prims.out')
    open(img, 'wb').write(mem)
    env = os.environ.copy()
    env.update({'MZ_W2': '18', 'MZ_W3': '19'})
    result = subprocess.run([TICKS, '-b', 'lua', '-lua', LUA_MODEL, '-pc', '100', '-end', '%04x' % SYMS['done'],
                             '-output', out, img], cwd=WORKDIR, env=env, capture_output=True, text=True)
    if result.returncode:
        raise RuntimeError(f'z88dk-ticks failed: {result.stdout}{result.stderr}')
    model_state = dict(line.strip().split('=') for line in open(os.path.join(WORKDIR, 'mz-state.txt')))
    if model_state['window2'] != '18' or model_state['window3'] != '19':
        raise AssertionError(f'{func} did not restore MZ windows 2 and 3: {model_state}')
    for p in range(4):
        suffix = f'mz-plane-b{p}.bin' if func == '_mz_arrow' else f'mz-plane{p}.bin'
        planes[p][:] = open(os.path.join(WORKDIR, suffix), 'rb').read()
    return state


def rev(b):
    return int(f'{b:08b}'[::-1], 2)


def A(y, xb, st=None):
    """The offset in a plane of the byte at line y, byte column xb."""
    return y * 40 + xb


def display(planes, st):
    """D[p][y][xb - 4]: what the CRTC shows (lines 0-191, bytes 4-35)."""
    return [[[planes[p][A(y, xb, st)] for xb in range(XB0, XB0 + 32)] for y in range(192)] for p in range(4)]


def rnd_planes(seed):
    r = random.Random(seed)
    return [bytearray(r.randrange(256) for _ in range(8192)) for _ in range(4)]


def first_diff(got, want, mask=None):
    for p in range(4):
        for y in range(192):
            for x in range(32):
                if mask and not mask(y, x):
                    continue
                if got[p][y][x] != want[p][y][x]:
                    return p, y, x
    return None


def check(name, planes, st, want, mask=None):
    got = display(planes, st)
    d = first_diff(got, want, mask)
    if d:
        p, y, x = d
        print(f'FAIL {name}: plane {p} line {y} byte {x}: got {got[p][y][x]:02x} want {want[p][y][x]:02x}')
        return False
    print(f'ok   {name}')
    return True


def copy(d):
    return [[row[:] for row in pl] for pl in d]


STATES = ((0, 0),)


def main():
    ok = True
    r = random.Random(1)

    for st in STATES:
        tag = f'state {st}'
        # tile, glyph, glyphr, overlay, xorcell, recolour in a panel row and map rows
        atlas = bytearray(r.randrange(256) for _ in range(8192))
        for n, col, row in ((37, 5, 3), (255, 31, 23), (100, 12, 9), (7, 0, 7), (200, 20, 16)):
            pl = rnd_planes(n + st[0])
            D = display(pl, st)
            for p in range(4):
                for k in range(8):
                    D[p][row * 8 + k][col] = atlas[(n & 255) * 32 + p * 8 + k]
            run('_mz_tile', [col, row, n], pl, st, atlas)
            ok &= check(f'tile {n} at {col},{row} {tag}', pl, st, D)

        for ink, pap, col, row in ((15, 0, 3, 4), (5, 10, 31, 23), (9, 2, 20, 6), (6, 1, 0, 7)):
            art = [r.randrange(256) for _ in range(8)]
            atl = bytearray(8192)
            atl[0x1000:0x1008] = bytes(art)
            for name, rv in (('glyph', True), ('glyphr', False)):
                pl = rnd_planes(ink * 16 + pap)
                D = display(pl, st)
                for p in range(4):
                    for k in range(8):
                        g = rev(art[k]) if rv else art[k]
                        i = 0xFF if (ink >> p) & 1 else 0
                        q = 0xFF if (pap >> p) & 1 else 0
                        D[p][row * 8 + k][col] = (g & i) | (~g & q & 0xFF)
                run('_mz_' + name, [col, row, 0x5000, ink, pap], pl, st, atl)
                ok &= check(f'{name} ink {ink} paper {pap} at {col},{row} {tag}', pl, st, D)

        for col, row in ((0, 0), (17, 11)):
            art = [r.randrange(256) for _ in range(8)]
            atl = bytearray(8192)
            atl[0x1000:0x1008] = bytes(art)
            pl = rnd_planes(77 + col)
            D = display(pl, st)
            for p in range(4):
                for k in range(8):
                    D[p][row * 8 + k][col] |= rev(art[k])
            run('_mz_overlay', [col, row, 0x5000], pl, st, atl)
            ok &= check(f'overlay at {col},{row} {tag}', pl, st, D)

        pl = rnd_planes(5)
        D = display(pl, st)
        for p in range(4):
            for k in range(8):
                D[p][7 * 8 + k][9] ^= 0xFF
        run('_mz_xorcell', [9, 7], pl, st)
        ok &= check(f'xorcell {tag}', pl, st, D)

        for col, row, n, ink, pap in ((2, 3, 5, 6, 1), (0, 20, 32, 15, 8), (10, 8, 1, 2, 9)):
            pl = rnd_planes(n)
            text = [[r.randrange(256) for _ in range(n)] for _ in range(8)]
            D0 = display(pl, st)
            for p in range(4):
                for k in range(8):
                    for b in range(n):
                        D0[p][row * 8 + k][col + b] = text[k][b]
            # put the text on the screen through the model's addresses
            for p in range(4):
                for k in range(8):
                    for b in range(n):
                        pl[p][A(row * 8 + k, col + b + XB0, st)] = text[k][b]
            D = copy(D0)
            for p in range(4):
                i = 0xFF if (ink >> p) & 1 else 0
                q = 0xFF if (pap >> p) & 1 else 0
                for k in range(8):
                    for b in range(n):
                        g = text[k][b]
                        D[p][row * 8 + k][col + b] = (g & i) | (~g & q & 0xFF)
            run('_mz_recolour', [col, row, n, ink, pap], pl, st)
            ok &= check(f'recolour {n} cells ink {ink} paper {pap} at {col},{row} {tag}', pl, st, D)

        # the line routines: the ring is put in order first, and what is displayed is what the model says
        for y, xb, nb, ny, colour in ((0, 4, 32, 8, 5), (100, 10, 3, 17, 15), (190, 35, 1, 2, 9), (50, 4, 1, 40, 0), (56, 4, 32, 136, 7)):
            pl = rnd_planes(y)
            D = display(pl, st)
            for p in range(4):
                v = 0xFF if (colour >> p) & 1 else 0
                for ln in range(ny):
                    for b in range(nb):
                        if y + ln < 192:
                            D[p][y + ln][xb - XB0 + b] = v
            st2 = run('_mz_fillb', [y, xb, nb, ny, colour], pl, st)
            ok &= check(f'fillb y{y} x{xb} {nb}x{ny} colour {colour} {tag} -> {st2}', pl, st2, D)
        for y, xb, ny, mask, colour in ((8, 6, 6, 0xF0, 12), (60, 4, 1, 0x01, 3), (180, 20, 10, 0x7E, 6)):
            pl = rnd_planes(y + 1)
            D = display(pl, st)
            for p in range(4):
                v = 0xFF if (colour >> p) & 1 else 0
                for ln in range(ny):
                    if y + ln < 192:
                        i = xb - XB0
                        D[p][y + ln][i] = (D[p][y + ln][i] & ~mask & 0xFF) | (v & mask)
            st2 = run('_mz_maskb', [y, xb, ny, mask, colour], pl, st)
            ok &= check(f'maskb y{y} x{xb} mask {mask:02x} colour {colour} {tag} -> {st2}', pl, st2, D)
        for y, nl in ((0, 2), (100, 1), (184, 2)):
            pix = bytes(r.randrange(16) for _ in range(192))
            pl = rnd_planes(y)
            D = display(pl, st)
            for p in range(4):
                for ln in range(nl):
                    for g in range(24):
                        D[p][y + ln][g] = sum(((pix[g * 8 + j] >> p) & 1) << j for j in range(8))
            atl = bytearray(8192)
            atl[0x1000:0x10C0] = pix
            st2 = run('_mz_wrline', [y, 0x5000, nl], pl, st, atl)
            ok &= check(f'wrline y{y} x{nl} {tag} -> {st2}', pl, st2, D)

        # the arrow: bytes of display columns 4-35 only, 16 lines (to 199), across the panel and the ring's seam
        for y, xb, buf_on in ((10, 7, True), (50, 20, True), (180, 35, True), (186, 34, True), (20, 9, False)):
            pl = rnd_planes(y + xb)
            buf = bytes(r.randrange(256) for _ in range(96))
            D = display(pl, st)
            n, nb = min(16, 200 - y), min(3, 36 - xb)
            for p in range(4):
                for k in range(n):
                    for i in range(nb):
                        if y + k < 192:
                            D[p][y + k][xb - XB0 + i] = (buf[k * 6 + (3 if p == 3 else 0) + i] if buf_on else 0)
            atl = bytearray(8192)
            atl[0x1000:0x1060] = buf
            run('_mz_arrow', [y, xb, 0x5000 if buf_on else 0], pl, st, atl)
            ok &= check(f'arrow y{y} xb{xb} {"put" if buf_on else "clear"} {tag}', pl, st, D)

    # scroll in software (the fallback) and in hardware (mz_scroll): cells (x, y) -> (x - dx, y - dy), the entering ones undefined
    def moved(D0, row, rows, dx, dy):
        D = copy(D0)
        for p in range(4):
            for ln in range(rows * 8):
                for b in range(32):
                    sx, sy = b + dx, ln + dy * 8
                    if 0 <= sx < 32 and 0 <= sy < rows * 8:
                        D[p][row * 8 + ln][b] = D0[p][row * 8 + sy][sx]
        return D

    for st in STATES:
        for row, rows, dx, dy in ((7, 17, 0, 1), (7, 17, 1, 0), (7, 17, -1, -1), (7, 17, 2, -1), (7, 17, -3, 2)):
            pl = rnd_planes(row + dx * 7 + dy + st[0])
            D0 = display(pl, st)
            want = moved(D0, row, rows, dx, dy)
            st2 = run('_mz_shift', [row, rows, dx & 0xFF, dy & 0xFF], pl, st)
            ok &= check(f'shift (software) dx {dx} dy {dy} state {st} -> {st2}', pl, st2, want)

    print('ALL OK' if ok else 'FAILED')
    return 0 if ok else 1


if __name__ == '__main__':
    sys.exit(main())
