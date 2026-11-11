#!/usr/bin/env python3
"""Host test of z88dk's PC-6001mkII 320x200 mode (zcc +pc6001 -subtype=mk2disc: mode 3 of the mc6847 console and the wide graphics, libsrc/target/pc6001/mk2) under z88dk-ticks with
the mkII model (lib/ticks/memory/pc6001mk2.lua): the video registers, text in the cells, pixels in the two planes (plot, unplot, xorplot, point, off the screen), vpeek and scrolling.
  usage: test/pc6001mk2/console_test.py      (z88dk on the path, ZCCCFG set)"""
import os, re, subprocess, sys, tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
MODEL = os.path.join(os.environ.get("ZCCCFG", os.path.expanduser("~/z88dk/lib/config")), "..", "ticks", "memory", "pc6001mk2.lua")

def run(cmd, **kw):
    r = subprocess.run(cmd, capture_output=True, text=True, **kw)
    if r.returncode:
        sys.exit("%s failed:\n%s%s" % (cmd[0], r.stdout, r.stderr))
    return r

def main(subtype="mk2disc"):
    ok = True
    def check(name, cond, extra=""):
        nonlocal ok
        print(("ok   " if cond else "FAIL ") + name + (" " + extra if extra and not cond else ""))
        ok &= bool(cond)
    with tempfile.TemporaryDirectory() as d:
        os.chdir(d)
        for f in ("console_prog.c", "console_ovl.asm"):
            open(f, "w").write(open(os.path.join(HERE, f)).read())
        opts = ["-subtype=rom", "-clib=mk2", "-create-app"] if subtype == "rom" else ["-subtype=mk2disc"]
        run(["zcc", "+pc6001", "-m"] + opts + ["console_prog.c", "console_ovl.asm", "-o", "prog"])
        image = "prog"
        pc = []
        if subtype == "rom":                        # a cartridge: -subtype=rom -clib=mk2: the ROM is at $4000, and the program starts at $4004
            open("rom.img", "wb").write(bytes(0x4000) + open("prog.bin", "rb").read())
            image, pc = "rom.img", ["-pc", "4004"]
        mp = open("prog.map").read()
        sym = lambda n: int(re.search(r"^%s\s*= \$([0-9A-F]+)" % n, mp, re.M).group(1), 16)
        env = dict(os.environ, MK2_OUTDIR=d)
        run(["z88dk-ticks", "-b", "lua", "-lua", MODEL, "-end", "%04x" % sym("_stop"), "-counter", "200000000", "-output", "mem.out"] + pc + [image], env=env)
        mem = open("mem.out", "rb").read()
        res = [mem[sym("_result") + 2 * i] | (mem[sym("_result") + 2 * i + 1] << 8) for i in range(8)]
        ports = {}
        for l in open("mk2-ports.txt"):
            m = re.match(r"\d+ \$([0-9a-f]+)=([0-9a-f]+)", l)
            if m: ports[int(m.group(1), 16)] = int(m.group(2), 16)
        want_b0 = 0 if subtype == "rom" else 2
        check("the video registers: $C1 = 0, $C0 = 4 (the default set), $B0 = %d (the screen at $%04X)" % (want_b0, 0x8000 if subtype == "rom" else 0xc000), ports.get(0xc1) == 0 and ports.get(0xc0) == 4 and ports.get(0xb0) == want_b0, str(ports))
        # the planes at the end: the scroll took row 0 away, so what is left of the pixels is below row 0
        base = (0x8000, 0xc000, 0x0000, 0x4000)[(ports.get(0xb0, 0) >> 1) & 3]       # the screen's base: $C000 for the disc, $8000 for a cartridge
        p0 = lambda a: mem[base + a]
        p1 = lambda a: mem[base + 0x2000 + a]
        def pixel(x, y):
            a = y * 40 + (x >> 3)
            m = 0x80 >> (x & 7)
            return (1 if p0(a) & m else 0) | (2 if p1(a) & m else 0)
        # pens: ink 1 (yellow) over paper 2 (blue) by default.  The scroll moved everything up by 8 pixel rows.
        check("plot(10, 20) is the ink pen (after the scroll, at y = 12)", pixel(10, 12) == 1, str(pixel(10, 12)))
        check("plot(319, 199) the corner (y = 191)", pixel(319, 191) == 1, str(pixel(319, 191)))
        check("a pixel left alone is the paper pen", pixel(200, 50) == 2, str(pixel(200, 50)))
        check("unplot gives the paper back, xorplot twice leaves the paper, once xors the ink in (2 ^ 1 = 3)", pixel(0, 0) == 2 and pixel(120, 92) == 2 and pixel(130, 92) == 3, "%d %d %d" % (pixel(0, 0), pixel(120, 92), pixel(130, 92)))
        check("point: the plotted pixel is set, its neighbour not", res[0] != 0 and res[1] == 0, str(res[:2]))
        check("getmaxx = 319, getmaxy = 199", res[2] == 319 and res[3] == 199, str(res[2:4]))
        check("vpeek reads the printed text back", res[4] == ord("H") and res[5] == ord("O"), str(res[4:6]))
        check("vpeek of an empty cell is a space", res[6] == 32, str(res[6]))
        check("the scroll moved the text off the top: row 0 is now what row 1 was", res[7] == 32, str(res[7]))
        # the screenshot is the model's: a sanity check that it writes
        check("the screen was exported", os.path.exists("mk2-screen.ppm"))
    return 0 if ok else 1

if __name__ == "__main__":
    print("-- -subtype=mk2disc")
    r = main("mk2disc")
    print("-- -subtype=rom -clib=mk2")
    r |= main("rom")
    sys.exit(r)
