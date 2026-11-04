#!/usr/bin/env python3
"""The PCW screen code (target/pcw/plat_pcw.asm) under z88dk-ticks, against a model of the screen written here from the description.

The harness gives the roller RAM at $B600 the values CP/M's would have for a screen at $4000 (a text row 720 bytes, the lines of its 8 pixel rows one byte apart:
the word w of a line with address a is ((a >> 1) & $7FF8) | (a & 7), which the code turns back into ((w << 1) & $FFF0) | (w & 7)), runs pcw_init, blits random cells,
inverts runs of cells and clears the screen.  The port writes that page the screen in are ignored by ticks, so the screen is plain RAM here: what is checked is the
arithmetic (the row table, the cell offset 16 * col, the 16 byte copy, the inversion, the clear), not the paging, which only a PCW or an emulator of one can check.
"""
import os
import random
import subprocess
import sys
import tempfile

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
SCREEN = 0x4000
MARGIN = 40                 # (the 40 columns are centred in the 720 pixels)
ROW_BYTES = 720


def line_address(y):
    return SCREEN + (y >> 3) * ROW_BYTES + (y & 7)


def roller_word(a):
    return ((a >> 1) & 0x7FF8) | (a & 7)


DRIVER = r"""
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#define __z88dk_fastcall
#define __smallc
static uint8_t tables[512];
#define PCW_TABLES tables
#include "../../target/pcw/plat_pcw.c"
const uint8_t *pcw_art;
uint8_t pcw_xor;
uint8_t pcw_invert_n;
static int verbose;
const uint8_t pcw_font[65 * 8] = { FONT_DATA };
const uint8_t pcw_icons[448];
void pcw_init(void) {}
void pcw_clear(void) {}
void pcw_invert(uint16_t colrow) { printf("invert %u %u %u\n", colrow & 255, colrow >> 8, pcw_invert_n); }
void cpm_print(const char *s) {}
uint8_t pcw_cellbuf[16];
uint8_t pcw_minibuf[96];
uint16_t pcw_mv_src, pcw_mv_len;
uint16_t pcw_rows[32];
static uint8_t fake[65536];                 /* the screen */
static int blits;
void pcw_blit(uint16_t colrow)
{
    int i;
    ++blits;
    if (verbose) { printf("blit %u %u ", colrow & 255, colrow >> 8); for (i = 0; i < 16; ++i) printf("%02x", pcw_cellbuf[i]); printf("\n"); }
    memcpy(fake + pcw_rows[colrow >> 8] + 16 * (colrow & 255), pcw_cellbuf, 16);
}
void pcw_put(uint16_t colrow)        /* what target/pcw/plat_pcw.asm does (checked by the harness), with the tables plat_init built */
{
    int i;
    for (i = 0; i < 8; ++i) {
        pcw_cellbuf[i] = tables[(uint8_t)(pcw_art[i] ^ pcw_xor)];
        pcw_cellbuf[8 + i] = tables[256 + (uint8_t)(pcw_art[i] ^ pcw_xor)];
    }
    pcw_blit(colrow);
}
void pcw_move(uint16_t dst) { memmove(fake + dst, fake + pcw_mv_src, pcw_mv_len); }
void pcw_mini(uint16_t dst)
{
    int i;
    for (i = 0; i < 48; ++i) { fake[dst + 8 * i] = pcw_minibuf[2 * i]; fake[dst + 8 * i + 1] = pcw_minibuf[2 * i + 1]; }
}

static uint8_t arts[40 * 26 * 2][8];        /* a picture for every cell, and the same for the other place */
static uint8_t *art_at(int x, int y, int variant) { return arts[(variant * 26 + y) * 40 + x]; }
static int check_scroll(int dx, int dy)
{
    int x, y, bad = 0, drawn, expect = 0;
    uint8_t saved[65536];

    memset(fake, 0, sizeof fake);
    plat_clear();
    for (y = 0; y < 26; ++y) for (x = 0; x < 40; ++x) plat_put_tile(x, 6 + y, art_at(x, y, 0), 0, 0);
    memcpy(saved, fake, sizeof fake);
    plat_scroll(6, 26, dx, dy);
    for (y = 0; y < 26; ++y) for (x = 0; x < 40; ++x)
        if (x + dx >= 0 && x + dx < 40 && y + dy >= 0 && y + dy < 26)
            if (memcmp(fake + pcw_rows[6 + y] + 16 * x, saved + pcw_rows[6 + y + dy] + 16 * (x + dx), 16)) ++bad;
    /* the game draws the cells that came into view; everything else it draws again must already be there */
    blits = 0;
    for (y = 0; y < 26; ++y) for (x = 0; x < 40; ++x) {
        int inside = x + dx >= 0 && x + dx < 40 && y + dy >= 0 && y + dy < 26;
        plat_put_tile(x, 6 + y, inside ? art_at(x + dx, y + dy, 0) : art_at(x, y, 1), 0, 0);
        if (!inside) ++expect;
    }
    drawn = blits;
    printf("scroll %d %d wrong %d redrawn %d expected %d\n", dx, dy, bad, drawn, expect);
    return 0;
}
int main(int argc, char **argv)
{
    uint8_t art[40][8];
    unsigned i, v, n, cell = 0;
    int k;

    for (k = 0; k < 32; ++k) pcw_rows[k] = 0x4028 + 720 * k;
    for (k = 0; k < 40 * 26 * 2; ++k) for (i = 0; i < 8; ++i) arts[k][i] = (uint8_t)(k * 7 + i * 13 + (k >> 3));
    plat_init();
    if (argc > 1) {
        static const int moves[][2] = { {1,0}, {-1,0}, {0,1}, {0,-1}, {8,0}, {-8,0}, {0,8}, {0,-8}, {3,-2}, {-4,5}, {39,0}, {0,25} };
        for (k = 0; k < (int)(sizeof moves / sizeof moves[0]); ++k) check_scroll(moves[k][0], moves[k][1]);
        /* a tile drawn twice is drawn once; text over it makes it drawn again */
        blits = 0; plat_put_tile(3, 10, art_at(3, 4, 0), 0, 0); plat_put_tile(3, 10, art_at(3, 4, 0), 0, 0);
        printf("twice %d\n", blits);
        plat_put_tile(3, 10, art_at(3, 4, 0), 0, 1); printf("inverse %d\n", blits);
        plat_put(3, 10, 'A'); plat_put_tile(3, 10, art_at(3, 4, 0), 0, 1); printf("after text %d\n", blits);
        plat_put_bitmap(3, 10, art_at(3, 4, 0)); plat_put_tile(3, 10, art_at(3, 4, 0), 0, 1); printf("after bitmap %d\n", blits);
        plat_put_tile(3, 2, art_at(3, 4, 0), 0, 0); plat_put_tile(3, 2, art_at(3, 4, 0), 0, 0); printf("panel rows are not cached %d\n", blits);
        /* a mini map row */
        {
            uint8_t colours[96];
            memset(fake, 0, sizeof fake);
            for (k = 0; k < 96; ++k) colours[k] = (uint8_t)((k * 5 + (k >> 3)) & 15);
            plat_put_minirow(5, colours, 0, argv[1][0] - '0');
            printf("mini");
            for (k = 0; k < 48; ++k) printf(" %02x%02x", fake[pcw_rows[1] + 2 + 8 * k], fake[pcw_rows[1] + 3 + 8 * k]);
            printf("\n");
        }
        return 0;
    }
    verbose = 1;
    while (scanf("%u", &n) == 1) {                 /* 0 tile, 1 inverted tile, 2 text */
        for (i = 0; i < 8; ++i) { scanf("%u", &v); art[cell % 40][i] = (uint8_t)v; }
        if (n == 2) plat_put(7, 3, art[cell % 40][0]);
        else plat_put_tile(5, 9, art[cell % 40], 0, n);
        ++cell;
    }
    return 0;
}
"""


