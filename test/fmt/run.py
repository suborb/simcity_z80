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
    r = subprocess.run(ZCC.split() + ['+test', '-m', '-Iui', '-Ca-Iengine', '-Ca-I.', test_main(), 'ui/textfmt.c', 'ui/numfmt.asm',
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
    print(('PASS' if not bad else 'FAIL') + f'  fmt_dec prints {N} values from 0 to 16777215 as plain decimal' + (f'  wrong: {bad[:4]}' if bad else ''))
    sys.exit(1 if bad else 0)


def test_main():
    return 'test/fmt/main.c'


if __name__ == '__main__':
    main()
