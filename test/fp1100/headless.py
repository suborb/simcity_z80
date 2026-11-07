#!/usr/bin/env python3
"""Run the FP-1100 game headless under z88dk-ticks with the machine model (fp_machine.lua: the floppy pack and the sub-CPU's commands) and render the frames asked for.

  headless.py [--frames 300,600] [--keys 100:3:1:2,...] [--max-frames N] [--out DIR] [--disc build/fp1100/simcity.d88]

A frame is one Tick command (the game's idle loop asks once a frame); --keys are frame:column:bit:hold (frames) in the key matrix (the `1` of the level menu is 3:1... as in game_run.lua,
with seconds there).  The run stops after --max-frames (default: the last of --frames) by a ticks instruction count, so it is approximate; output is OUT/vram_<n>.png.
"""
import argparse, os, subprocess, sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--frames', default='300')
    ap.add_argument('--keys', default='100:3:1:2')
    ap.add_argument('--out', default=os.path.join(ROOT, 'build/fp1100/tk'))
    ap.add_argument('--disc', default=os.path.join(ROOT, 'build/fp1100/simcity.d88'))
    ap.add_argument('--timeout', type=int, default=900)
    a = ap.parse_args()
    os.makedirs(a.out, exist_ok=True)
    B = os.path.join(ROOT, 'build/fp1100')
    img = bytearray(open(os.path.join(B, 'simcity.bin'), 'rb').read())
    # the takeover talks to the ROM's own sub-CPU program, which the model does not have: the machine starts taken over (fp_boot returns at once); the pictures come from the disc as on the real machine
    boot = int([l.split('$')[1][:4] for l in open(os.path.join(B, 'simcity.map')) if l.startswith('_fp_boot ')][0], 16)
    img[boot] = 0xC9
    open(os.path.join(a.out, 'img.bin'), 'wb').write(bytes(img))
    frames = [int(x) for x in a.frames.split(',')]
    env = dict(os.environ, FP_OUT=a.out, FP_SNAPS=a.frames, FP_KEYS=a.keys, FDC_IMAGE=a.disc, FP_EVERY='100000000')
    # stop when the last snapshot is written: poll the output file from a watcher
    last = os.path.join(a.out, 'vram_%d.bin' % max(frames))
    if os.path.exists(last):
        os.remove(last)
    p = subprocess.Popen(['z88dk-ticks', '-lua', os.path.join(HERE, 'fp_machine.lua'), '-pc', '0', '-counter', '100000000000', '-output', os.path.join(a.out, 'mem.out'),
                          os.path.join(a.out, 'img.bin')], cwd=a.out, env=env, stdout=subprocess.DEVNULL, stderr=subprocess.PIPE)
    import time
    t0 = time.time()
    while p.poll() is None and time.time() - t0 < a.timeout:
        if os.path.exists(last) and os.path.getsize(last) == 24000:
            break
        time.sleep(0.5)
    if p.poll() is None:
        p.kill()
    err = p.stderr.read().decode()
    if err.strip():
        print(err.strip())
    for n in frames:
        v = os.path.join(a.out, 'vram_%d.bin' % n)
        if os.path.exists(v):
            subprocess.run([sys.executable, os.path.join(HERE, 'render.py'), v, os.path.join(a.out, 'frame_%d.png' % n), '2'], check=True)
            print('frame %d: %s' % (n, os.path.join(a.out, 'frame_%d.png' % n)))
        else:
            print('frame %d: not reached' % n)


main()
