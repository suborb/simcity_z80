#!/usr/bin/env python3
"""Host test of z88dk's SPC-1000 in_Inkey (libsrc/target/spc1000/input/in_Inkey.asm) under z88dk-ticks: the routine is assembled with its port reads
(IN A,(C) with B = $80) turned into memory reads of a fake matrix at $8000 to $8009 (a clear bit is a key down), and each case is run.
usage: test/spc1000/inkey.py"""
import os, re, subprocess, sys, tempfile
Z = os.path.expanduser('~/z88dk/libsrc/target/spc1000/input')

def main():
    tbl = open(os.path.join(Z, 'in_keytranstbl.asm')).read()
    src = open(os.path.join(Z, 'in_Inkey.asm')).read()
    assert re.search(r'in\s+a,\s*\(c\)', src)
    src = re.sub(r'in\s+a,\s*\(c\)', 'ld a,(bc)', src)
    work = tempfile.mkdtemp()
    # the codes of the unshifted table, row r, bit b
    codes = {}
    rows = [l for l in tbl.split('\n') if l.strip().startswith('defb')]
    def parse(l):
        out = []
        for tok in re.findall(r"'(?:\\.|[^'\\])'|\d+", l.split('defb')[1])[:8]:     # (the comment after them has quotes too)
            if tok.startswith("'"):
                ch = tok[1:-1]
                out.append(ord(ch[1]) if ch.startswith('\\') else ord(ch))
            else:
                out.append(int(tok))
        return out
    tables = [[parse(l) for l in rows[i * 10:(i + 1) * 10]] for i in range(3)]
    open(os.path.join(work, 't.asm'), 'w').write('''        org $2000
        call in_Inkey
        ld (result),hl
        ld a,0
        jr nc,got
        inc a
got:    ld (carry),a
done:   jr done
result: defw 0
carry:  defb 0
''' + src + '\n' + tbl)
    r = subprocess.run(['z88dk-z80asm', '-b', '-m', os.path.join(work, 't.asm')], capture_output=True, text=True)
    if r.returncode:
        sys.exit(r.stdout + r.stderr)
    code = open(os.path.join(work, 't.bin'), 'rb').read()
    m = open(os.path.join(work, 't.map')).read()
    sym = lambda n: int(re.search(r'^%s\s*=\s*\$([0-9A-Fa-f]+)' % n, m, re.M).group(1), 16)

    def run(pressed, shift=False, ctrl=False):
        """pressed: list of (row, bit) down in rows 1-9; returns (hl, carry)"""
        mem = bytearray(65536)
        mem[0x2000:0x2000 + len(code)] = code
        for i in range(10):
            mem[0x8000 + i] = 0xFF
        for r, b in pressed:
            mem[0x8000 + r] &= ~(1 << b) & 0xFF
        if shift: mem[0x8000] &= ~0x02 & 0xFF
        if ctrl: mem[0x8000] &= ~0x04 & 0xFF
        open(os.path.join(work, 'i.bin'), 'wb').write(mem)
        subprocess.run(['z88dk-ticks', '-pc', '2000', '-end', format(sym('done'), 'x'), '-output', os.path.join(work, 'o.bin'), os.path.join(work, 'i.bin')], capture_output=True)
        o = open(os.path.join(work, 'o.bin'), 'rb').read()
        return o[sym('result')] | o[sym('result') + 1] << 8, o[sym('carry')]

    bad = 0
    def check(name, got, want):
        nonlocal bad
        ok = got == want
        bad += not ok
        print('%-34s %s %s' % (name, 'ok  ' if ok else 'FAIL', got if ok else '%s (wanted %s)' % (got, want)))

    check('no key', run([]), (0, 1))
    # every key of the three tables, alone
    for t, kw in ((0, {}), (1, {'shift': True}), (2, {'ctrl': True})):
        for r in range(1, 10):
            for k in range(8):
                want = tables[t][r][k]
                # the bits that are not keys are masked: the row's mask is in the routine, so only check keys the table has
                res = run([(r, 7 - k)], **kw)
                exp = (want, 0) if want != 255 else (0, 1)
                if res != exp and not (want == 255):
                    check('table %d row %d bit %d' % (t, r, 7 - k), res, exp)
    check('shift + 1', run([(1, 7)], shift=True), (ord('!'), 0))
    check('1', run([(1, 7)]), (ord('1'), 0))
    check('two keys, two rows (1 and q)', run([(1, 7), (3, 7)]), (0, 1))
    check('two keys, one row (1 and q)', run([(1, 7), (1, 6)]), (0, 1))
    check('a modifier alone', run([], shift=True), (0, 1))
    check('unused bit (row 5 bit 0)', run([(5, 0)]), (0, 1))
    check('unused bit and a key', run([(5, 0), (1, 7)]), (ord('1'), 0))
    print('FAILED' if bad else 'all passed')
    sys.exit(1 if bad else 0)

main()
