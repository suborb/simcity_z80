#!/usr/bin/env python3
"""The loader of the FP-1100 boot disc (z88dk's BOOTSTRAP2, build/fp1100/simcity_BOOTSTRAP2.bin, which `make fp1100` builds with the game) under z88dk-ticks, loading the program from the real disc image (build/fp1100/simcity.d88) through the polled
driver against the uPD765A model: the program must be at $0000 afterwards, and the loader must end by jumping to 0.  Needs `make fp1100` first."""
import os, subprocess, sys, tempfile

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
HERE = os.path.dirname(os.path.abspath(__file__))
B = os.path.join(ROOT, 'build', 'fp1100')


def main():
    image = open(os.path.join(B, 'simcity.bin'), 'rb').read()
    with tempfile.TemporaryDirectory() as tmp:
        s2 = open(os.path.join(B, 'simcity_BOOTSTRAP2.bin'), 'rb').read()
        mem = bytearray(0xF800) + s2
        open(os.path.join(tmp, 'img.bin'), 'wb').write(mem)
        env = dict(os.environ, FDC_IMAGE=os.path.join(B, 'simcity.d88'))
        out = os.path.join(tmp, 'mem.out')
        r = subprocess.run(['z88dk-ticks', '-lua', os.path.join(HERE, 'fdc_model.lua'), '-pc', 'F800', '-end', '0', '-counter', '400000000', '-output', out,
                            os.path.join(tmp, 'img.bin')], capture_output=True, text=True, cwd=tmp, env=env)
        if not os.path.exists(out):
            sys.exit('no memory dump:\n' + r.stdout + r.stderr)
        m = open(out, 'rb').read()
        print(r.stdout.strip().splitlines()[-1] if r.stdout.strip() else '')
        bad = 0
        if m[:len(image)] != image:
            bad += 1
            first = next(i for i in range(len(image)) if m[i] != image[i])
            print('FAIL program differs, first at $%04X' % first)
        else:
            print('ok   the program (%d bytes) is at $0000' % len(image))
        return bad


if __name__ == '__main__':
    sys.exit(1 if main() else 0)
