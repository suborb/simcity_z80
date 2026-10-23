#!/usr/bin/env python3
"""Checks the Aquarius+ square mini map's C (plat_put_minirow and plat_minimap_key in target/aqplus/plat_aqplus.c) on the host.

The block between `#ifdef HAVE_MINIMAP_SQUARE` and its `#endif` is cut out of the file and compiled with the host's compiler against stubs of
the video copy (aq_vcopy writes into a model of the 16 KB video page) and of aq_blit8 and plat_text_puts; random rows of colours go in, and the
page is compared with a model written here from the description: a tile is a solid 2x2 block for the colours that are something built or a
road, water is two pixels corner to corner, dirt and trees are black; the cell colours are the paper of the highest density level, red or yellow
for power, white on black otherwise.
"""
import os
import random
import re
import subprocess
import sys
import tempfile

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
MM_COL0 = 4
DENSITY = [0x70, 0x7B, 0x74, 0x79, 0x72, 0x0C, 0x03, 0x71]
POWER = [0x70, 0x30, 0x10]
SOLID = {2, 3, 5, 6, 7}

DRIVER = r'''
#include <stdint.h>
#include <stdio.h>
#include <string.h>
#define HAVE_MINIMAP_SQUARE
#define MM_SIDE_COL 28
#define __smallc
uint8_t video[0x4000];
uint8_t aq_mm_buf[72];
void aq_vcopy(uint16_t offset, const uint8_t *src, uint8_t n) { memcpy(video + offset, src, n); }
void aq_blit8(uint8_t col, uint8_t row, const uint8_t *art, uint8_t colour, uint8_t inverse) { printf("blit %d %d %02x %02x\n", col, row, art[0], colour); }
void plat_text_puts(uint8_t col, uint8_t row, const char *s) { printf("text %d %d %s\n", col, row, s); }
BLOCK
int main(void)
{
    uint8_t colours[96], base[96];
    int ty, view, mode, i, n;
    unsigned v;

    while (scanf("%d %d %d", &ty, &view, &mode) == 3) {          /* ty view usebase, then 96 colours and 96 base colours */
        for (i = 0; i < 96; ++i) { scanf("%u", &v); colours[i] = (uint8_t)v; }
        for (i = 0; i < 96; ++i) { scanf("%u", &v); base[i] = (uint8_t)v; }
        plat_put_minirow((uint8_t)ty, colours, mode ? base : 0, (uint8_t)view);
    }
    for (n = 0; n < 0x4000; ++n)
        printf("%02x", video[n]);
    printf("\n");
    plat_minimap_key(1); plat_minimap_key(2); plat_minimap_key(6);
    return 0;
}
'''


def main():
    src = open(os.path.join(ROOT, 'target/aqplus/plat_aqplus.c')).read()
    a = src.index('#ifdef HAVE_MINIMAP_SQUARE')
    b = src.index('#endif', src.rindex('plat_minimap_key')) + len('#endif')
    block = src[a:b]
    rng = random.Random(5)
    rows = []                                                      # (ty, view, usebase, colours, base)
    for view in (1, 2, 3, 4, 5, 6, 7, 8):
        for cell_row in (0, 7, 23):                                 # whole cell rows, in order, as the game draws them
            for k in range(4):
                ty = cell_row * 4 + k
                dens = view in (2, 3, 4, 5, 8)
                colours = [rng.randrange(8) for _ in range(96)]
                if view == 6:
                    colours = [rng.choice((0, 1, 2, 7)) for _ in range(96)]
                if view == 7:
                    colours = [rng.choice((0, 1, 7)) for _ in range(96)]
                if cell_row == 7 and k == 0 and dens:               # a cell with no density at all
                    colours = [0 if i < 8 else c for i, c in enumerate(colours)]
                base = [rng.randrange(8) for _ in range(96)]
                rows.append((ty, view, 1 if dens else 0, colours, base))
    with tempfile.TemporaryDirectory() as tmp:
        open(os.path.join(tmp, 't.c'), 'w').write(DRIVER.replace('BLOCK', block))
        r = subprocess.run(['cc', '-O0', '-w', '-o', os.path.join(tmp, 't'), os.path.join(tmp, 't.c')], capture_output=True, text=True)
        if r.returncode:
            print(r.stderr)
            print('FAIL  the mini map block does not compile on the host')
            return 1
        stdin = ''.join(f'{ty} {view} {ub} ' + ' '.join(map(str, c)) + ' ' + ' '.join(map(str, bs)) + '\n' for ty, view, ub, c, bs in rows)
        out = subprocess.run([os.path.join(tmp, 't')], input=stdin, capture_output=True, text=True).stdout.split('\n')

    # the model: the video page after all the rows were drawn in order (each view's rows over the last one's: so model them in order)
    page = bytearray(0x4000)
    cellmax = [0] * 24
    for ty, view, ub, colours, base in rows:
        src_c = base if ub else colours
        cy, r = ty >> 2, (ty & 3) * 2
        for cx in range(24):
            b0 = b1 = 0
            for i in range(4):
                c = src_c[cx * 4 + i] & 7
                l0, l1 = (0b11, 0b11) if c in SOLID else ((0b10, 0b01) if c == 1 else (0, 0))
                b0 = (b0 << 2 | l0) & 0xFF
                b1 = (b1 << 2 | l1) & 0xFF
            page[cy * 320 + r * 40 + MM_COL0 + cx] = b0
            page[cy * 320 + (r + 1) * 40 + MM_COL0 + cx] = b1
        dens = view in (2, 3, 4, 5, 8)
        if ty & 3 == 0:
            cellmax = [0] * 24
        for cx in range(24):
            for i in range(4):
                c = colours[cx * 4 + i] & 7
                w = c if dens else (2 if c == 2 else 1 if c == 7 else 0) if view == 6 else 0
                cellmax[cx] = max(cellmax[cx], w)
        if ty & 3 == 3:
            for cx in range(24):
                page[0x2000 + cy * 40 + MM_COL0 + cx] = DENSITY[cellmax[cx]] if dens else POWER[cellmax[cx]] if view == 6 else 0x70
    got = bytes.fromhex(next(l for l in out if len(l) == 0x8000))
    bad = [i for i in range(0x4000) if got[i] != page[i]]
    ok = not bad
    print(('PASS' if ok else 'FAIL') + f'  plat_put_minirow: {len(rows)} rows over the eight views: the pixel lines and the cell colours equal the model'
          + (f' ({len(bad)} bytes differ, first at offset ${bad[0]:04X}: {got[bad[0]]:02X}, wanted {page[bad[0]]:02X})' if bad else ''))
    keys = [l for l in out if l.startswith('blit') or l.startswith('text')]
    has = lambda s: any(s in l for l in keys)
    ok2 = has('text 28 6 LOW') and has('text 28 14 HIGH') and has('text 29 6 BUILT') and has('text 29 7 NO PWR') and \
        sum(l.startswith('blit 28') for l in keys) == 2 + 7 + 3
    print(('PASS' if ok2 else 'FAIL') + '  plat_minimap_key: the city, density and power keys draw their swatches and labels at the sidebar column')
    return 0 if ok and ok2 else 1


if __name__ == '__main__':
    sys.exit(main())
