#!/usr/bin/env python3
"""target/lynx/lynx_lsec.asm (the file code's sectors of 256 bytes on z88dk's 512 byte sector driver) under z88dk-ticks, against the WD1793 model: the disk is a line of bytes, a
logical sector (16 to a logical track) is 256 bytes of it, two to a physical sector.  Reads and writes of runs that begin on either half, are of one sector or many, end on either
half and cross physical tracks are compared with a model of the line: a read gives the bytes, a write changes exactly those bytes (the neighbouring half of a physical sector keeps its
own) and writes only the physical sectors it touches.
"""
import os, subprocess, sys, tempfile

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
HERE = os.path.dirname(os.path.abspath(__file__))
CFG = os.environ.get('ZCCCFG', os.path.expanduser('~/z88dk/lib/config'))
MODEL = os.path.join(CFG, '..', 'ticks', 'memory', 'lynx.lua')        # z88dk's Lynx 128K model
CLIBS = os.path.join(os.environ.get('ZCCCFG', os.path.expanduser('~/z88dk/lib/config')), '..', 'clibs')

HARNESS = """
        SECTION code_user
        org     $2000
start:  ld      sp,$7000
        ld      hl,$4000                    ; the buffer: 3 * i + 1 (a write sends this)
        ld      de,0
fill:   ld      a,e
        add     a,a
        add     a,e
        inc     a
        ld      (hl),a
        inc     hl
        inc     de
        ld      a,d
        cp      $30
        jr      nz,fill
        ld      a,@MODE@
        ld      e,0
        ld      d,@LTRACK@
        ld      c,@LSEC@
        ld      b,@COUNT@
        ld      hl,$4000
        call    asm_lynx_lsec_regs
        ld      ($3F00),hl
        ld      a,1
        out     ($F0),a
done:   jp      done
        EXTERN  asm_lynx_lsec_regs
"""


def pattern(t, s, i):
    return (t * 7 + s * 29 + i) & 0xff


def disc_byte(off):
    p, i = divmod(off, 512)
    return pattern(p // 10, p % 10 + 1, i)


def fill(i):
    return (3 * i + 1) & 0xff


def run(mode, ltrack, lsec, count, env=None):
    with tempfile.TemporaryDirectory() as tmp:
        src = HARNESS
        for k, v in dict(MODE=mode, LTRACK=ltrack, LSEC=lsec, COUNT=count).items():
            src = src.replace('@%s@' % k, str(v))
        open(os.path.join(tmp, 'h.asm'), 'w').write(src)
        r = subprocess.run(['z88dk-z80asm', '-b', '-m', '-I' + ROOT, '-L' + CLIBS, '-llynx_clib', os.path.join(tmp, 'h.asm'), os.path.join(ROOT, 'target/lynx/lynx_lsec.asm')],
                           capture_output=True, text=True, cwd=ROOT)
        if r.returncode:
            sys.exit(r.stdout + r.stderr)
        img = b''.join(open(os.path.join(tmp, f), 'rb').read() for f in ('h_code_user.bin', 'h_code_clib.bin') if os.path.exists(os.path.join(tmp, f)))
        open(os.path.join(tmp, 'img.bin'), 'wb').write(bytearray(0x2000) + img)
        done = [l for l in open(os.path.join(tmp, 'h.map')) if l.startswith('done ')][0].split('$')[1][:4]
        e = dict(os.environ, ZCCCFG=CFG, LYNX_OUTDIR=tmp, **(env or {}))
        r = subprocess.run(['z88dk-ticks', '-b', 'lua', '-lua', MODEL, '-pc', '2000', '-end', done, '-counter', '400000000', '-output', os.path.join(tmp, 'mem.out'),
                            os.path.join(tmp, 'img.bin')], capture_output=True, text=True, cwd=tmp, env=e)
        mem = open(os.path.join(tmp, 'mem.out'), 'rb').read()
        written = {}
        p = os.path.join(tmp, 'disk_out.txt')
        if os.path.exists(p):
            for line in open(p):
                t, s, hx = line.split()
                written[(int(t), int(s))] = bytes.fromhex(hx)
        errs = open(os.path.join(tmp, 'fdc_errors.txt')).read().strip() if os.path.exists(os.path.join(tmp, 'fdc_errors.txt')) else 'no dump: ' + r.stdout + r.stderr
        return mem, written, errs


def main():
    bad = 0
    cases = []
    for lt, ls in ((0, 1), (0, 2), (0, 3), (0, 16), (1, 1), (1, 2), (3, 7), (5, 15), (12, 16), (24, 1)):   # (logical track 25, physical track 20, is where the files start)
        for n in (1, 2, 3, 4, 5, 16, 45):
            cases.append((lt, ls, n))
    for mode in (0, 1):
        for lt, ls, n in cases:
            mem, w, errs = run(mode, lt, ls, n)
            res = mem[0x3F00] | mem[0x3F01] << 8
            L = lt * 16 + ls - 1
            lo, hi = L * 256, (L + n) * 256
            name = '%s logical track %d sector %d x%d' % ('write' if mode else 'read', lt, ls, n)
            ok = res == 0 and errs == ''
            why = 'hl=%d errors=%s' % (res, errs)
            if ok and mode == 0:
                exp = bytes(disc_byte(o) for o in range(lo, hi))
                ok = mem[0x4000:0x4000 + n * 256] == exp
                why = 'data differs'
            elif ok:
                touched = sorted({(o // 512) for o in range(lo, hi)})
                expect = {}
                for p in touched:
                    expect[(p // 10, p % 10 + 1)] = bytes(fill(o - lo) if lo <= o < hi else disc_byte(o) for o in range(p * 512, p * 512 + 512))
                ok = w == expect
                why = 'sectors written %s, expected %s' % (sorted(w), sorted(expect))
                if not ok and set(w) == set(expect):
                    why = 'contents of %s differ' % [k for k in w if w[k] != expect[k]]
            if not ok:
                bad += 1
                print('FAIL', name, why)
    print('%d cases' % (2 * len(cases)), 'FAILED: %d' % bad if bad else 'all ok')
    return 1 if bad else 0


if __name__ == '__main__':
    sys.exit(main())