def expand(b):
    """A source byte as the two column bytes: each of its 8 pixels (bit 7 the left) drawn twice, the first four into the left byte."""
    w = 0
    for i in range(8):
        if b & (0x80 >> i):
            w |= 3 << (14 - 2 * i)
    return w >> 8, w & 255


def check_c():
    rng = random.Random(3)
    cases = []
    for k in range(40):
        cases.append((k % 3, [rng.randrange(256) for _ in range(8)]))
    for ch in (0, 31, 32, 65, 96, 97, 'a', 'z', 127, 200):
        cases.append((2, [ord(ch) if isinstance(ch, str) else ch] + [0] * 7))
    ok = True
    with tempfile.TemporaryDirectory() as tmp:
        open(os.path.join(tmp, 't.c'), 'w').write(DRIVER.replace('FONT_DATA', ','.join(str((i * 37 + 11) & 255) for i in range(65 * 8))))
        r = subprocess.run(['cc', '-w', '-I' + os.path.join(ROOT, 'ui'), '-I' + os.path.join(ROOT, 'engine'), '-I' + os.path.join(ROOT, 'target/pcw'), '-o', 't', 't.c'], cwd=tmp, capture_output=True, text=True)
        if r.returncode:
            print('FAIL  host compile:', r.stderr[:600])
            return False
        out = subprocess.run(['./t'], cwd=tmp, input=' '.join(str(n) + ' ' + ' '.join(map(str, a)) for n, a in cases), capture_output=True, text=True).stdout.split('\n')
        font = [(i * 37 + 11) & 255 for i in range(65 * 8)]
        bad = 0
        for (n, a), line in zip(cases, out):
            p = line.split()
            if n == 2:
                ch = a[0]
                if 1 <= ch <= 6:
                    continue                                            # (the frame's line pieces: drawn from their own table)
                if 97 <= ch <= 122:
                    ch -= 32
                ch = 32 if ch < 32 or ch > 96 else ch                  # (anything else is a space)
                art = font[(ch - 32) * 8:(ch - 32) * 8 + 8]
                want = (7, 3)
            else:
                art = [b ^ (0 if n == 1 else 0xFF) for b in a]      # (the map is inverse: the cursor's tile, n == 1, is as it is)
                want = (5, 9)
            left = bytes(expand(b)[0] for b in art).hex()
            right = bytes(expand(b)[1] for b in art).hex()
            if p[0] != 'blit' or (int(p[1]), int(p[2])) != want or p[3] != left + right:
                bad += 1
        print(('PASS' if not bad else 'FAIL') + f'  {len(cases)} tiles, inverted tiles and characters drawn twice across into the cell buffer (left column, right column)' + (f' ({bad} wrong)' if bad else ''))
        ok = not bad
        out = {v: subprocess.run(['./t', str(v)], cwd=tmp, capture_output=True, text=True).stdout.split('\n') for v in (1, 2)}
        sc = [l.split() for l in out[1] if l.startswith('scroll')]
        badsc = [l for l in sc if l[4] != '0' or l[6] != l[8]]
        print(('PASS' if sc and not badsc else 'FAIL') + f'  plat_scroll: {len(sc)} moves, every cell that stays is where it should be and only the cells that come into view are drawn again (the tile cache follows)' + (f' {badsc[:2]}' if badsc else ''))
        ok &= bool(sc) and not badsc
        want = ['twice 1', 'inverse 2', 'after text 4', 'after bitmap 6', 'panel rows are not cached 8']
        got = [l for l in out[1] if l and l.split()[0] in ('twice', 'inverse', 'after', 'panel')]
        print(('PASS' if got == want else 'FAIL') + '  the tile cache: a tile there already is not drawn, text, a bitmap or a different picture is, the panel rows are not cached' + ('' if got == want else f' {got}'))
        ok &= got == want
        pal_city = [0x00, 0xA5, 0x69, 0xF6, 0x48, 0xEA, 0xF9, 0x66] + [0] * 8
        pal_density = [0x00, 0x48, 0xA5, 0xED, 0xFF, 0xFF, 0xFF, 0xFF, 0x00, 0x00, 0x40, 0x40, 0x00, 0x40, 0x40, 0x40]
        for v, pal in ((1, pal_city), (2, pal_density)):
            col = [(k * 5 + (k >> 3)) & 15 for k in range(96)]
            want = []
            for i in range(48):
                a, b = pal[col[2 * i]], pal[col[2 * i + 1]]
                want.append('%02x%02x' % ((a & 0xF0) | (b >> 4), ((a & 15) << 4) | (b & 15)))
            got = [l.split()[1:] for l in out[v] if l.startswith('mini')][0]
            print(('PASS' if got == want else 'FAIL') + f'  plat_put_minirow, view {v}: a tile row of 96 colours as 4x2 pixel patterns, two lines, onto the screen' + ('' if got == want else f' {got[:4]} {want[:4]}'))
            ok &= got == want
    return ok


