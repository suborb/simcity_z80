#!/usr/bin/env python3
"""How much stack does the ZX Spectrum build use?

Builds the real game core and engine for +zx with the Spectrum's memory map (same -zorg,
stack at the top of RAM, sections) but the headless platform, fills the free memory below
the stack with a pattern, plays a scripted game under z88dk-ticks (a tool of every kind,
simulation running fast, and each disaster forced in turn) and looks for the deepest byte
the stack reached.  The simulation task's own 256 byte stack (zeroed by the crt, so only
the deepest non-zero byte can be seen) is measured the same way.

  usage: test/stack/run.py
"""
import os
import re
import subprocess
import sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
Z88DK = os.environ.get('Z88DK', os.path.expanduser('~/z88dk'))
OUT = os.path.join(ROOT, 'build', 'stack')
ZORG, SP_TOP = 24000, 0xFF57
SCRIPT_LEN = 512
PATTERN = 0xA5
MARGIN = 256                    # free bytes we want to keep beyond what the stack used


def build():
    os.makedirs(OUT, exist_ok=True)
    env = dict(os.environ, ZCCCFG=os.path.join(Z88DK, 'lib', 'config'),
               PATH=os.path.join(Z88DK, 'bin') + os.pathsep + os.environ['PATH'])
    cmd = ['zcc', '+zx', f'-zorg={ZORG}', '-pragma-include:platform/console/zpragma_zx.inc', '-Ca-DPORTABLE', '-Ca-Iengine', '-Ca-I.', '-Iui',
           '-Cc-standard-escape-chars', '-m', '-DHAVE_TILES', '-DMAX_VIEW_W=32', '-DMAX_VIEW_H=16',
           'ui/main.c', 'ui/game.c', 'engine/engine_c.asm', 'platform/common/hooks.asm',
           'platform/test_ui/plat_test.c',
           '-o', os.path.join(OUT, 'stack')]
    r = subprocess.run(cmd, cwd=ROOT, env=env, capture_output=True, text=True)
    if r.returncode:
        print(r.stdout, r.stderr)
        sys.exit('build failed')
    syms = {}
    for line in open(os.path.join(OUT, 'stack.map')):
        m = re.match(r'(\S+)\s*=\s*\$([0-9A-Fa-f]+)', line)
        if m:
            syms[m.group(1)] = int(m.group(2), 16)
    return open(os.path.join(OUT, 'stack'), 'rb').read(), syms


def script():
    """Level 2, fast, then each tool used at a few places, then idle frames."""
    k = [ord('2'), ord('+')]
    for tool in range(14):
        k += [ord(str(tool)) if tool < 10 else ord('.')] * (1 if tool < 10 else tool - 9)
        k += [ord('p')] * 3 + [ord('a')] * 2 + [ord(' ')] + [ord('P')] + [ord('A')] + [ord(' ')]
        k += [ord(',')] * (0 if tool < 10 else tool - 9)
    return bytes(k)


def run(binary, syms, disaster):
    image = bytearray(ZORG) + bytearray(binary)
    image += bytearray(65536 - len(image))
    end = syms['__BSS_END_tail']
    image[end:SP_TOP] = bytes([PATTERN]) * (SP_TOP - end)
    keys = script() + bytes(SCRIPT_LEN - len(script()) - 1) + b'\xff'
    a = syms['_test_script']
    image[a:a + SCRIPT_LEN] = keys
    image[syms['V_disaster_option']] = disaster
    path = os.path.join(OUT, 'stack.img')
    open(path, 'wb').write(image)
    dump = os.path.join(OUT, 'stack.out')
    if os.path.exists(dump):
        os.remove(dump)
    subprocess.run([os.path.join(Z88DK, 'bin', 'z88dk-ticks'), '-pc', f'{ZORG:x}', '-end', f'{syms["__Exit"]:x}',
                    '-counter', '4000000000', '-output', dump, path], capture_output=True)
    mem = open(dump, 'rb').read()
    low = next((i for i in range(end, SP_TOP) if mem[i] != PATTERN), SP_TOP)
    sim_lo = syms['sim_stack']
    sim_top = sim_lo + 256
    sim_used = next((sim_top - i for i in range(sim_lo, sim_top) if mem[i]), 0)
    return SP_TOP - low, sim_used, mem[syms['_test_done']]


def real_free():
    """Free bytes below the stack in the real game (make zx), from its link map."""
    subprocess.run(['make', '-s', '-C', ROOT, 'zx'], check=True, capture_output=True)
    for line in open(os.path.join(ROOT, 'build', 'zx', 'simcity.map')):
        m = re.match(r'__BSS_END_tail\s*=\s*\$([0-9A-Fa-f]+)', line)
        if m:
            return SP_TOP - int(m.group(1), 16), int(m.group(1), 16)


def main():
    binary, syms = build()
    # this headless build carries its own screen and script buffers, so only its stack
    # figures are meaningful; the free space is that of the real Spectrum build
    free, end = real_free()
    print(f'real build: image ends at {end:#06x}, stack top {SP_TOP:#06x}: {free} bytes free for the stack')
    worst = worst_sim = 0
    for d, name in enumerate(['no forced disaster', 'fire', 'flood', 'earthquake', 'air crash', 'tornado', 'meltdown']):
        used, sim, done = run(binary, syms, d)
        worst, worst_sim = max(worst, used), max(worst_sim, sim)
        print(f'  {name:20} main stack {used:4} bytes, simulation stack {sim:3} of 256'
              + ('' if done == 1 else '   (game did not exit cleanly)'))
    left = free - worst
    print(f'deepest main stack {worst} bytes, simulation stack {worst_sim} of 256; {left} of the free bytes unused')
    print('(the console and tile drawing add a little more than the headless platform shows)')
    ok = left >= MARGIN and worst_sim <= 256 - 32
    print(('PASS' if ok else 'FAIL') + f'  stack fits with a margin of {MARGIN} bytes (and the simulation stack with 32 spare)')
    sys.exit(0 if ok else 1)


if __name__ == '__main__':
    main()
