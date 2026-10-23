#!/usr/bin/env python3
"""Extract the sound effects of the Atari ST SimCity (Maxis, 1989) from a Hatari memory snapshot.

  tools/extract_st_sounds.py SNAPSHOT.sav [--out assets/st_sounds.bin] [--effects 2,4,6,...] [--wav DIR] [--list]

The ST game has its own sound driver (at $56300 in the snapshot's RAM: a parameter block of 14 bytes for each of 48 effects, a tick
routine the game calls from an interrupt at 50 Hz, and the YM2149's registers written directly).  It plays one voice, on channel C: a tone
and/or noise, whose period is stepped and swept, and whose volume follows a curve.  This tool runs the game's own driver under Unicorn (the
68000 emulator; `pip install unicorn`) with a stand in for the sound chip, a tick at a time, and keeps what it writes: for each tick the
tone period (the noise period is always its low byte) and the volume.  The registers of channels A and B and the envelope never change.

The effects are packed small (see pack()): per effect a mixer byte, the length of its volume stream, the first tone period, the volume as runs
of equal ticks (a byte each: count << 4 | volume), then the tone period as segments of ticks in which it changes by the same amount each
tick (a count and a delta, one byte each, or three bytes for a delta that does not fit a byte).  The file is a count, a word offset for each
effect, then the effects; target/common/ay_sfx.asm plays it.  --wav writes each effect as a sound file to listen to.

The game's effects (the numbers are the driver's).  The art, and so the sound, belongs to the game: keep the snapshot out of the repository.
"""
import argparse
import gzip
import os
import struct
import sys
import wave

RAM_AT = 0x6ced                # where the ST's RAM starts in the Hatari snapshot
START = 0x5668c                # the driver: start the effect in d0
TICK = 0x56452                 # one tick
SILENCE = 0x56604

# the effects the game can start (found from the calls of its play routine at $56314 and its wrappers)
USED = [0, 1, 2, 4, 6, 8, 9, 10, 14, 21, 22, 24, 26, 28, 29, 33, 36, 37, 40]


def load(path):
    data = open(path, 'rb').read()
    if data[:2] == b'\x1f\x8b':
        data = gzip.decompress(data)
    return bytes(data[RAM_AT:RAM_AT + 0x100000])


class Chip:
    """The sound chip as the driver sees it: a register select, a data port, and a read back of the selected register."""
    def __init__(self):
        self.sel = 0
        self.regs = [0] * 16

    def read(self, uc, off, size, ud):
        if off == 0x800:
            return self.regs[self.sel & 15]
        return 2 if off == 0x20a else 0              # (the shifter's sync mode: 50 Hz)

    def write(self, uc, off, size, val, ud):
        if off == 0x800:
            self.sel = val & 15
        elif off == 0x802:
            self.regs[self.sel & 15] = val & 0xFF


def record(ram, effect, maxticks=700, quiet=8):
    """The register file after each tick of the effect, until the volume has been 0 for `quiet` ticks (or maxticks)."""
    from unicorn import Uc, UC_ARCH_M68K, UC_MODE_BIG_ENDIAN
    from unicorn.m68k_const import UC_M68K_REG_SR, UC_M68K_REG_A7, UC_M68K_REG_D0
    from unicorn.m68k_const import UC_CPU_M68K_M68000
    chip = Chip()
    uc = Uc(UC_ARCH_M68K, UC_MODE_BIG_ENDIAN)
    uc.ctl_set_cpu_model(UC_CPU_M68K_M68000)             # (the default is a ColdFire)
    uc.mem_map(0, 0x100000)
    uc.mem_write(0, ram)
    uc.mmio_map(0xFF8000, 0x1000, chip.read, None, chip.write, None)
    uc.mmio_map(0xFFF000, 0x1000, lambda uc, off, sz, ud: 0x80 if off == 0xa01 else 0, None, lambda *a: None, None)   # (a colour monitor)
    ret = 0xFE000
    uc.mem_write(ret, bytes.fromhex('4E71'))

    def call(addr, d0=0):
        uc.reg_write(UC_M68K_REG_SR, 0x2700)
        sp = 0xF0000 - 4
        uc.mem_write(sp, ret.to_bytes(4, 'big'))
        uc.reg_write(UC_M68K_REG_A7, sp)
        uc.reg_write(UC_M68K_REG_D0, d0)
        uc.emu_start(addr, ret, count=200000)

    call(SILENCE)
    call(START, d0=effect)
    frames, silent = [], 0
    for _ in range(maxticks):
        call(TICK)
        frames.append(list(chip.regs))
        silent = silent + 1 if chip.regs[10] & 15 == 0 and chip.regs[8] & 15 == 0 and chip.regs[9] & 15 == 0 else 0
        if silent >= quiet:
            break
    return frames[:len(frames) - quiet + 1] if silent >= quiet else frames


