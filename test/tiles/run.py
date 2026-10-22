#!/usr/bin/env python3
"""ZX Spectrum drawing: the Spectrum target platform (target/zx) and engine art, built for +zx with the
game's flags and run under z88dk-ticks.  Checks the Spectrum's screen memory against the art in assets/udgs.bin
for every picture (map tiles and both ranges of large-zone pieces), the inverted cursor, the colours, the
sprites, and the text: it is drawn from the ROM's font, which under ticks (there is no ROM) the harness fills
with a font of its own, in black on white, clipped at the right edge, and plat_clear blanks the screen.

  usage: test/tiles/run.py
"""
import os
import re
import subprocess
import sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
OUT = os.path.join(ROOT, 'build', 'tiles')
ZORG = 24000
ART = open(os.path.join(ROOT, 'assets', 'udgs.bin'), 'rb').read()
TILE_BASE = 536
N_ART = 94 + 251


ROM_FONT = 0x3D00                    # the ROM's font, characters 32..127
TEXT_ATTR = 0x38
FONT = bytes((i * 37 + (i >> 3) * 11 + 5) & 255 for i in range(96 * 8))      # the harness's own font


def build():
    os.makedirs(OUT, exist_ok=True)
    env = os.environ
    cmd = os.environ.get('ZCC', 'zcc -compiler=80cc -fframe-pointer').split() + ['+zx', f'-zorg={ZORG}', '-pragma-include:target/zx/zpragma.inc', '-Ca-DPORTABLE',
           '-Ca-Iengine', '-Ca-I.', '-Iui', '-Cc-standard-escape-chars', '-m',
           '-Itarget/zx', '-DTARGET_ZX', '-Ca-DTARGET_ZX', '-DHAVE_SPRITES'] + [ '-DMAX_VIEW_W=32', '-DMAX_VIEW_H=16',
           'test/tiles/main.c', 'ui/sprites.c', 'engine/engine_c.asm', 'platform/common/hooks.asm', 'platform/common/nosound.asm',
           'target/zx/plat_zx.asm'] + [
           '-o', os.path.join(OUT, 'tiles')]
    r = subprocess.run(cmd, cwd=ROOT, env=env, capture_output=True, text=True)
    if r.returncode:
        print(r.stdout, r.stderr)
        sys.exit('build failed')
    syms = {}
    for line in open(os.path.join(OUT, 'tiles.map')):
        m = re.match(r'(\S+)\s*=\s*\$([0-9A-Fa-f]+)', line)
        if m:
            syms[m.group(1)] = int(m.group(2), 16)
    return syms


def run(syms):
    path = os.path.join(OUT, 'tiles')
    dump = os.path.join(OUT, 'tiles.out')
    if os.path.exists(dump):
        os.remove(dump)
    end = syms['__Exit']
    binary = open(path, 'rb').read()
    rom = bytearray(ZORG)
    rom[ROM_FONT:ROM_FONT + len(FONT)] = FONT
    image = bytes(rom) + binary
    img_path = os.path.join(OUT, 'tiles.img')
    open(img_path, 'wb').write(image)
    subprocess.run(['z88dk-ticks', '-pc', f'{ZORG:x}', '-end', f'{end:x}',
                    '-counter', '2000000000', '-output', dump, img_path], capture_output=True, text=True)
    return open(dump, 'rb').read()


def cell(mem, col, row):
    base = 0x4000 + ((row >> 3) << 11) + ((row & 7) << 5) + col
    return bytes(mem[base + 0x100 * k] for k in range(8)), mem[0x5800 + row * 32 + col]


failures = []


def check(name, ok, detail=''):
    print(('PASS  ' if ok else 'FAIL  ') + name + ((' ' + detail) if detail and not ok else ''))
    if not ok:
        failures.append(name)


def main():
    syms = build()
    mem = run(syms)
    bad = []
    for i in range(N_ART):
        art, attr = cell(mem, i % 32, i // 32)
        want = ART[TILE_BASE + 8 * i:TILE_BASE + 8 * i + 8]
        if art != want or attr != ((i & 0x7F) | 0x08):
            bad.append((i, art.hex(), want.hex(), attr))
    check(f'all {N_ART} pictures drawn correctly with their colours', not bad,
          f'{len(bad)} wrong, first: {bad[:3]}')
    tiles_bad = [b for b in bad if b[0] < 94]
    check('map tiles', not tiles_bad)
    zones_a = [b for b in bad if 94 <= b[0] < 94 + 128]
    zones_b = [b for b in bad if b[0] >= 94 + 128]
    check('zone pieces 0-127', not zones_a)
    check('zone pieces 128-250', not zones_b)

    inv = lambda i: bytes(~b & 255 for b in ART[TILE_BASE + 8 * i:TILE_BASE + 8 * i + 8])
    for col, i in ((0, 5), (1, 150)):
        art, attr = cell(mem, col, 12)
        check(f'cursor over picture {i} is inverted', art == inv(i) and attr == 0x47, f'{art.hex()} {attr:02x}')

    # Text: the ROM's font (here the harness's own), black on white, clipped at column 31.
    def glyph(ch):
        return FONT[(ord(ch) - 32) * 8:(ord(ch) - 32) * 8 + 8]
    bad = []
    for row, col0, text in ((14, 0, 'HELLO SIMCITY 123'), (18, 0, 'AFTER'), (22, 28, 'ABCD'), (23, 0, 'EFGH'), (23, 30, 'XY'), (19, 20, '~')):
        for k, ch in enumerate(text):
            art, attr = cell(mem, col0 + k, row)
            if art != glyph(ch) or attr != TEXT_ATTR:
                bad.append((row, col0 + k, ch, art.hex(), attr))
    check('text is drawn from the ROM font in the standard colours', not bad, str(bad[:3]))
    # A line that runs off the right edge carries on in the next row ("ABCDEFGH" from column 28 of row 22 gives EFGH
    # at the start of row 23, checked above); at the bottom of the screen it stops ("XYZ" from column 30 of row 23:
    # Z would be written over the attributes, so the attribute of the first cell must be as the test drew it).
    check('text wraps to the next row, and stops at the bottom of the screen',
          cell(mem, 0, 0)[1] == 0x08 and cell(mem, 1, 0)[1] == 0x09)
    check('plat_clear blanked the screen (a tile drawn before it is gone, the rest is untouched)',
          cell(mem, 31, 17) == (bytes(8), TEXT_ATTR) and cell(mem, 13, 13) == (bytes(8), TEXT_ATTR))
    art, attr = cell(mem, 0, 16)
    want = ART[TILE_BASE + 8 * 200:TILE_BASE + 8 * 200 + 8]
    check('picture after text still correct', art == want and attr == 0x46, f'{art.hex()} {attr:02x}')
    spr = open(os.path.join(ROOT, 'assets', 'transport.spr'), 'rb').read()
    bad = []
    for sid in range(5):
        base = ART[TILE_BASE + 8 * (2 if sid & 1 else 7):][:8]
        for q in range(4):
            qx, qy = q & 1, q >> 1
            want = bytes(base[r] | spr[sid * 32 + (qy * 8 + r) * 2 + qx] for r in range(8))
            got = cell(mem, sid * 3 + qx, 20 + qy)[0]
            if got != want:
                bad.append((sid, q, got.hex(), want.hex()))
    check('all 5 sprites, in 4 cells each, are the picture ORed onto the tile under it', not bad, str(bad[:3]))
    print('FAILED: ' + ', '.join(failures) if failures else 'all tile tests passed')
    sys.exit(1 if failures else 0)


if __name__ == '__main__':
    main()
