#!/usr/bin/env python3
"""The Z88's sound routines (platform/console/plat_sound.asm) play the Spectrum's effects through the COM register.

Each routine is run under z88dk-ticks with its trace on, from which every byte written to port $B0 (the COM
register) is read.  What is checked:
  * the speaker is bit 6 and SRUN (bit 7) is left clear while a sound plays;
  * COM is put back as OZ had it (its copy at $04B0) at the end;
  * the number of writes is what the Spectrum's loops make: soundfx1 writes once for every step of 200 where
    (counter AND E) = 0, soundfx2 twice for each of 500 cycles, and the three sweeps call soundfx1 with the
    Spectrum's E values;
  * with the Sound option off nothing is written.

  usage: test/sound/run.py
"""
import os
import re
import subprocess
import sys
import tempfile

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
SHADOW = 0xA1                       # what OZ has in COM: SRUN (bit 7) set, to see it cleared and restored
failures = []


def check(name, ok, detail=''):
    print(('PASS  ' if ok else 'FAIL  ') + name + ((' ' + detail) if detail and not ok else ''))
    if not ok:
        failures.append(name)


def writes(e):
    """Steps of soundfx1 that write: the counter runs 1..200 and writes when (counter AND E) = 0."""
    return sum(1 for d in range(1, 201) if d & e == 0)


def run(tmp, call, enabled=1, e=0):
    asm = os.path.join(tmp, 'driver.asm')
    open(asm, 'w').write(f'''        MODULE  driver
        INCLUDE "sections.asm"
        IN_CODE
        org     $0100
start:  ld      sp,$0F00
        ld      a,${SHADOW:02x}
        ld      ($04B0),a
        ld      e,${e:02x}
        {call}
stop:   jp      stop
        INCLUDE "{ROOT}/platform/console/plat_sound.asm"
''')
    subprocess.run(['z88dk-z80asm', '-b', '-m', f'-I{ROOT}/engine', '-DPORTABLE', asm], check=True, capture_output=True, cwd=tmp)
    syms = {}
    for line in open(os.path.join(tmp, 'driver.map')):
        m = re.match(r'(\S+)\s*=\s*\$([0-9A-Fa-f]+)', line)
        if m:
            syms[m.group(1)] = int(m.group(2), 16)
    code = open(os.path.join(tmp, 'driver_code_user.bin'), 'rb').read()
    image = bytearray(65536)
    image[0x51] = image[0x54] = 0xC9                                # OZ_DI and OZ_EI: just return
    image[0x100:0x100 + len(code)] = code
    # the data section follows the code in the flat binary: _sound_enabled
    image[syms['_sound_enabled']] = enabled
    path = os.path.join(tmp, 'driver.img')
    open(path, 'wb').write(image)
    # -trace prints the registers before each instruction: the value written by OUT ($B0),A is A in the block above it
    p = subprocess.Popen(['z88dk-ticks', '-trace', '-pc', '100', '-end', f'{syms["stop"]:x}', '-counter', '2000000000', path],
                         stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, text=True, errors='replace')
    out = bytearray()
    a = 0
    for line in p.stdout:
        if line.startswith('pc='):
            a = int(line[line.index('af=') + 3:line.index('af=') + 5], 16)
        elif 'out       ($b0),a' in line:
            out.append(a)
    p.wait()
    return bytes(out)


def main():
    with tempfile.TemporaryDirectory() as tmp:
        out = run(tmp, 'call soundfx1', e=0)
        check('soundfx1 (E=0): 200 writes of the speaker bit, then COM as OZ had it',
              len(out) == 201 and out[-1] == SHADOW and all(b in (0x21, 0x61) for b in out[:-1]) and 0x21 in out and 0x61 in out,
              f'{len(out)} writes, {sorted(set(out))}')
        out = run(tmp, 'call soundfx1', e=0xFF)
        check('soundfx1 (E=255): the counter never reaches 0, so only the restore', list(out) == [SHADOW], str(list(out)))
        out = run(tmp, 'call soundfx1', e=0x0F)
        check('soundfx1 (E=15): a write for every step where counter AND 15 = 0', len(out) == writes(0x0F) + 1, f'{len(out)} vs {writes(0x0F) + 1}')
        out = run(tmp, 'call soundfx2')
        tone = list(out[:-1])
        check('soundfx2: 500 cycles of high then low (speaker bit 6, SRUN clear), then the restore',
              len(out) == 1001 and tone == [0x61, 0x21] * 500 and out[-1] == SHADOW, f'{len(out)} writes')
        check('play_place_sound is that tone', list(run(tmp, 'call play_place_sound')) == list(out))
        out = run(tmp, 'call play_rising_tone')
        want = sum(writes(b & 63) + 1 for b in range(127, 0, -1))
        check('play_rising_tone: 127 bursts, E = B AND 63', len(out) == want, f'{len(out)} vs {want}')
        out = run(tmp, 'call play_falling_tone')
        want = sum(writes((~b) & 127) + 1 for b in range(127, 0, -1))
        check('play_falling_tone: 127 bursts, E = NOT B AND 127', len(out) == want, f'{len(out)} vs {want}')
        out = run(tmp, 'call play_crash_sound')
        want = sum(writes(e) + 1 for e in range(255))
        check('play_crash_sound: 255 bursts, E from 0 up', len(out) == want, f'{len(out)} vs {want}')
        for call in ('call soundfx1', 'call soundfx2', 'call play_rising_tone'):
            check(f'with the Sound option off {call[5:]} writes nothing', len(run(tmp, call, enabled=0)) == 0)
    print('FAILED: ' + ', '.join(failures) if failures else 'all sound tests passed')
    sys.exit(1 if failures else 0)


if __name__ == '__main__':
    main()
