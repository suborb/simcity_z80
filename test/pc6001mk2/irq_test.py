#!/usr/bin/env python3
"""Host test of the game's interrupt and sound code (target/pc6001mk2/plat_irq.asm, plat_sound.asm) under z88dk-ticks with the mkII model (lib/ticks/memory/pc6001mk2.lua): the timer's
rate ($F6 = 31: about 61 Hz), a scripted keyboard interrupt and its code, and the PSG writes of the refusal's beep with their timing.
  usage: test/pc6001mk2/irq_test.py      (z88dk on the path, ZCCCFG set)"""
import os, re, subprocess, sys, tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
MODEL = os.path.join(os.environ.get("ZCCCFG", os.path.expanduser("~/z88dk/lib/config")), "..", "ticks", "memory", "pc6001mk2.lua")
CYCLES_PER_TICK = 4000000 * 32 / 1950

def run(cmd, **kw):
    r = subprocess.run(cmd, capture_output=True, text=True, **kw)
    if r.returncode:
        sys.exit("%s failed:\n%s%s" % (cmd[0], r.stdout, r.stderr))
    return r

def main():
    ok = True
    def check(name, cond, extra=""):
        nonlocal ok
        print(("ok   " if cond else "FAIL ") + name + (" " + extra if extra and not cond else ""))
        ok &= bool(cond)
    with tempfile.TemporaryDirectory() as d:
        os.chdir(d)
        for f in ("irq_prog.c", "irq_ovl.asm"):
            open(f, "w").write(open(os.path.join(HERE, f)).read())
        for f in ("plat_irq.asm", "plat_sound.asm"):
            open(f, "w").write(open(os.path.join(ROOT, "target", "pc6001mk2", f)).read())
        run(["zcc", "+pc6001", "-subtype=mk2disc", "-m", "-pragma-define:CRT_ENABLE_STDIO=0", "-pragma-define:CLIB_EXIT_STACK_SIZE=0", "-pragma-define:CRT_PC6001MK2_NO_MODE=1",
             "irq_prog.c", "irq_ovl.asm", "plat_irq.asm", "plat_sound.asm", "-o", "prog"])
        mp = open("prog.map").read()
        sym = lambda n: int(re.search(r"^%s\s*= \$([0-9A-F]+)" % n, mp, re.M).group(1), 16)
        key_at = int(6.5 * CYCLES_PER_TICK)
        env = dict(os.environ, MK2_OUTDIR=d, MK2_KEYS="%d:97" % key_at)
        run(["z88dk-ticks", "-b", "lua", "-lua", MODEL, "-int", "2000", "-end", "%04x" % sym("_stop"), "-output", "mem.out", "prog"], env=env)
        mem = open("mem.out", "rb").read()
        res = [mem[sym("_result") + 2 * i] | (mem[sym("_result") + 2 * i + 1] << 8) for i in range(8)]
        check("three waits are three timer ticks", res[0] == 3, str(res[:1]))
        check("the key interrupt gave the code", res[1] == 97 and res[3] == 0, str(res[1:4:2]))
        check("it came at about 6.5 ticks (the timer runs at 61 Hz)", 6 <= res[2] <= 8, "ticks %d" % res[2])
        check("30 ticks later", res[4] - res[2] in (30, 31), str(res[4] - res[2]))
        psg = [tuple(map(int, re.match(r"(\d+) R(\d+)=([0-9a-f]+)", l).groups()[:2])) + (int(re.match(r"(\d+) R(\d+)=([0-9a-f]+)", l).group(3), 16),) for l in open("mk2-psg.txt")]
        vol = [(c, v) for c, r, v in psg if r == 8]
        beep = [(c, v) for c, v in vol if v == 15]
        check("the refusal's beep starts at full volume", len(beep) >= 1)
        first = [c for c, v in vol][1:]
        # the beep: volume 15 for 12 ticks, then 0
        times = [c for c, v in vol]
        start = next(c for c, v in vol if v == 15)
        stop = next(c for c, v in vol if c > start and v == 0)
        check("and lasts 12 ticks", abs((stop - start) / CYCLES_PER_TICK - 12) < 1.1, "%.2f ticks" % ((stop - start) / CYCLES_PER_TICK))
        tone = [(c, r, v) for c, r, v in psg if r in (0, 1) and c >= start - 5000 and c <= start + 5000]
        check("at tone period 400 ($0190)", any(r == 0 and v == 0x90 for _, r, v in tone) and any(r == 1 and v == 0x01 for _, r, v in tone), str(tone[:4]))
    return 0 if ok else 1

if __name__ == "__main__":
    sys.exit(main())
