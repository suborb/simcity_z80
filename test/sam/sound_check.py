#!/usr/bin/env python3
"""The SAM Coupe's sound in MAME, recorded from its SAA 1099.

make builds the game with -DSOUND_TEST (build/samtest): its idle loop calls each of the engine's sound hooks at a frame of its own, as the
engine would (target/sam/plat_sound.asm: snd_test).  MAME records the sound and each burst of it is measured: there must be one for each
hook, in order, starting as far apart as the frames say (the frame interrupt is 50 Hz) and lasting about as long as the packed data says
(the last ticks are too quiet to measure, so a burst may be shorter).

  usage: test/sam/sound_check.py        (MAME in $SAM_MAME)
"""
import array
import os
import subprocess
import sys
import wave

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
OUT = os.path.join(ROOT, 'build', 'samsnd')
# the hook, the frame it is called at (snd_test), and the seconds it should sound for (the packed data's ticks / 50)
EFFECTS = (('play_place_sound', 100, 0.20), ('play_built_sound', 300, 0.24), ('play_crash_sound', 500, 2.02),
           ('play_rising_tone', 800, 0.30), ('play_falling_tone', 1000, 0.62), ('soundfx1', 1200, 2.42))


def bursts(s, rate, gap=0.3, threshold=150):
    found, start, last = [], None, None
    for i, v in enumerate(s):
        if abs(v) > threshold:
            if start is None:
                start = i
            elif i - last > gap * rate:
                found.append((start / rate, last / rate))
                start = i
            last = i
    if start is not None:
        found.append((start / rate, last / rate))
    return found


def main():
    os.makedirs(OUT, exist_ok=True)
    r = subprocess.run(['make', '-s', 'SAM=build/samtest/simcity.mgt', 'SAM_TEST=-DSOUND_TEST -Ca-DSOUND_TEST', 'build/samtest/simcity.mgt'],
                       cwd=ROOT, capture_output=True, text=True)
    if r.returncode:
        print(r.stdout + r.stderr)
        print('FAIL  the sound test build did not build')
        return 1
    wav = os.path.join(OUT, 'check.wav')
    if os.path.exists(wav):
        os.remove(wav)
    env = dict(os.environ, SAMDISK=os.path.join(ROOT, 'build/samtest/simcity.mgt'))
    subprocess.run([os.path.join(ROOT, 'test/sam/sound.sh'), '', '3600', os.path.join(OUT, 'check.log'), wav], capture_output=True, env=env)
    if not os.path.exists(wav):
        print('FAIL  MAME made no recording')
        return 1
    w = wave.open(wav)
    s = array.array('h', w.readframes(w.getnframes()))[0::w.getnchannels()]
    found = bursts(s, w.getframerate())
    ok = len(found) == len(EFFECTS)
    if not ok:
        print(f'FAIL  {len(found)} bursts of sound, wanted {len(EFFECTS)}: {[(round(a, 2), round(b - a, 2)) for a, b in found]}')
        return 1
    for k, ((h, f, want), (a, b)) in enumerate(zip(EFFECTS, found)):
        length = b - a
        apart = (a - found[k - 1][0]) if k else None
        wanted_apart = (f - EFFECTS[k - 1][1]) / 50.0 if k else None
        good = want * 0.6 <= length <= want * 1.15 and (apart is None or abs(apart - wanted_apart) < 0.1)
        print(('PASS' if good else 'FAIL') + f'  {h}: lasts {length:.2f} s (the data: {want:.2f} s)'
              + ('' if apart is None else f', {apart:.2f} s after the one before (the frames: {wanted_apart:.2f} s)'))
        ok &= good
    return 0 if ok else 1


if __name__ == '__main__':
    sys.exit(main())
