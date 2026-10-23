#!/usr/bin/env python3
"""The PC-8801's file routines (target/pc88/plat_pc88_files.asm) and the file name editor (target/common/line_editor.asm) under
z88dk-ticks.

The file routines run against a disk in memory, a stand-in for z88dk's asm_pc88_disk_regs that has tracks 16 to 21 (two slots),
and the editor with scripted keys and a log of what it draws.  Python then looks at the disk, the buffers and the results.

  usage: test/pc88/files.py
"""
import os
import random
import re
import subprocess
import sys
import tempfile

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
Z80ASM = 'z88dk-z80asm'
TICKS = 'z88dk-ticks'

DISK = 0x4000                           # tracks 16 to 21 of 16 sectors of 256 bytes
ONES = 0x3800                           # names and headers
R_SRC1, R_OUT1 = 0xA000, 0xC400         # two 9216 byte areas
R_SRC2, R_OUT2, R_OUT3, R_OUT4 = 0xE800, 0xEC00, 0xF000, 0xF400

FILES = '''        SECTION code_user
        org     $0100
        PUBLIC  asm_pc88_disk_regs
        EXTERN  _plat_file_save, _plat_file_load
        defc    DISK = $4000
start:  ld      sp,$FF00
        ld      hl,DISK
        ld      de,DISK + 1
        ld      bc,16 * 6 * 256 - 1
        ld      (hl),$E5
        ldir                            ; a blank disk
        ld      ix,calls
next:   ld      a,(ix+0)
        cp      255
        jr      z,done
        ld      l,(ix+1)
        ld      h,(ix+2)
        push    hl                      ; name
        ld      l,(ix+3)
        ld      h,(ix+4)
        push    hl                      ; a
        ld      l,(ix+5)
        ld      h,(ix+6)
        push    hl                      ; alen
        ld      l,(ix+7)
        ld      h,(ix+8)
        push    hl                      ; b
        ld      l,(ix+9)
        ld      h,(ix+10)
        push    hl                      ; blen
        ld      a,(ix+0)
        or      a
        jr      nz,doload
        call    _plat_file_save
        jr      called
doload: call    _plat_file_load
called: ld      a,l
        ld      (tmp),a
        ld      hl,10
        add     hl,sp
        ld      sp,hl
        ld      c,(ix+11)
        ld      b,0
        ld      hl,results
        add     hl,bc
        ld      a,(tmp)
        ld      (hl),a
        ld      de,12
        add     ix,de
        jr      next
done:   halt
tmp:    defb    0
results: defs   32
st_mode: defb   0
st_buf: defw    0

; the disk: a = mode, e = drive, d = track, c = sector, b = count, hl = buf; hl = 0, or 1 for a track that is not there
asm_pc88_disk_regs:
        ld      (st_mode),a
        ld      (st_buf),hl
dr_next:
        ld      a,d
        cp      16
        jr      c,dr_bad
        cp      22
        jr      nc,dr_bad
        ld      a,c
        or      a
        jr      z,dr_bad
        cp      17
        jr      nc,dr_bad
        push    bc
        push    de
        ld      a,d
        sub     16
        add     a,a
        add     a,a
        add     a,a
        add     a,a
        add     a,c
        dec     a
        add     a,DISK / 256
        ld      d,a
        ld      e,0                     ; de = the sector on the disk
        ld      hl,(st_buf)
        ld      a,(st_mode)
        or      a
        jr      nz,dr_copy              ; a write: from the buffer to the disk
        ex      de,hl                   ; a read: the other way
dr_copy:
        ld      bc,256
        ldir
        ld      hl,(st_buf)
        inc     h
        ld      (st_buf),hl
        pop     de
        pop     bc
        inc     c
        ld      a,c
        cp      17
        jr      c,dr_more
        ld      c,1
        inc     d
dr_more:
        djnz    dr_next
        ld      hl,0
        ret
dr_bad:
        ld      hl,1
        ret
calls:
        CALLS
'''

