#!/usr/bin/env python3
"""fmt_dec (ui/textfmt.c, with the Z80 routine in numfmt.asm) prints every kind of number right:
no leading zeros, a lone 0, and all the way to the largest 24 bit value.

  usage: test/fmt/run.py
"""
import os
import re
import subprocess
import sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
OUT = os.path.join(ROOT, 'build', 'fmt')
ZCC = os.environ.get('ZCC', 'zcc -compiler=80cc -fframe-pointer')
N = 24


def main():
    os.makedirs(OUT, exist_ok=True)
    env = os.environ
    binary = os.path.join(OUT, 'fmt.bin')
    r = subprocess.run(ZCC.split() + ['+test', '-m', '-Iui', '-Iplatform/test_ui', '-Ca-Iengine', '-Ca-I.', test_main(), 'ui/textfmt.c', 'ui/numfmt.asm',
                                      '-o', binary], cwd=ROOT, env=env, capture_output=True, text=True)
    if r.returncode:
        print(r.stdout, r.stderr)
        sys.exit('build failed')
    syms = {}
    for line in open(os.path.join(OUT, 'fmt.map')):
        m = re.match(r'(\S+)\s*=\s*\$([0-9A-Fa-f]+)', line)
        if m:
            syms[m.group(1)] = int(m.group(2), 16)
    dump = os.path.join(OUT, 'fmt.out')
    if os.path.exists(dump):
        os.remove(dump)
    subprocess.run(['z88dk-ticks', binary, '-end', f'{syms["__Exit"]:x}', '-counter', '200000000',
                    '-output', dump], capture_output=True)
    mem = open(dump, 'rb').read()
    values = [int.from_bytes(mem[syms['_fmt_in'] + 4 * i:syms['_fmt_in'] + 4 * i + 4], 'little') for i in range(N)]
    bad = []
    for i, v in enumerate(values):
        got = mem[syms['_fmt_out'] + 10 * i:syms['_fmt_out'] + 10 * i + 10].split(b'\0')[0].decode()
        n = mem[syms['_fmt_len'] + i]
        if got != str(v) or n != len(str(v)):
            bad.append((v, got, n))
    # the table drawing in assembler: every kind of field, against a rendering of the same table made here
    r = subprocess.run(ZCC.split() + ['+test', '-m', '-DHAVE_FIELDS', '-Iui', '-Iplatform/test_ui', '-Ca-Iengine', '-Ca-I.', 'test/fmt/fields.c',
                                      'ui/textfmt.c', 'ui/numfmt.asm', 'ui/fmtfields.asm', '-o', os.path.join(OUT, 'fields.bin')],
                       cwd=ROOT, env=env, capture_output=True, text=True)
    if r.returncode:
        print(r.stdout, r.stderr)
        sys.exit('build failed')
    fsyms = {}
    for line in open(os.path.join(OUT, 'fields.map')):
        m = re.match(r'(\S+)\s*=\s*\$([0-9A-Fa-f]+)', line)
        if m:
            fsyms[m.group(1)] = int(m.group(2), 16)
    dump = os.path.join(OUT, 'fields.out')
    if os.path.exists(dump):
        os.remove(dump)
    subprocess.run(['z88dk-ticks', os.path.join(OUT, 'fields.bin'), '-end', f'{fsyms["__Exit"]:x}', '-counter', '200000000', '-output', dump],
                   capture_output=True)
    mem = open(dump, 'rb').read()
    got = [mem[fsyms['_rows'] + 41 * i:fsyms['_rows'] + 41 * i + 41].split(b'\0')[0].decode() for i in range(5)]

    def render(fields):
        rows = {}
        for row, col, kind, unit, value in fields:
            line = rows.setdefault(row, [' '] * 40)
            if kind == 'text':
                for i, ch in enumerate(value):
                    line[col + i] = ch
            else:
                n = abs(value)
                digits = str(n)
                if kind == 'k':
                    digits += '000' if n else ''
                if kind in ('l', 'k'):
                    for i, ch in enumerate(digits):
                        line[col + i] = ch
                else:
                    start = col - len(digits)
                    for i, ch in enumerate(digits):
                        line[start + i] = ch
                    if value < 0:
                        line[start - 1] = '-'
                    if unit:
                        line[col] = unit
        return [''.join(rows[r]).rstrip() if r in rows else '' for r in range(5)]

    want = render([
        (0, 0, 'text', '', 'AB'), (0, 8, 'r', '%', 255), (0, 12, 'r', '', 0),
        (1, 6, 'r', '', 65535), (1, 10, 'r', '%', 7), (1, 25, 'r', '', 16777215),
        (2, 10, 'r', '', -123), (2, 25, 'r', '$', -8388608), (2, 30, 'r', '', 12345),
        (3, 3, 'l', '', 12345), (3, 10, 'l', '', 0), (3, 20, 'k', '', 4000), (3, 30, 'k', '', 0),
        (4, 0, 'text', '', 'HELLO'), (4, 10, 'text', '', 'THROUGH'), (4, 20, 'r', '', 0)])
    bad_rows = [(i, g.rstrip(), w) for i, (g, w) in enumerate(zip(got, want)) if g.rstrip() != w]
    print(('PASS' if not bad_rows else 'FAIL') + '  the table drawing (fmtfields.asm): every kind of field, signs, units, zero, 8 digits, left aligned and thousands'
          + (f'  wrong: {bad_rows[:3]}' if bad_rows else ''))
    bad = list(bad) + list(bad_rows)
    print(('PASS' if not bad else 'FAIL') + f'  fmt_dec prints {N} values from 0 to 16777215 as plain decimal' + (f'  wrong: {bad[:4]}' if bad else ''))
    sys.exit(1 if bad else 0)


def test_main():
    return 'test/fmt/main.c'


if __name__ == '__main__':
    main()
