#!/usr/bin/env python3
"""Run the SPC-1000 game headless under z88dk-ticks with the video RAM as flat memory (plat_spc1000.asm -DVRAM_FLAT) and a scripted key, then
draw the 256x192 screen to a PNG (default build/spc1000flat/screen.png).  usage: test/spc1000/flat.py [cycles] [out.png]"""
import os, re, subprocess, sys
ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
OUT = os.path.join(ROOT, 'build', 'spc1000flat')
BASE = 0xE000
ZCC = ['zcc', '-compiler=80cc', '-fframe-pointer', '+spc1000', '-subtype=allram', '-create-app', '-m', '-Cp-DAPP_VERSION=1.2.0', '-Ca-DPORTABLE', '-Ca-Iengine', '-Ca-I.', '-Iui', '-Cc-standard-escape-chars',
       '-pragma-include:target/spc1000/zpragma.inc', '-Itarget/spc1000', '-DTARGET_SPC1000', '-Ca-DTARGET_SPC1000', '-Ca-DFMT_WIDTH=32', '-Ca-DHAVE_MINIMAP_SQUARE', '-Ca-DHAVE_SOUND', '-Ca-DAY_ISR',
       '-Ca-DAY_PORT16', '-Ca-DAY_ADDR_PORT=0x4000', '-Ca-DAY_DATA_PORT=0x4001', '-Ca-DVRAM_FLAT=0x%X' % BASE, '-Ca-Ibuild/spc1000flat']
SRC = ['ui/main.c', 'ui/game.c', 'ui/text.c', 'ui/textfmt.c', 'ui/numfmt.asm', 'ui/budget.c', 'ui/evaluation.c', 'ui/cityfile.c', 'ui/minimap.c', 'ui/sprites.c',
       'ui/prompt.c', 'engine/engine_c.asm', 'platform/common/hooks.asm', 'platform/common/entropy.asm', 'ui/menu.c', 'target/common/ay_hooks.asm',
       'target/common/ay_sfx.asm', 'ui/fmtfields.asm', 'target/common/minimap_640x200_3bpp.asm', 'target/common/line_editor.asm', 'target/spc1000/plat_spc1000.asm', 'target/spc1000/plat_spc1000.c', 'target/spc1000/plat_sound.asm']

def build():
    # (the host build has the key script in it and can be too big for the loader's unpack-in-place check: only simcity.bin and the map matter here)
    r = subprocess.run(ZCC + SRC + ['-o', os.path.join(OUT, 'simcity.bin')], cwd=ROOT, capture_output=True, text=True)
    if r.returncode and 'unpacks over its own packed data' not in r.stdout + r.stderr:
        sys.exit(r.stdout + r.stderr)

NAMES = {'comma': 44, 'dot': 46, 'down': 10, 'up': 11, 'left': 8, 'right': 9, 'enter': 13, 'esc': 27, 'space': 32}

def key_position(code):
    """(row, bit) of the key with this code: the CRT's table (z88dk's in_keytranstbl, unshifted) has 8 codes a row, bit 7 first, rows 0 to 9."""
    img = open(os.path.join(OUT, 'simcity.bin'), 'rb').read()
    sym = int(re.search(r'^in_keytranstbl\s*=\s*\$([0-9A-Fa-f]+)', open(os.path.join(OUT, 'simcity.map')).read(), re.M).group(1), 16)
    for row in range(1, 10):
        for k in range(8):
            if img[sym + row * 8 + k] == code:
                return row, 7 - k
    raise SystemExit('no key with code %d' % code)