EDITOR = '''        SECTION code_user
        org     $0100
        defc    LOG = $3000
        PUBLIC  _plat_key, _plat_idle, _plat_put
        EXTERN  _plat_text_input
start:  ld      sp,$FF00
        ld      hl,keys
        ld      (kp),hl
        ld      hl,LOG
        ld      (lp),hl
        ld      ix,runs
next:   ld      a,(ix+0)
        cp      255
        jr      z,done
        ld      (cur),a
        ld      l,(ix+1)
        ld      h,0
        push    hl                      ; col
        ld      l,(ix+2)
        push    hl                      ; row
        ld      l,(ix+3)
        ld      h,(ix+4)
        push    hl                      ; buf
        ld      l,(ix+5)
        ld      h,0
        push    hl                      ; max
        ld      l,(ix+6)
        push    hl                      ; spaces
        call    _plat_text_input
        ld      a,l
        ld      (tmp),a
        ld      hl,10
        add     hl,sp
        ld      sp,hl
        ld      a,(cur)
        ld      c,a
        ld      b,0
        ld      hl,results
        add     hl,bc
        ld      a,(tmp)
        ld      (hl),a
        ld      de,7
        add     ix,de
        jr      next
done:   halt
tmp:    defb    0
cur:    defb    0
idles:  defw    0
kp:     defw    0
lp:     defw    0
results: defs   32

_plat_key:
        ld      hl,(kp)
        ld      a,(hl)
        inc     hl
        ld      (kp),hl
        ld      l,a
        ld      h,0
        ret
_plat_idle:
        ld      hl,(idles)
        inc     hl
        ld      (idles),hl
        ret
_plat_put:                              ; (col, row, ch): logged with the run's number
        ld      hl,2
        add     hl,sp
        ld      c,(hl)                  ; ch
        inc     hl
        inc     hl
        ld      b,(hl)                  ; row
        inc     hl
        inc     hl
        ld      d,(hl)                  ; col
        ld      hl,(lp)
        ld      a,(cur)
        ld      (hl),a
        inc     hl
        ld      (hl),d
        inc     hl
        ld      (hl),b
        inc     hl
        ld      (hl),c
        inc     hl
        ld      (lp),hl
        ret
runs:
        RUNS
keys:
        KEYS
'''


def assemble(src, name, extra, tmp):
    open(os.path.join(tmp, name + '.asm'), 'w').write(src)
    out = subprocess.run([Z80ASM, '-b', '-m', '-I' + ROOT, f'-o{name}.bin', name + '.asm'] + extra, cwd=tmp, capture_output=True, text=True)
    if out.returncode or out.stderr.strip():
        print(out.stdout + out.stderr)
        return None
    syms = {}
    for line in open(os.path.join(tmp, name + '.map')):
        m = re.match(r'(\S+)\s+= \$([0-9A-F]+) ;', line)
        if m:
            syms[m.group(1)] = int(m.group(2), 16)
    img = bytearray(65536)
    for sec in ('code_user',):
        p = os.path.join(tmp, f'{name}_{sec}.bin')
        if os.path.exists(p):
            b = open(p, 'rb').read()
            img[syms[f'__{sec}_head']:syms[f'__{sec}_head'] + len(b)] = b
    first = os.path.join(tmp, name + '.bin')
    if os.path.exists(first) and os.path.getsize(first):
        b = open(first, 'rb').read()
        img[0x100:0x100 + len(b)] = b
    return syms, img


def run_image(img, syms, tmp):
    open(os.path.join(tmp, 'img.bin'), 'wb').write(img)
    subprocess.run([TICKS, '-pc', '100', '-end', f'{syms["done"]:x}', '-counter', '2000000000', '-output', 'mem.out', 'img.bin'],
                   cwd=tmp, capture_output=True)
    return open(os.path.join(tmp, 'mem.out'), 'rb').read()


def pattern(seed, n):
    rng = random.Random(seed)
    return bytes(rng.randrange(256) for _ in range(n))


def key(name):
    out, done = '', False
    for i in range(12):
        ch = name[i] if i < len(name) else ' '
        if done:
            ch = ' '
        elif ch == ' ':
            done = True
        out += ch
    return out.encode()


def cstr(s, size=32):
    return s.encode() + bytes(size - len(s))


def files_run(calls, expect, check, title):
    """calls: (op, name, hdr_at, hdr_len, map_at, map_len, pattern spec); each is a save (0) or a load (1)."""
    with tempfile.TemporaryDirectory() as tmp:
        rows = ''
        data = {}
        for i, (op, name, hdr, alen, mapat, blen) in enumerate(calls):
            at = ONES + 0x20 * i
            data[at] = cstr(name)
            rows += f'        defb {op}\n        defw {at}, {hdr}, {alen}, {mapat}, {blen}\n        defb {i}\n'
        rows += '        defb 255\n'
        src = FILES.replace('        CALLS\n', rows)
        res = assemble(src, 'f', [os.path.join(ROOT, 'target/pc88/plat_pc88_files.asm')], tmp)
        if not res:
            print('FAIL  ' + title + ': does not assemble')
            return False
        syms, img = res
        assert syms['f_sector'] + 256 < 0x2C00, 'the routines\' variables overlap the test data'
        for at, d in data.items():
            img[at:at + len(d)] = d
        for at, d in check['init'].items():
            img[at:at + len(d)] = d
        mem = run_image(img, syms, tmp)
        got = [mem[syms['results'] + i] for i in range(len(calls))]
        ok = got == expect
        msgs = []
        if not ok:
            msgs.append(f'results {got}, wanted {expect}')
        for what, at, want in check['mem']:
            if mem[at:at + len(want)] != want:
                ok = False
                msgs.append(f'{what} is not as wanted')
        sector = lambda track, sec: mem[DISK + ((track - 16) * 16 + sec - 1) * 256:DISK + ((track - 16) * 16 + sec) * 256]
        for what, track, sec, want in check.get('disk', []):
            if sector(track, sec) != want:
                ok = False
                msgs.append(f'{what} (track {track}, sector {sec}) is not as wanted')
        print(('PASS' if ok else 'FAIL') + '  ' + title + ('' if ok else '  ' + '; '.join(msgs)))
        return ok