def main():
    rng = random.Random(8)
    cells = [(rng.randrange(40), rng.randrange(32), bytes(rng.randrange(256) for _ in range(16))) for _ in range(60)]
    cells += [(0, 0, bytes(range(16))), (39, 31, bytes(range(100, 116)))]
    puts = [(rng.randrange(40), rng.randrange(32), bytes(rng.randrange(256) for _ in range(8)), rng.choice([0, 255, 0x5A])) for _ in range(40)]
    inverts = [(3, 5, 4), (35, 20, 5), (0, 31, 1)]

    roller = []
    for y in range(256):
        w = roller_word(line_address(y))
        roller += [w & 255, w >> 8]
    asm = ['        org     $2000', '        SECTION code_user', '        EXTERN _pcw_init, _pcw_blit, _pcw_invert, _pcw_clear, _pcw_cellbuf, _pcw_invert_n, _pcw_put, _pcw_art, _pcw_xor, _pcw_move, _pcw_mv_src, _pcw_mv_len, _pcw_mini, _pcw_minibuf',
           'start:  ld      hl,rollerdata', '        ld      de,$B600', '        ld      bc,512', '        ldir', '        call    _pcw_init']
    for i, (c, r, d, x) in enumerate(puts):
        asm += [f'        ld      hl,art{i}', '        ld      (_pcw_art),hl', f'        ld      a,{x}', '        ld      (_pcw_xor),a', '        ld      ix,$1234', f'        ld      hl,{(r << 8) | c}', '        call    _pcw_put', '        push    ix', '        pop     hl', '        ld      de,$1234', '        or      a', '        sbc     hl,de', f'        jr      z,ixok{i}', '        ld      a,1', '        ld      (ixbad),a', f'ixok{i}:']
    asm += ['after_puts: nop']
    for i, (c, r, d) in enumerate(cells):
        asm += [f'        ld      hl,cell{i}', '        ld      de,_pcw_cellbuf', '        ld      bc,16', '        ldir', f'        ld      hl,{(r << 8) | c}', '        call    _pcw_blit']
    asm += ['after_blits: nop']
    for c, r, n in inverts:
        asm += [f'        ld      a,{n}', '        ld      (_pcw_invert_n),a', f'        ld      hl,{(r << 8) | c}', '        call    _pcw_invert']
    asm += ['after_invert: nop']
    # moves on the screen: forward and backward overlaps, and a different row; then a mini map row
    moves = [(0x4028 + 720 * 3, 0x4028 + 720 * 3 + 16, 600), (0x4028 + 720 * 5 + 16, 0x4028 + 720 * 5, 600), (0x4028 + 720 * 8, 0x4028 + 720 * 9, 640)]
    for src, dst, ln in moves:
        asm += [f'        ld      hl,{src}', '        ld      (_pcw_mv_src),hl', f'        ld      hl,{ln}', '        ld      (_pcw_mv_len),hl', f'        ld      hl,{dst}', '        call    _pcw_move']
    asm += ['        ld      hl,minidata', '        ld      de,_pcw_minibuf', '        ld      bc,96', '        ldir', f'        ld      hl,{0x4028 + 720 * 20 + 4}', '        call    _pcw_mini', 'after_moves: nop']
    asm += [ '        ld      ix,$1234', '        call    _pcw_clear', '        ld      (ixsave),ix', 'the_end: nop', '        jr      the_end']
    asm += ['ixsave: defw 0', 'ixbad: defb 0', 'minidata: defb ' + ','.join(str((i * 11 + 3) & 255) for i in range(96)), 'rollerdata:'] + ['        defb    ' + ','.join(str(b) for b in roller[i:i + 16]) for i in range(0, 512, 16)]
    for i, (c, r, d, x) in enumerate(puts):
        asm += [f'art{i}:', '        defb    ' + ','.join(str(b) for b in d)]
    for i, (c, r, d) in enumerate(cells):
        asm += [f'cell{i}:', '        defb    ' + ','.join(str(b) for b in d)]
    # (one section, so that the image is one file: the code, then the buffers)
    asm += [l.replace('SECTION code_himem', 'SECTION code_user').replace('SECTION bss_himem', 'SECTION code_user') for l in open(os.path.join(ROOT, 'target/pcw/plat_pcw.asm')).read().split('\n')]
    ok = True
    with tempfile.TemporaryDirectory() as tmp:
        src = os.path.join(tmp, 'h.asm')
        open(src, 'w').write('\n'.join(asm) + '\n')
        r = subprocess.run(['z88dk-z80asm', '-b', '-m', '-I' + ROOT, src], capture_output=True, text=True, cwd=ROOT)
        if r.returncode:
            print('FAIL  assemble:', r.stdout, r.stderr)
            return 1
        syms = {}
        for line in open(os.path.join(tmp, 'h.map')):
            p = line.split()
            if len(p) >= 3 and p[1] == '=':
                syms[p[0]] = int(p[2].lstrip('$'), 16)
        img = open(os.path.join(tmp, 'h.bin'), 'rb').read() if os.path.getsize(os.path.join(tmp, 'h.bin')) else b''
        if not img:
            img = open(os.path.join(tmp, 'h_code_user.bin'), 'rb').read()
        full = bytearray(65536)
        full[0x2000:0x2000 + len(img)] = img
        for v in range(256):                                    # the doubling tables plat_init builds
            full[0xF200 + v] = expand(v)[0]
            full[0xF300 + v] = expand(v)[1]
        open(os.path.join(tmp, 'img.bin'), 'wb').write(full)

        def run(end, out):
            r = subprocess.run(['z88dk-ticks', '-pc', '2000', '-end', f'{syms[end]:x}', '-output', out, os.path.join(tmp, 'img.bin')], capture_output=True, text=True, cwd=tmp)
            return open(os.path.join(tmp, out), 'rb').read()

        # Loading the whole image at $2000 would not put the HIMEM sections where the build does; they follow the code, which is what the model needs.
        m = run('after_puts', 'm0.out')
        model = bytearray(0x10000)
        for c, r, d, x in puts:
            a = line_address(r * 8) + MARGIN + 16 * c
            model[a:a + 8] = bytes(expand(b ^ x)[0] for b in d)
            model[a + 8:a + 16] = bytes(expand(b ^ x)[1] for b in d)
        bad = [a for a in range(SCREEN, SCREEN + 32 * ROW_BYTES) if m[a] != model[a]]
        print(('PASS' if not bad and m[syms['ixbad']] == 0 else 'FAIL') + f'  {len(puts)} cells put from 8 bytes (drawn twice across, xor, IX kept)' + (f' ({len(bad)} bytes differ, first at {bad[0]:04x})' if bad else ''))
        ok &= not bad and m[syms['ixbad']] == 0
        m = run('after_blits', 'm1.out')
        for c, r, d in cells:
            a = line_address(r * 8) + MARGIN + 16 * c
            model[a:a + 16] = d
        bad = [a for a in range(SCREEN, SCREEN + 32 * ROW_BYTES) if m[a] != model[a]]
        print(('PASS' if not bad else 'FAIL') + f'  {len(cells)} cells blitted to the 16 bytes at rows[row] + 16 * col' + (f' ({len(bad)} bytes differ, first at {bad[0]:04x})' if bad else ''))
        ok &= not bad
        rows = [m[syms['_pcw_rows'] + 2 * i] | (m[syms['_pcw_rows'] + 2 * i + 1] << 8) for i in range(32)] if '_pcw_rows' in syms else None
        if rows is not None:
            want = [line_address(8 * i) + MARGIN for i in range(32)]
            print(('PASS' if rows == want else 'FAIL') + '  the row table from the roller RAM', [hex(x) for x in rows[:4]], [hex(x) for x in want[:4]])
            ok &= rows == want
        m = run('after_invert', 'm2.out')
        for c, r, n in inverts:
            a = line_address(r * 8) + MARGIN + 16 * c
            for i in range(16 * n):
                model[a + i] ^= 0xFF
        bad = [a for a in range(SCREEN, SCREEN + 32 * ROW_BYTES) if m[a] != model[a]]
        print(('PASS' if not bad else 'FAIL') + f'  {len(inverts)} runs of cells inverted' + (f' ({len(bad)} bytes differ, first at {bad[0]:04x})' if bad else ''))
        ok &= not bad
        m = run('after_moves', 'mm.out')
        for src, dst, ln in moves:
            model[dst:dst + ln] = bytes(model[src:src + ln])
        a = 0x4028 + 720 * 20 + 4
        for i in range(48):
            model[a + 8 * i] = (i * 2 * 11 + 3) & 255
            model[a + 8 * i + 1] = ((i * 2 + 1) * 11 + 3) & 255
        bad = [a for a in range(SCREEN, SCREEN + 32 * ROW_BYTES) if m[a] != model[a]]
        print(('PASS' if not bad else 'FAIL') + '  pcw_move (forward and backward overlaps, another row) and pcw_mini (48 pairs of bytes, a column apart)' + (f' ({len(bad)} bytes differ, first at {bad[0]:04x})' if bad else ''))
        ok &= not bad
        m = run('the_end', 'm3.out')
        bad = [a for a in range(SCREEN, SCREEN + 32 * ROW_BYTES) if m[a]]
        print(('PASS' if not bad else 'FAIL') + '  the clear blanks all 32 text rows' + (f' ({len(bad)} bytes left, first at {bad[0]:04x})' if bad else ''))
        ok &= not bad
        ixv = m[syms['ixsave']] | (m[syms['ixsave'] + 1] << 8)
        print(('PASS' if ixv == 0x1234 else 'FAIL') + f'  IX (the C code frame pointer) kept across the clear: {ixv:04x}')
        ok &= ixv == 0x1234
    ok &= check_c()
    return 0 if ok else 1


if __name__ == '__main__':
    sys.exit(main())
