#!/usr/bin/env python3
"""The SAM Coupe's sound in MAME: calls the game's sound hooks one after the other (test/sam/sound.sh makes the game run them, as if the
engine had) and measures the recording of the SAA 1099.  Each effect must start, and last about as long as its packed data says (50 ticks a
second: the frame interrupt calls the player); the crash is a noise that must have died away after its 2.02 s.

  usage: test/sam/sound_check.py        (MAME in $SAM_MAME; make sam first)
"""
import array
import os
import re
import subprocess
import sys
import wave

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
OUT = os.path.join(ROOT, 'build', 'samsnd')
# hook, the frame it is called at, the seconds it should sound for (the packed data's ticks / 50), and how much of the end may be too quiet to see
EFFECTS = (('play_place_sound', 700, 0.20), ('play_built_sound', 800, 0.24), ('play_crash_sound', 900, 2.02),
           ('play_rising_tone', 1100, 0.30), ('play_falling_tone', 1200, 0.62))


def main():
    syms = {}
    for line in open(os.path.join(ROOT, 'build/sam/simcity.map')):
        m = re.match(r'(\S+)\s+= \$([0-9A-F]+) ;', line)
        if m:
            syms[m.group(1)] = m.group(2)
    os.makedirs(OUT, exist_ok=True)
    spec = ','.join(f'{f}:{syms[h]}' for h, f, d in EFFECTS)
    wav, log = os.path.join(OUT, 'check.wav'), os.path.join(OUT, 'check.log')
    subprocess.run([os.path.join(ROOT, 'test/sam/sound.sh'), spec, '1400', log, wav], capture_output=True)
    if not os.path.exists(wav):
        print('FAIL  MAME made no recording')
        return 1
    w = wave.open(wav)
    s = array.array('h', w.readframes(w.getnframes()))[0::w.getnchannels()]
    r = w.getframerate()
    ok = True
    for h, f, want in EFFECTS:
        t0 = f / 50.0
        x = s[int(t0 * r):int((t0 + want + 1.0) * r)]
        loud = [i for i, v in enumerate(x) if abs(v) > 150]
        if not loud:
            print(f'FAIL  {h}: silent')
            ok = False
            continue
        start, length = loud[0] / r, (loud[-1] - loud[0]) / r
        good = start < 0.1 and want * 0.6 <= length <= want * 1.15           # (the last ticks are too quiet to measure)
        print(('PASS' if good else 'FAIL') + f'  {h}: starts {start:.2f} s after the call, lasts {length:.2f} s (the data: {want:.2f} s)')
        ok &= good
    return 0 if ok else 1


if __name__ == '__main__':
    sys.exit(main())