def files_tests():
    ok = True
    hdr1, hdr2, hdr3 = key('ALPHA') + pattern(1, 19), key('BETA') + pattern(2, 19), key('ALPHA') + pattern(3, 19)
    map1, map2, map3 = pattern(4, 9216), pattern(5, 1000), pattern(6, 600)
    H = lambda n: 0x2C00 + 0x100 * n                 # headers and their copies (to $33FC: below the names at $3800 and the disk)
    # a save, a second city, loads of both, a name that is not there, a full disk, a name saved again (the same slot), loads
    calls = [(0, 'ALPHA', H(0), 31, R_SRC1, 9216),
             (0, 'BETA', H(1), 31, R_SRC2, 1000),
             (1, 'ALPHA', H(2), 31, R_OUT1, 9216),
             (1, 'BETA', H(3), 31, R_OUT2, 1000),
             (1, 'NOSUCH', H(4), 31, R_OUT3, 600),
             (0, 'GAMMA', H(0), 31, R_SRC2, 1000),
             (0, 'ALPHA', H(5), 31, R_SRC2, 600),
             (1, 'ALPHA', H(6), 31, R_OUT3, 600),
             (1, 'BETA', H(7), 31, R_OUT4, 1000)]
    init = {H(0): hdr1, H(1): hdr2, H(5): hdr3, R_SRC1: map1, R_SRC2: map2}
    # (ALPHA is saved again from the first 600 bytes of map2's area, with the header hdr3)
    check = {'init': init,
             'mem': [('the first header loaded', H(2), hdr1), ('the first map loaded', R_OUT1, map1),
                     ('the second header loaded', H(3), hdr2), ('the second map loaded', R_OUT2, map2),
                     ('the header of the name saved again', H(6), hdr3), ('its map', R_OUT3, map2[:600]),
                     ('the second city after it', H(7), hdr2), ('and its map', R_OUT4, map2)],
             'disk': [('the header of slot 0 (ALPHA, the second time)', 16, 1, hdr3 + bytes(223) + b'SC'),
                      ('the header of slot 1 (BETA)', 19, 1, hdr2 + bytes(223) + b'SC'),
                      ('the first sector of slot 0\'s map', 16, 2, map2[0:256]),
                      ('the part sector after it (the second save is 600 bytes)', 16, 4, map2[512:600] + bytes(256 - 88)),
                      ('the last sector of slot 1\'s map (a part sector)', 19, 5, map2[768:1000] + bytes(256 - 232))]}
    # (slot 0's data came back from the second save: its map is map2's first 600 bytes at sectors 2 and 3, the part sector at 4)
    ok &= files_run(calls, [0, 0, 0, 0, 1, 1, 0, 0, 0], check, 'save two cities, load them, a missing name, a full disk, a name saved again')

    # the name is 12 characters and blank after the first space
    calls = [(0, 'A B', H(0), 31, R_SRC2, 1000), (1, 'A Z', H(1), 31, R_OUT2, 1000), (1, 'AB', H(2), 31, R_OUT3, 1000),
             (0, 'A VERY LONG FILENAME', H(0), 31, R_SRC2, 1000), (1, 'A VERY LONG', H(3), 31, R_OUT4, 1000)]
    hdrA = key('A B') + pattern(11, 19)
    check = {'init': {H(0): hdrA, R_SRC2: map2},
             'mem': [('the header loaded by the name with the same first word', H(1), hdrA), ('its map', R_OUT2, map2)]}
    ok &= files_run(calls, [0, 0, 1, 0, 0], check, 'a name is blank after its first space (and A, A B and A Z are one name)')

    # what does not fit: a header of 253 bytes, a map of 46 sectors; what does: 252 and 45 sectors and a part
    calls = [(0, 'X', H(0), 253, R_SRC2, 1000), (0, 'X', H(0), 31, R_SRC1, 46 * 256), (0, 'X', H(0), 252, R_SRC1, 45 * 256 + 200),
             (1, 'X', H(1), 252, R_OUT1, 45 * 256 + 200), (1, 'X', H(2), 253, R_OUT3, 100)]
    big = key('X') + pattern(7, 240)
    check = {'init': {H(0): big, R_SRC1: pattern(8, 9216) + pattern(9, 3000)},
             'mem': [('the longest header', H(1), big)]}
    ok &= files_run(calls, [1, 1, 0, 0, 1], check, 'the sizes that do not fit and the largest that does')
    return ok


