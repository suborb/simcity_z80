#!/usr/bin/env python3
"""z88dk's Lynx disk driver (lynx_disk_read/write: asm_lynx_disk_regs of lynx_clib) under z88dk-ticks, against the WD1793 model (z88dk's lib/ticks/wd1793.lua behind the ports of
z88dk's lib/ticks/memory/lynx.lua).  Reads across a track boundary, writes and reads the written sectors back out of the model, the E bit (the head settling delay, asked for only on the first sector
after the heads moved), the motor stopped at the end, a drive that is not ready, a sector that does not exist, a slow motor, and the interrupt flag kept.
What it cannot check is the timing: the model has no clock for the disk (and the DAC log has the CPU's).
"""
import os, subprocess, sys, tempfile

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
HERE = os.path.dirname(os.path.abspath(__file__))
CFG = os.environ.get('ZCCCFG', os.path.expanduser('~/z88dk/lib/config'))
MODEL = os.path.join(CFG, '..', 'ticks', 'memory', 'lynx.lua')        # z88dk's Lynx 128K model
CLIBS = os.path.join(os.environ.get('ZCCCFG', os.path.expanduser('~/z88dk/lib/config')), '..', 'clibs')

HARNESS = """
        SECTION code_user
        org     $2000
start:  ld      sp,$7000
        ld      hl,$4000                    ; the buffer: 3 * i + 1 (a write sends this)
        ld      de,0
fill:   ld      a,e
        add     a,a
        add     a,e
        inc     a
        ld      (hl),a
        inc     hl
        inc     de
        ld      a,d
        cp      8
        jr      nz,fill
        @EI@
        ld      a,@MODE@
        ld      e,@DRIVE@
        ld      d,@TRACK@
        ld      c,@SECTOR@
        ld      b,@COUNT@
        ld      hl,$4000
        call    asm_lynx_disk_regs
        ld      ($3F00),hl
        ld      a,i
        push    af
        pop     bc
        ld      a,c
        ld      ($3F02),a                   ; the flags of LD A,I: bit 2 is the interrupt flag
        ld      a,1
        out     ($F0),a                     ; (the model dumps what was written)
done:   jp      done
        EXTERN  asm_lynx_disk_regs
"""


def pattern(t, s, i):
    return (t * 7 + s * 29 + i) & 0xff


def run(mode, track, sector, count, env=None, ei=False, drive=0, preload=None):
    with tempfile.TemporaryDirectory() as tmp:
        src = HARNESS
        for k, v in dict(MODE=mode, DRIVE=drive, TRACK=track, SECTOR=sector, COUNT=count, EI='ei' if ei else 'di').items():
            src = src.replace('@%s@' % k, str(v))
        open(os.path.join(tmp, 'h.asm'), 'w').write(src)
        r = subprocess.run(['z88dk-z80asm', '-b', '-m', '-I' + ROOT, '-L' + CLIBS, '-llynx_clib', os.path.join(tmp, 'h.asm')], capture_output=True, text=True, cwd=ROOT)
        if r.returncode:
            sys.exit(r.stdout + r.stderr)
        img = b''.join(open(os.path.join(tmp, f), 'rb').read() for f in ('h_code_user.bin', 'h_code_clib.bin') if os.path.exists(os.path.join(tmp, f)))
        open(os.path.join(tmp, 'img.bin'), 'wb').write(bytearray(0x2000) + img)
        done = [l for l in open(os.path.join(tmp, 'h.map')) if l.startswith('done ')][0].split('$')[1][:4]
        if preload:
            open(os.path.join(tmp, 'pre.bin'), 'wb').write(preload)
        e = dict(os.environ, ZCCCFG=CFG, LYNX_OUTDIR=tmp, **(env or {}))
        out = os.path.join(tmp, 'mem.out')
        r = subprocess.run(['z88dk-ticks', '-b', 'lua', '-lua', MODEL, '-pc', '2000', '-end', done, '-counter', '400000000', '-output', out,
                            os.path.join(tmp, 'img.bin')], capture_output=True, text=True, cwd=tmp, env=e)
        mem = open(out, 'rb').read() if os.path.exists(out) else b''
        written = {}
        p = os.path.join(tmp, 'disk_out.txt')
        if os.path.exists(p):
            for line in open(p):
                t, s, hx = line.split()
                written[(int(t), int(s))] = bytes.fromhex(hx)
        rd = lambda n: open(os.path.join(tmp, n)).read() if os.path.exists(os.path.join(tmp, n)) else ''
        return mem, written, rd('fdc_log.txt'), rd('ports_log.txt'), rd('fdc_errors.txt').strip(), r.stdout + r.stderr


