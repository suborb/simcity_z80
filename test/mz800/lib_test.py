#!/usr/bin/env python3
"""z88dk's MZ-800 library (libsrc/target/mz800: console, graphics, keyboard) run on the ticks model: lib_test.c is built with zcc +mz800, loaded at $2000 (the crt's origin) with no IPL, takes
keys through the model's matrix and is checked by its screen (the model's pixels) and its results in memory."""
import os, re, subprocess, sys, tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
ROM = os.environ.get('MZ800_ROM', os.path.expanduser('~/emu/sord/binary/binary/mz800/Sharp MZ-800 BIOS (19xx)(Sharp).bin'))
CFG = os.environ.get('ZCCCFG', os.path.expanduser('~/z88dk/lib/config'))
MODEL = os.path.join(CFG, '..', 'ticks', 'memory', 'mz800.lua')
M = 1000000


def main(ipl=False):
    bad = 0

    def check(n, c, x=''):
        nonlocal bad
        print(('ok   ' if c else 'FAIL ') + ('[IPL] ' if ipl else '') + n + ('' if c else '  ' + str(x)))
        bad += not c

    d = tempfile.mkdtemp()
    env = dict(os.environ, ZCCCFG=CFG)
    subprocess.check_call(['zcc', '+mz800', '-compiler=sccz80', '-lndos', '-m', '-create-app', '-o', d + '/lt.bin', HERE + '/lib_test.c'], env=env, cwd=d)
    sym = {m.group(1): int(m.group(2), 16) for m in re.finditer(r'^(\w+)\s+= \$([0-9A-F]+)', open(d + '/lt.map').read(), re.M)}
    off = 8 * M if ipl else 0       # (the IPL's boot takes about 6 million cycles first)
    keys = ','.join('%d:%s:1,%d:%s:0' % (t + off, k, t + off + 3 * M, k) for t, k in ((20 * M, 'a'), (28 * M, 'b'), (32 * M, 'escape'), (36 * M, 'shift'), (37 * M, 'c'), (41 * M, 'escape'), (45 * M, 'q'), (50 * M, 'a'), (54 * M, 'b'), (58 * M, 'escape'), (62 * M, 'c'), (66 * M, 'return'), (106 * M, 'left'), (109 * M, 'a')))
    keys = keys.replace('%d:shift:0' % (39 * M + off), '%d:shift:0' % (42 * M + off))
    keys += ',%d:joy1_up:1,%d:joy1_up:0,%d:joy1_fire:1,%d:joy1_fire:0,%d:joy2_left:1,%d:joy2_left:0,%d:joy2_right:1,%d:joy2_right:0' % tuple(x * M + off for x in (95, 97, 95, 97, 99, 101, 99, 101))
    if ipl:     # the real IPL boots the disc: the stack, the memory and the display are as it leaves them
        open(d + '/reset.bin', 'wb').write(b'\x00')
        cmd = ['z88dk-ticks', '-b', 'lua', '-lua', MODEL, '-pc', '0', '-counter', str(125 * M + off), '-output', d + '/mem.out', d + '/reset.bin']
        extra = dict(MZ800_ROM=ROM, MZ800_DISC=d + '/lt.d88')
    else:
        cmd = ['z88dk-ticks', '-b', 'lua', '-lua', MODEL, '-l', '0x2000', '-pc', '0x2000', '-counter', str(125 * M), '-output', d + '/mem.out', d + '/lt.bin']
        extra = {}
    run = subprocess.run(cmd, capture_output=True, text=True, cwd=d, env=dict(env, MZ800_KEYS=keys, MZ800_SNAP=str(44 * M + off), MZ800_PORTLOG='1', MZ800_OUTDIR=d, **extra))
    mem = open(d + '/mem.out', 'rb').read()
    pr = list(mem[sym['_point_results']:sym['_point_results'] + 8])
    check('point() is 1 for a pixel that is not pen 0 (the line, the vertical line, the second plot, the xor toggled to ink) and 0 for the others; getmaxx/y are 319 and 199; drawb and circle (the wide library) draw their corners and the top and right of the circle, and not its centre', pr == [1, 1, 0, 1, 0, 1, 1, 1], pr)
    vp = list(mem[sym['_vpeek_results']:sym['_vpeek_results'] + 5])
    check('cvpeek reads the characters back (M, Z, a), and after three lines of scrolling the "at 2,10" line is on row 7 and the last line is "line 2"', vp == [ord('M'), ord('Z'), ord('a'), ord('a'), ord('l')], vp)
    sc = mem[sym['_scancode_a']] | (mem[sym['_scancode_a'] + 1] << 8)
    check('in_LookupKey(\'a\') is strobe 4, mask $80 (the a key at the last bit)', sc == 0x8004, hex(sc))
    kl = list(mem[sym['_key_log']:sym['_key_log'] + mem[sym['_key_count']]])
    check('the keys read: a, b, BREAK = 12 (delete), shift+c = C, shift+BREAK = 27 (Esc), q', kl == [ord('a'), ord('b'), 12, ord('C'), 27, ord('q')], kl)
    ln = bytes(mem[sym['_line']:sym['_line'] + 6]).split(b'\0')[0]
    check('fgets_cons: a b BREAK c return gives "ac" (the delete code is the crt\'s CRT_KEY_DEL)', ln.rstrip(b'\n') == b'ac', ln)
    check('the last key read was q', mem[sym['_last_key']] == ord('q'), mem[sym['_last_key']])
    d_ = open(d + '/mz800-snap-1.ppm', 'rb').read()
    px = d_[len(b'P6\n320 200\n255\n'):]

    def pix(x, y):
        return tuple(px[(y * 320 + x) * 3:(y * 320 + x) * 3 + 3])
    BLACK, RED, GREEN, WHITE = (0, 0, 0), (255, 0, 0), (0, 255, 0), (255, 255, 255)
    check('the console prints white text on black in the first row (row 0 of cells has pixels, nothing below row 12 but the plots)', any(pix(x, y) == WHITE for x in range(0, 112) for y in range(0, 8)))
    row1 = {pix(x, y) for x in range(0, 16 * 8) for y in range(8, 16)}
    check('textcolor(1), (2) and (3): the pens of the second line are red, green and white', {RED, GREEN, WHITE} <= row1, row1)
    check('gotoxy(2, 10): text in cell row 10 from column 2 (nothing in columns 0 and 1)', any(pix(x, y) != BLACK for x in range(16, 70) for y in range(80, 88)) and not any(pix(x, y) != BLACK for x in range(0, 16) for y in range(80, 88)))
    check('the line: plot in pen 3 at (50, 112) and the vertical line of pen 1 at x = 200', pix(50, 112) == WHITE and pix(200, 120) == RED)
    check('plot/unplot: (5, 5) is back to black, (6, 5) green', pix(5, 5) == BLACK and pix(6, 5) == GREEN)
    check('plot follows textcolor (red, green, white pens) and unplot textbackground (green)', pix(100, 60) == RED and pix(102, 60) == GREEN and pix(104, 60) == GREEN, [pix(100, 60), pix(102, 60), pix(104, 60)])
    check('xorplot: (300, 190) black, (301, 190) white, (302, 190) white', pix(300, 190) == BLACK and pix(301, 190) == WHITE and pix(302, 190) == WHITE)
    keys_line = {pix(x, y) for x in range(0, 16 * 8) for y in range(8 * 14, 8 * 15)}
    check('the keys read are echoed on the "keys:" line (a, b, shift+c = C, q)', WHITE in keys_line)
    # styled text: row 3 plain, row 4 bold (more pixels), row 5 inverse (the complement of the plain cells), row 6 underlined (the last line of each cell solid)
    def count(row):
        return sum(1 for x in range(32) for y in range(row * 8, row * 8 + 8) if pix(x, y) != BLACK)
    plain, bold, inv, und = (count(r) for r in (3, 4, 5, 6))
    check('bold: more pixels than plain (%d vs %d)' % (bold, plain), bold > plain, (plain, bold))
    check('inverse: the complement of the plain cells (%d + %d = 256)' % (plain, inv), plain + inv == 256, (plain, inv))
    check('underline: the last line of each cell is solid, the rest is the plain glyph', all(pix(x, 6 * 8 + 7) != BLACK for x in range(32)) and und == plain + sum(1 for x in range(32) if pix(x, 3 * 8 + 7) == BLACK), (plain, und))
    jr = list(mem[sym['_joy_results']:sym['_joy_results'] + 4])
    check('joystick(1): up and fire from port $F0 (%s); joystick(2): left and right from $F1' % [hex(b) for b in jr], jr[0] == 0x28 and jr[1] == 0x03, jr)
    check('joystick(6) the cursor keys: left is down; joystick(3) QAOP: A is down (and nothing else)', jr[2] == 0x02 and jr[3] == 0x04, jr)
    f2 = [int(l.split('$f2,$')[1], 16) for l in open(d + '/ports.txt').read().splitlines() if '$f2' in l]
    check('the SN76489 stack: PSGPlayNoRepeat/PSGFrame write the song to $F2 (tone $85 $0A, volume $90, volume off $9F)', f2[-6:] == [0x85, 0x4A, 0x90, 0x9F, 0x9F, 0x9F] or (0x85 in f2 and 0x4A in f2 and 0x90 in f2 and 0x9F in f2[f2.index(0x90):]), f2[-12:])
    return bad


if __name__ == '__main__':
    bad = main()
    if os.path.exists(ROM):
        bad += main(ipl=True)
    else:
        print('(MZ800_ROM not found: the run through the IPL is skipped)')
    sys.exit(1 if bad else 0)
