#!/usr/bin/env python3
"""Checks the Aquarius+ square mini map's C (plat_put_minirow, plat_minimap_mode and plat_minimap_key in target/aqplus/plat_aqplus.c) on the host.

The text-layer helpers (from `#define MM_CH_SOLID` to the end of tcells) and the block between `#ifdef HAVE_MINIMAP_SQUARE` and its `#endif` are cut
out of the file and compiled with the host's compiler against stubs of the assembler (aq_vcopy writes into a model of the 16 KB video page, aq_tcell
and aq_defchar log what they are given); random rows of colours go in, and the 4bpp page is compared with a model written here from the description:
a tile is one pixel (the upper nibble of a byte the left one) on two lines of 80 bytes, from byte 8, in the colour the view's table gives it; a density is
the ramp of its level (1..7) and the dim city where the level is none.  The keys' cells are checked against the same colours.
"""
import os
import random
import subprocess
import sys
import tempfile

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
COL0 = 8
CITY = [0, 4, 7, 3, 15, 13, 6, 8]
POWER = [0, 9, 1, 15, 0, 15, 3, 15]
TRANS = [0, 9, 15, 15, 0, 15, 15, 7]
DIM = [0, 9, 15, 15, 0, 15, 15, 8]
RAMP = [0, 11, 4, 6, 2, 3, 5, 1]
SIDE = 28

DRIVER = r'''
#include <stdint.h>
#include <stdio.h>
#include <string.h>
#define HAVE_MINIMAP_SQUARE
#define MM_SIDE_COL 28
#define __smallc
#define __z88dk_fastcall
uint8_t video[0x4000];
uint8_t aq_mm_buf[72];
uint8_t aq_mm4, aq_mm_want, aq_txt;
void aq_txt_set(uint8_t m) { aq_txt = m; }
void aq_text_blank(void) {}
void aq_tcolour(uint8_t col, uint8_t row, uint8_t n, uint8_t colour) {}
void aq_mm_enter(void) { aq_mm4 = 1; printf("enter\n"); }
void aq_mm_leave(void) { aq_mm4 = 0; printf("leave\n"); }
void aq_vcopy(uint16_t offset, const uint8_t *src, uint8_t n) { memcpy(video + offset, src, n); }
void aq_tcell(uint8_t col, uint8_t row, uint8_t ch, uint8_t colour) { printf("t %d %d %d %d\n", col, row, ch, colour); }
void aq_defchar(uint8_t ch, const uint8_t *art) { printf("d %d %d\n", ch, art[0]); }
CHUNK_A
CHUNK_B
int main(void)
{
    uint8_t colours[96], base[96];
    int ty, view, mode, i, n;
    unsigned v;

    plat_minimap_mode(1);
    while (scanf("%d %d %d", &ty, &view, &mode) == 3) {          /* ty view usebase, then 96 colours and 96 base colours */
        for (i = 0; i < 96; ++i) { scanf("%u", &v); colours[i] = (uint8_t)v; }
        for (i = 0; i < 96; ++i) { scanf("%u", &v); base[i] = (uint8_t)v; }
        plat_put_minirow((uint8_t)ty, colours, mode ? base : 0, (uint8_t)view);
    }
    for (n = 0; n < 16000; ++n)
        printf("%02x", video[n]);
    printf("\n");
    for (i = 1; i <= 8; ++i) { printf("key %d\n", i); plat_minimap_key((uint8_t)i); }
    plat_minimap_mode(0);
    return 0;
}
'''


