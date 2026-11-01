#!/usr/bin/env python3
"""Host test of z88dk's SPC-1000 in_Inkey (libsrc/target/spc1000/input/in_Inkey.asm) under z88dk-ticks: Lua models port reads from the keyboard matrix at $8000 to $8009 (a clear bit is a key down), and each case is run.
usage: test/spc1000/inkey.py"""
import os, re, subprocess, sys, tempfile
Z88DK_ROOT = os.path.abspath(os.path.join(os.environ.get('ZCCCFG', os.path.expanduser('~/z88dk/lib/config')), '../..'))
Z = os.path.join(Z88DK_ROOT, 'libsrc/target/spc1000/input')

LUA = '''local rows = {%ROWS%}
function io_in(port, cycles)
    local row = port & 0xff
    if row < #rows then return rows[row + 1] end
    return -1
end
'''
TICKS = 'z88dk-ticks'

def main():
    tbl = open(os.path.join(Z, 'in_keytranstbl.asm')).read()
    src = open(os.path.join(Z, 'in_Inkey.asm')).read()
    assert re.search(r'in\s+a,\s*\(c\)', src)
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
        rows = [0xFF] * 10
        for r, b in pressed:
            rows[r] &= ~(1 << b) & 0xFF
        if shift: rows[0] &= ~0x02 & 0xFF
        if ctrl: rows[0] &= ~0x04 & 0xFF
        open(os.path.join(work, 'i.bin'), 'wb').write(mem)
        open(os.path.join(work, 'device.lua'), 'w').write(LUA.replace('%ROWS%', ','.join(map(str, rows))))
        run = subprocess.run([TICKS, '-pc', '2000', '-end', format(sym('done'), 'x'), '-lua', 'device.lua', '-output', os.path.join(work, 'o.bin'), os.path.join(work, 'i.bin')], cwd=work, capture_output=True, text=True)
        if run.returncode:
            raise RuntimeError(run.stdout + run.stderr)
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