def reduce_frames(effect, frames):
    """(mixer, [(period, volume)] a tick): and checks what the packing leaves out really never changes."""
    mixer = frames[0][7]
    out = []
    for f in frames:
        period = f[4] | (f[5] & 15) << 8
        assert f[7] == mixer, (effect, 'the mixer changes')
        assert f[8] & 15 == 0 and f[9] & 15 == 0, (effect, 'channels A and B sound')
        assert mixer & 32 or f[6] & 31 == period & 31, (effect, 'the noise period is not the tone period\'s low byte')
        out.append((period, f[10] & 15))
    return mixer, out


def pack_effect(mixer, ticks):
    """One effect: mixer, the length of the volume stream, the first period (a word), the volume runs (count << 4 | volume, 0 ends), the period segments."""
    runs = bytearray()
    i = 0
    while i < len(ticks):
        v = ticks[i][1]
        n = 1
        while i + n < len(ticks) and ticks[i + n][1] == v and n < 15:
            n += 1
        runs.append(n << 4 | v)
        i += n
    runs.append(0)
    segs = bytearray()
    deltas = [((ticks[i][0] - ticks[i - 1][0] + 2048) & 4095) - 2048 for i in range(1, len(ticks))]
    i = 0
    while i < len(deltas):
        d = deltas[i]
        n = 1
        while i + n < len(deltas) and deltas[i + n] == d and n < 127:
            n += 1
        if -128 <= d <= 127:
            segs += bytes((n, d & 255))
        else:
            segs += bytes((n | 0x80, d & 255, (d >> 8) & 255))
        i += n
    segs.append(0)
    assert len(runs) < 256
    return bytes((mixer, len(runs))) + struct.pack('<H', ticks[0][0]) + bytes(runs) + bytes(segs)


def unpack_effect(blob, at):
    """The ticks (period, volume) of the packed effect at `at`, as the Z80 player makes them (the reference for the test)."""
    mixer, vlen = blob[at], blob[at + 1]
    period = blob[at + 2] | blob[at + 3] << 8
    v = at + 4
    p = v + vlen
    vols = []
    while blob[v]:
        vols += [blob[v] & 15] * (blob[v] >> 4)
        v += 1
    deltas = []
    while blob[p]:
        n = blob[p] & 0x7F
        if blob[p] & 0x80:
            d = blob[p + 1] | blob[p + 2] << 8
            d = d - 65536 if d & 0x8000 else d
            p += 3
        else:
            d = blob[p + 1] - 256 if blob[p + 1] & 0x80 else blob[p + 1]
            p += 2
        deltas += [d] * n
    ticks = [(period, vols[0])]
    for t in range(1, len(vols)):
        period = (period + (deltas[t - 1] if t - 1 < len(deltas) else 0)) & 4095
        ticks.append((period, vols[t]))
    return mixer, ticks


def pack(effects):
    """The file: a count, a word offset for each effect (from the start of the file), the effects."""
    body = [pack_effect(m, t) for m, t in effects]
    head = 1 + 2 * len(body)
    offsets, at = [], head
    for b in body:
        offsets.append(at)
        at += len(b)
    return bytes((len(body),)) + b''.join(struct.pack('<H', o) for o in offsets) + b''.join(body)