def editor_tests():
    BUF = lambda n: ONES + 0x40 * n
    R = lambda *k: bytes(k)
    # run: (col, row, max, spaces, keys, return, buf, idles, puts as (col, row, char))
    runs = [
        (5, 3, 10, 0, b'AB\r', 1, 'AB', 0, [(5, 3, 'A'), (6, 3, 'B')]),
        (5, 3, 10, 0, R(0, 0, 65, 0, 13), 1, 'A', 3, [(5, 3, 'A')]),
        (5, 3, 10, 0, b'AB\x08C\r', 1, 'AC', 0, [(5, 3, 'A'), (6, 3, 'B'), (6, 3, ' '), (6, 3, 'C')]),
        (5, 3, 10, 0, b'\x7fX\r', 1, 'X', 0, [(5, 3, 'X')]),
        (5, 3, 3, 0, b'ABCDE\r', 1, 'ABC', 0, [(5, 3, 'A'), (6, 3, 'B'), (7, 3, 'C')]),
        (5, 3, 10, 0, R(32, 1, 33, 126, 127, 128, 200, 13), 1, '!', 0, [(5, 3, '!'), (6, 3, '~'), (6, 3, ' ')]),
        (5, 3, 10, 1, b'A B\r', 1, 'A B', 0, [(5, 3, 'A'), (6, 3, ' '), (7, 3, 'B')]),
        (5, 3, 10, 0, b'A\x1b', 0, 'A', 0, [(5, 3, 'A')]),
        (5, 3, 10, 0, b'\r', 0, '', 0, []),
        (5, 3, 10, 0, b'\x08\x08Q\r', 1, 'Q', 0, [(5, 3, 'Q')]),
        (5, 3, 2, 0, b'AB\x08\x08\x08Z\r', 1, 'Z', 0, [(5, 3, 'A'), (6, 3, 'B'), (6, 3, ' '), (5, 3, ' '), (5, 3, 'Z')]),
    ]
    with tempfile.TemporaryDirectory() as tmp:
        rrows = ''
        keys = b''
        for i, (col, row, mx, sp, k, *_rest) in enumerate(runs):
            rrows += f'        defb {i + 1}, {col}, {row}\n        defw {BUF(i)}\n        defb {mx}, {sp}\n'
            keys += k
        rrows += '        defb 255\n'
        src = EDITOR.replace('        RUNS\n', rrows).replace('        KEYS\n', '        defb ' + ','.join(str(b) for b in keys) + '\n')
        res = assemble(src, 'e', [os.path.join(ROOT, 'target/common/line_editor.asm')], tmp)
        if not res:
            print('FAIL  the editor test does not assemble')
            return False
        syms, img = res
        assert syms['le_n'] < 0x3000, 'the editor\'s variables overlap the log'
        for i in range(len(runs)):
            img[BUF(i):BUF(i) + 32] = b'\xEE' * 32            # (so that a buffer left unterminated shows)
        mem = run_image(img, syms, tmp)
        log = mem[0x3000:0x3000 + 4 * 64]
        entries = [(log[j], log[j + 1], log[j + 2], chr(log[j + 3])) for j in range(0, len(log), 4) if log[j]]
        idles = mem[syms['idles']] | mem[syms['idles'] + 1] << 8
        ok = True
        total_idles = sum(r[7] for r in runs)
        for i, (col, row, mx, sp, k, ret, buf, idle, puts) in enumerate(runs):
            got_ret = mem[syms['results'] + i + 1]
            got_buf = bytes(mem[BUF(i):BUF(i) + 32]).split(b'\0')[0].decode('latin1')
            got_puts = [(c, r, ch) for n, c, r, ch in entries if n == i + 1]
            bad = []
            if got_ret != ret:
                bad.append(f'returned {got_ret}')
            if got_buf != buf:
                bad.append(f'buf {got_buf!r}')
            if got_puts != puts:
                bad.append(f'drew {got_puts}')
            if bad:
                ok = False
                print(f'FAIL  editor run {i + 1} (keys {k!r}, max {mx}, spaces {sp}): ' + ', '.join(bad))
        if idles != total_idles:
            ok = False
            print(f'FAIL  the editor waited {idles} times for a key (plat_idle), not {total_idles}')
        print(('PASS' if ok else 'FAIL') + f'  the file name editor: {len(runs)} scripts of keys (typing, backspace and delete, the length limit, spaces '
              'allowed or not, ENTER and ESC, idle while there is no key) return, fill the buffer and draw as the C editor did')
        return ok


def main():
    ok = files_tests()
    ok &= editor_tests()
    return 0 if ok else 1


if __name__ == '__main__':
    sys.exit(main())