def main():
    bad = 0

    def check(name, cond, extra=''):
        nonlocal bad
        print(('ok   ' if cond else 'FAIL ') + name + ('  ' + extra if (extra and not cond) else ''))
        bad += not cond

    # read 3 sectors from track 5 sector 9: two on that track, then the first of track 6
    mem, w, log, ports, errs, o = run(0, 5, 9, 3)
    if not mem:
        sys.exit('no memory dump:\n' + o)
    res = mem[0x3F00] | mem[0x3F01] << 8
    check('read across a track: result 0', res == 0, 'hl=%d\n%s' % (res, log[-600:]))
    exp = b''.join(bytes(pattern(t, s, i) for i in range(512)) for t, s in ((5, 9), (5, 10), (6, 1)))
    check('read data right', mem[0x4000:0x4000 + 1536] == exp)
    cmds = [l.split()[1] for l in log.splitlines() if l.startswith('cmd')]
    check('commands: restore, seek 5, read (E), read, seek 6, read (E)', cmds == ['0b', '1b', '84', '80', '1b', '84'], str(cmds))
    check('no model errors', errs == '', errs)
    last58 = [l for l in ports.splitlines() if '$58=' in l][-1]
    check('the motor is stopped at the end ($58 bit 3)', int(last58.split('=')[1], 16) & 8 != 0, last58)
    check('the motor was started (an earlier $58 write with bit 3 clear)', any(int(l.split('=')[1], 16) & 8 == 0 for l in ports.splitlines() if '$58=' in l))

    # the next read from the same track needs no restore when the heads are known: it is a new call, so the driver restores again (it keeps no state across a reset of the model)
    # write 2 sectors: track 0 sector 10, track 1 sector 1
    buf = bytes((i * 3 + 1) & 0xff for i in range(1024))
    mem, w, log, ports, errs, o = run(1, 0, 10, 2)
    res = mem[0x3F00] | mem[0x3F01] << 8
    check('write 2 sectors: result 0', res == 0, 'hl=%d\n%s' % (res, log[-600:]))
    check('written sectors reach track 0 sector 10 and track 1 sector 1', sorted(w) == [(0, 10), (1, 1)], str(sorted(w)))
    check('they are the buffer, in order', w.get((0, 10)) == buf[:512] and w.get((1, 1)) == buf[512:1024])
    check('no model errors (write)', errs == '', errs)
    cmds = [l.split()[1] for l in log.splitlines() if l.startswith('cmd')]
    check('write commands: restore, write (E: track 0 needs no seek), seek 1, write (E)', cmds == ['0b', 'a4', '1b', 'a4'], str(cmds))

    # no disk: an error at once (and little work: the wait for ready is bounded)
    mem, w, log, ports, errs, o = run(0, 0, 1, 1, env={'LYNX_NO_DISC': '1'})
    res = mem[0x3F00] | mem[0x3F01] << 8
    check('no disk: error 1', res == 1, 'hl=%d' % res)
    check('no disk: no sector commands', 'read sector' not in log, log)

    # a slow motor
    mem, w, log, ports, errs, o = run(0, 2, 3, 1, env={'LYNX_SPINUP': '400'})
    res = mem[0x3F00] | mem[0x3F01] << 8
    check('a motor that takes 400 status reads to come up to speed: result 0, data right', res == 0 and mem[0x4000:0x4200] == bytes(pattern(2, 3, i) for i in range(512)), 'hl=%d' % res)

    # past the last track: the sector is not there, and the driver gives up
    mem, w, log, ports, errs, o = run(0, 39, 10, 2)
    res = mem[0x3F00] | mem[0x3F01] << 8
    check('read past the last track: error 1', res == 1, 'hl=%d\n%s' % (res, log[-500:]))

    # the interrupt flag comes back as it was
    for ei in (False, True):
        mem, w, log, ports, errs, o = run(0, 1, 1, 1, ei=ei)
        flag = (mem[0x3F02] >> 2) & 1
        check('interrupts %s before: %s after' % ('on' if ei else 'off', 'on' if ei else 'off'), flag == (1 if ei else 0), 'flags %02x' % mem[0x3F02])
    print('FAILED' if bad else 'all ok')
    return 1 if bad else 0


if __name__ == '__main__':
    sys.exit(main())