def main():
    src = open(os.path.join(ROOT, 'target/aqplus/plat_aqplus.c')).read()
    a = src.index('#define MM_CH_SOLID')
    b = src.index('\n}\n', src.index('static void tcells')) + 3
    chunk_a = src[a:b]
    a = src.index('#ifdef HAVE_MINIMAP_SQUARE')
    b = src.index('#endif', src.rindex('plat_minimap_key')) + len('#endif')
    chunk_b = src[a:b]
    rng = random.Random(5)
    ok = True
    total_rows = 0
    with tempfile.TemporaryDirectory() as tmp:
        open(os.path.join(tmp, 't.c'), 'w').write(DRIVER.replace('CHUNK_A', chunk_a).replace('CHUNK_B', chunk_b))
        r = subprocess.run(['cc', '-O0', '-w', '-o', os.path.join(tmp, 't'), os.path.join(tmp, 't.c')], capture_output=True, text=True)
        if r.returncode:
            print(r.stderr)
            print('FAIL  the mini map block does not compile on the host')
            return 1
        rows = []                                                    # (ty, view, usebase, colours, base): every tile row once, the views mixed
        for ty in range(96):
            view = rng.choice((1, 2, 3, 4, 5, 6, 7, 8))
            dens = view in (2, 3, 4, 5, 8)
            colours = [rng.randrange(8) for _ in range(96)]
            if dens and ty % 3 == 0:
                colours = [0 if rng.random() < 0.5 else c for c in colours]
            rows.append((ty, view, 1 if dens and ty % 5 else 0, colours, [rng.randrange(8) for _ in range(96)]))
        total_rows = len(rows)
        stdin = ''.join(f'{ty} {v} {ub} ' + ' '.join(map(str, c)) + ' ' + ' '.join(map(str, bs)) + '\n' for ty, v, ub, c, bs in rows)
        out = subprocess.run([os.path.join(tmp, 't')], input=stdin, capture_output=True, text=True).stdout.split('\n')

        page = bytearray(16000)
        for ty, v, ub, colours, base in rows:
            def pix(i):
                c = colours[i] & 7
                if v == 1:
                    return CITY[c]
                if v == 6:
                    return POWER[c]
                if v == 7:
                    return TRANS[c]
                if c:
                    return RAMP[c]
                return DIM[base[i] & 7] if ub else 0
            for i in range(48):
                byte = pix(2 * i) << 4 | pix(2 * i + 1)
                page[ty * 160 + COL0 + i] = byte
                page[ty * 160 + 80 + COL0 + i] = byte
        got = bytes.fromhex(next(l for l in out if len(l) == 32000))
        bad = [i for i in range(16000) if got[i] != page[i]]
        if bad:
            print(f'FAIL  {len(bad)} bytes differ, first at offset ${bad[0]:04X}: {got[bad[0]]:02X}, wanted {page[bad[0]]:02X}')
            ok = False
        print(('PASS' if ok else 'FAIL') + f'  plat_put_minirow: {total_rows} rows over the eight views: the 4bpp lines equal the model (two lines a tile row, from byte {COL0})')

    # the mode call and the keys
    ok2 = out[0] == 'enter'                                                    # opening a mini map enters the mode
    keys = {}
    cur = None
    for l in out:
        if l.startswith('key '):
            cur = int(l.split()[1])
            keys[cur] = []
        elif cur is not None and l.startswith('t '):
            keys[cur].append(tuple(int(x) for x in l.split()[1:]))
    ok2 = ok2 and out[out.index('key 8') + 1:].count('leave') == 1

    def swatches(view):                                                         # the solid cells (character 96) of the sidebar column
        return [(row, colour >> 4) for col, row, ch, colour in keys[view] if col == SIDE and ch == 96]
    ok2 = ok2 and swatches(1) == list(zip(range(6, 13), [CITY[5], CITY[6], CITY[3], CITY[2], CITY[7], CITY[1], CITY[4]]))
    ok2 = ok2 and swatches(6) == [(6, 3), (7, 1), (8, 15), (9, POWER[1])]
    ok2 = ok2 and swatches(7) == [(6, 7), (7, 15), (8, TRANS[1])]
    for v in (2, 3, 4, 5, 8):
        ok2 = ok2 and swatches(v) == [(6 + i, RAMP[i]) for i in range(1, 8)]
    text = lambda view, row: ''.join(chr(ch - 128) for col, r, ch, colour in keys[view] if r == row and col >= SIDE and ch != 96 and ch != 160 and colour == 0x70 and col > SIDE - 1)
    ok2 = ok2 and text(2, 6).startswith('LOW') and text(2, 14).startswith('HIGH') and text(1, 6).startswith('HOUSES') and text(6, 7).startswith('NOPWR') and text(1, 8).startswith('INDUSTRY') and text(1, 9).startswith('SERVICES')
    print(('PASS' if ok2 else 'FAIL') + '  plat_minimap_mode and plat_minimap_key: the mode is entered and left, the swatches are the views\' colours and the labels are beside them')
    return 0 if ok and ok2 else 1


if __name__ == '__main__':
    sys.exit(main())
