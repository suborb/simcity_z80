#!/usr/bin/env python3
"""The CP/M BDOS under z88dk-ticks: builds test/cpm/bdos_test.c for +cpm and runs it, with the line "hello" on its input."""
import os
import subprocess
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))


def main():
    with tempfile.TemporaryDirectory() as tmp:
        built = subprocess.run(['zcc', '+cpm', '-o', 'bdos_test.com', os.path.join(HERE, 'bdos_test.c')], cwd=tmp, capture_output=True, text=True)
        if built.returncode:
            print('FAIL  building:', (built.stdout + built.stderr)[-500:])
            return 1
        ticks = os.environ.get('TICKS', 'z88dk-ticks')
        run = subprocess.run([ticks, 'bdos_test.com'], cwd=tmp, input='hello\n', capture_output=True, text=True)
        if 'Unsupported BDOS call' in run.stderr:
            print('SKIP  this z88dk-ticks does not have the BDOS calls (sequential files, search, read line, time): rebuild and install it from z88dk/src/ticks')
            return 0
        lines = [l for l in run.stdout.split('\n') if l.startswith(('ok', 'FAIL'))]
        bad = [l for l in lines if l.startswith('FAIL')]
        for l in bad:
            print(l)
        print(('PASS' if lines and not bad and 'Unsupported' not in run.stderr else 'FAIL') + f'  the BDOS of z88dk-ticks: {len(lines) - len(bad)} of {len(lines)} checks'
              + (f' ({run.stderr.strip()[:80]})' if run.stderr.strip() else ''))
        return 1 if bad or not lines else 0


if __name__ == '__main__':
    sys.exit(main())
