#!/usr/bin/env python3
"""The SAM Coupe's animation routine (mp_anim in target/sam/plat_sam.asm) under z88dk-ticks: for every one of the engine's 345 pictures and a set of values of the game's
frame counter, the art it returns is the picture's own if it is not animated, and else the art of the frame the tables (build/sam/anim.inc, which tools/st_tiles_3bpp.py
--sam-anim makes) and the counter say: the first frame plus (the counter / 16) masked by the number of frames less one.  Needs no emulator of the SAM.

    python3 test/sam/anim_check.py          (make build/sam/anim.inc first: make sam does)"""
import os
import re
import subprocess
import sys
import tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.path.insert(0, os.path.join(ROOT, 'tools'))
import st_tiles_3bpp as T      # noqa: E402

ART, TICK = 0x2000, 0xF000
TICKS = (0, 15, 16, 31, 32, 48, 64, 80, 255)


def main():
    if not os.path.exists(os.path.join(ROOT, 'build/sam/anim.inc')):
        subprocess.run(['make', '-s', 'build/sam/anim.inc'], cwd=ROOT, check=True)
    src = open(os.path.join(ROOT, 'target/sam/plat_sam.asm')).read()
    routine = src[src.index('mp_anim:'):src.index('        INCLUDE "build/sam/anim.inc"')]
    cases = [(n, t) for n in range(T.OURS) for t in TICKS]
    asm = f'''        org 0
        defc _view_tile_art = {ART}
        defc _V_view_tick = {TICK}
        ld ix,cases
        ld iy,results
        ld bc,{len(cases)}
loop:   push bc
        ld a,(ix+2)
        ld ({TICK}),a
        ld l,(ix+0)
        ld h,(ix+1)
        add hl,hl
        add hl,hl
        add hl,hl
        ld bc,{ART}
        add hl,bc
        ex de,hl
        ld a,5
        ld bc,$0102
        call mp_anim
        ld (iy+0),e
        ld (iy+1),d
        ld de,3
        add ix,de
        ld de,2
        add iy,de
        pop bc
        dec bc
        ld a,b
        or c
        jr nz,loop
done:   jr done
{routine}
        include "build/sam/anim.inc"
cases:
''' + ''.join(f'        defw {n}\n        defb {t}\n' for n, t in cases) + f'''results:
        defs 2 * {len(cases)}
'''
    with tempfile.TemporaryDirectory() as tmp:
        open(f'{tmp}/h.asm', 'w').write(asm)
        r = subprocess.run(['z88dk-z80asm', '-b', '-m', '-I' + ROOT, f'-o{tmp}/h.bin', f'{tmp}/h.asm'], capture_output=True, text=True, cwd=ROOT)
        if r.returncode:
            print('FAIL  assembling:', r.stderr[-300:])
            return 1
        m = open(f'{tmp}/h.map').read()
        sym = lambda n: int(re.search(r'^%s\s*=\s*\$([0-9A-Fa-f]+)' % n, m, re.M).group(1), 16)
        subprocess.run(['z88dk-ticks', f'{tmp}/h.bin', '-end', hex(sym('done')), '-counter', '30000000', '-output', f'{tmp}/h.dump'], capture_output=True)
        d = open(f'{tmp}/h.dump', 'rb').read()
    res = sym('results')
    extra, amap, entries = T.animation([T.st_picture_ours(i) for i in range(T.OURS)])
    bad = 0
    for k, (n, t) in enumerate(cases):
        got = d[res + 2 * k] | (d[res + 2 * k + 1] << 8)
        e = amap[n]
        want = ART + 8 * ((entries[e - 1][0] + ((t >> 4) & (entries[e - 1][1] - 1))) if e else n)
        if got != want:
            bad += 1
            if bad < 6:
                print(f'      picture {n}, counter {t}: {got:#x}, wanted {want:#x}')
    animated = sum(1 for v in amap if v)
    ok = bad == 0 and animated == 11 and len(extra) == 48
    print(('PASS' if ok else 'FAIL') + f'  mp_anim: {len(cases)} cases (every picture, {len(TICKS)} counters), {bad} wrong, {animated} animated pictures with {len(extra)} frames')
    return 0 if ok else 1


if __name__ == '__main__':
    sys.exit(main())