def script(spec):
    """spec 'gap:key,gap:key*n,gap:key~hold': wait gap looks (the game looks at the keyboard about once a frame), then press the key for one look, or hold
    of them; *n does it n times.  Returns the rows of every look, 9 bytes each."""
    looks = []
    for item in spec.split(','):
        gap, key = item.split(':')
        n, hold = 1, 1
        if '*' in key:
            key, n = key.split('*')
            n = int(n)
        if '~' in key:
            key, hold = key.split('~')
            hold = int(hold)
        code = NAMES.get(key, ord(key[0]))
        row, bit = key_position(code)
        for _ in range(n):
            looks += [[0] * 9] * int(gap)
            rows = [0] * 9
            rows[row - 1] = 1 << bit
            looks += [rows] * hold
    return looks

def main():
    """KEYS in the environment (see script()); the default is the easy level after 60 looks.  Run with 'KEYS=' and the screen is the title."""
    cycles = int(sys.argv[1]) if len(sys.argv) > 1 else 80000000
    png = sys.argv[2] if len(sys.argv) > 2 else os.path.join(OUT, 'screen.png')
    os.makedirs(OUT, exist_ok=True)
    # the key table's address does not depend on the script: build once with an empty one, then with the real
    open(os.path.join(OUT, 'script.inc'), 'w').write('mp_stream_left: defw 0\nmp_stream_ptr: defw 0\n')
    build()
    looks = script(os.environ.get('KEYS', '60:1')) if os.environ.get('KEYS', '60:1') else []
    lines = ['mp_stream_left: defw %d' % len(looks), 'mp_stream_ptr: defw mp_stream_data', 'mp_stream_data:']
    runs = []                                       # (count, rows): equal looks together, at most 255
    for rows in looks:
        if runs and runs[-1][1] == rows and runs[-1][0] < 255:
            runs[-1][0] += 1
        else:
            runs.append([1, rows])
    lines[0] = 'mp_stream_left: defw %d' % len(runs)
    for n, rows in runs:
        lines.append('        defb    %d,' % n + ','.join(str(b) for b in rows))
    open(os.path.join(OUT, 'script.inc'), 'w').write('\n'.join(lines) + '\n')
    build()
    img = open(os.path.join(OUT, 'simcity.bin'), 'rb').read()
    mem = bytearray(65536)
    if os.environ.get('JUNK'):                      # what BASIC left in RAM: the memory the program does not load is not zero
        import random
        random.seed(int(os.environ['JUNK']))
        for a in range(len(img), 0xFFF0):
            mem[a] = random.randrange(256)
    mem[:len(img)] = img
    open(os.path.join(OUT, 'img.bin'), 'wb').write(mem)
    r = subprocess.run(['z88dk-ticks', '-pc', '0', '-int', '66667', '-counter', str(cycles), '-output', os.path.join(OUT, 'mem.out'), os.path.join(OUT, 'img.bin')],
                       capture_output=True, text=True)
    out = open(os.path.join(OUT, 'mem.out'), 'rb').read()
    from PIL import Image
    mm = open(os.path.join(OUT, 'simcity.map')).read()
    cg = out[int(re.search(r'^_mp_cg\s*=\s*\$([0-9A-Fa-f]+)', mm, re.M).group(1), 16)]
    if cg:                                          # the CG6 mini map: 128x192, two bits a pixel, colour set 0 (green, yellow, blue, red)
        pal = [(0, 170, 0), (255, 255, 0), (0, 0, 255), (255, 0, 0)]
        im = Image.new('RGB', (128, 192))
        px = im.load()
        for y in range(192):
            for xb in range(32):
                b = out[BASE + y * 32 + xb]
                for x in range(4):
                    px[xb * 4 + x, y] = pal[(b >> (6 - 2 * x)) & 3]
        im = im.resize((768, 576), Image.NEAREST)
    else:
        im = Image.new('L', (256, 192))
        px = im.load()
        for y in range(192):
            for xb in range(32):
                b = out[BASE + y * 32 + xb]
                for x in range(8):
                    px[xb * 8 + x, y] = 255 if b & (0x80 >> x) else 0
        im = im.resize((768, 576), Image.NEAREST)
    im.save(png)
    print('wrote', png, r.stdout.strip()[-80:])

main()