AY_CLOCK = 2000000                # the ST's YM2149
VOLUME = [0.0, 0.0047, 0.0067, 0.0094, 0.0133, 0.0188, 0.0266, 0.0376, 0.0531, 0.0751, 0.1061, 0.1500, 0.2119, 0.2996, 0.4237, 0.6000]


def render(mixer, ticks, rate=22050):
    """The effect as 16 bit mono samples: channel C's square wave and noise through the chip's mixer and a logarithmic volume."""
    samples = bytearray()
    phase, lfsr, noise_phase, tone, noise = 0.0, 1, 0.0, 1, 0
    per_tick = rate // 50
    for period, vol in ticks:
        tone_period = max(period, 1)
        noise_period = max(period & 31, 1)
        tone_enabled = not mixer & 4
        noise_enabled = not mixer & 32
        for _ in range(per_tick):
            phase += rate_step(rate, tone_period)
            while phase >= 1.0:
                phase -= 1.0
                tone ^= 1
            noise_phase += rate_step(rate, noise_period)
            while noise_phase >= 1.0:
                noise_phase -= 1.0
                bit = (lfsr ^ (lfsr >> 3)) & 1
                lfsr = (lfsr >> 1) | bit << 16
                noise = lfsr & 1
            level = ((tone or not tone_enabled) and (noise or not noise_enabled))
            if not tone_enabled and not noise_enabled:
                level = 0
            value = int(VOLUME[vol] * (1 if level else -1) * 16000)
            samples += struct.pack('<h', value)
    return bytes(samples)


def rate_step(rate, period):
    """The tone's half periods a sample: the chip toggles every `period` steps of clock / 16."""
    return (AY_CLOCK / 16.0 / period) / rate


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('snapshot')
    ap.add_argument('--out', default=os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'assets', 'st_sounds.bin'))
    ap.add_argument('--effects', help='the driver\'s effect numbers to pack, in order (default: the ones the game starts)')
    ap.add_argument('--wav', help='a directory to write each effect to as a .wav')
    ap.add_argument('--list', action='store_true', help='say what each effect is like')
    ap.add_argument('--maxticks', type=int, default=250, help='cut the sounds that never end after this many ticks (50 a second)')
    args = ap.parse_args()

    ram = load(args.snapshot)
    ids = [int(x) for x in args.effects.split(',')] if args.effects else USED
    effects = []
    for e in ids:
        frames = record(ram, e, maxticks=args.maxticks)
        mixer, ticks = reduce_frames(e, frames)
        effects.append((mixer, ticks))
        if args.list:
            periods = [p for p, v in ticks]
            kind = ('tone' if not mixer & 4 else '') + (' + noise' if not mixer & 32 else '')
            print(f'effect {e:2d}: {len(ticks):3d} ticks ({len(ticks) * 0.02:.2f} s), {kind.strip() or "silent"}, period {periods[0]} -> {periods[-1]}, volume {max(v for p, v in ticks)} max')
        if args.wav:
            os.makedirs(args.wav, exist_ok=True)
            with wave.open(os.path.join(args.wav, f'effect_{e:02d}.wav'), 'wb') as w:
                w.setnchannels(1)
                w.setsampwidth(2)
                w.setframerate(22050)
                w.writeframes(render(mixer, ticks))
    blob = pack(effects)
    # the packing must give back the ticks it was made from
    count = blob[0]
    for k, (mixer, ticks) in enumerate(effects):
        at = blob[1 + 2 * k] | blob[2 + 2 * k] << 8
        m2, t2 = unpack_effect(blob, at)
        assert m2 == mixer and t2 == ticks, f'effect {ids[k]} does not unpack to what was packed'
    open(args.out, 'wb').write(blob)
    raw = sum(len(t) * 14 for m, t in effects)
    print(f'{count} effects, {len(blob)} bytes -> {args.out} (the register writes of the same ticks, 14 a tick: {raw} bytes)')


if __name__ == '__main__':
    main()
