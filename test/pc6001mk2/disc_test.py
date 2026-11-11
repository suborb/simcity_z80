#!/usr/bin/env python3
"""Host test of z88dk's PC-6001mkII disc support (zcc +pc6001 -subtype=mk2disc): a program with three overlays is built, put on a disc by appmake +pc6001mk2, and run under
z88dk-ticks with the machine model lib/ticks/memory/pc6001mk2.lua (the PC-6031 handshake and a .d88).  It checks the loader's track arithmetic against appmake's layout (overlays
from tracks after the program, two tracks for a 5000 byte one), a write and a read back through the unit, and that the disc written is the d88 with only those sectors changed.
  usage: test/pc6001mk2/disc_test.py      (z88dk on the path, ZCCCFG set)"""
import os, re, struct, subprocess, sys, tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
MODEL = os.path.join(os.environ.get("ZCCCFG", os.path.expanduser("~/z88dk/lib/config")), "..", "ticks", "memory", "pc6001mk2.lua")

def run(cmd, **kw):
    r = subprocess.run(cmd, capture_output=True, text=True, **kw)
    if r.returncode:
        sys.exit("%s failed:\n%s%s" % (cmd[0], r.stdout, r.stderr))
    return r

def d88_sectors(path):
    d = open(path, "rb").read()
    out, off = {}, 0x2b0
    while off + 16 <= len(d):
        c, h, r = d[off], d[off + 1], d[off + 2]
        size = d[off + 14] | (d[off + 15] << 8)
        out[(c, h, r)] = d[off + 16:off + 16 + size]
        off += 16 + size
    return out

def main():
    ok = True
    def check(name, cond, extra=""):
        nonlocal ok
        print(("ok   " if cond else "FAIL ") + name + (" " + extra if extra and not cond else ""))
        ok &= bool(cond)
    with tempfile.TemporaryDirectory() as d:
        os.chdir(d)
        for f in ("disc_prog.c", "disc_ovl.asm", "disc_mmap.inc"):
            open(f, "w").write(open(os.path.join(HERE, f)).read())
        os.rename("disc_mmap.inc", "mmap.inc")
        run(["zcc", "+pc6001", "-subtype=mk2disc", "-create-app", "-m", "-pragma-define:MMAP=-1", "-pragma-define:CRT_PC6001MK2_OVERLAYS=3",
             "-pragma-define:CRT_ENABLE_STDIO=0", "-pragma-define:CLIB_EXIT_STACK_SIZE=0", "disc_prog.c", "disc_ovl.asm", "-o", "prog"])
        mp = open("prog.map").read()
        sym = lambda n: int(re.search(r"^%s\s*= \$([0-9A-F]+)" % n, mp, re.M).group(1), 16)
        img_tracks = (sym("__DATA_END_tail") + 4095) // 4096
        # the layout: program tracks 1..n, overlay 0 two tracks, 1 and 2 one each, then the free tracks
        first_free = 1 + img_tracks + 2 + 1 + 1
        sectors = d88_sectors("prog.d88")
        boot = sectors[(0, 0, 1)]
        check("boot sector starts SYS", boot[:3] == b"SYS")
        img = open("prog", "rb").read()
        check("the vectors: jp over them, ret at the rsts, ei/reti at $38, retn at $66",
              img[0] == 0xc3 and all(img[a] == 0xc9 for a in (8, 0x10, 0x18, 0x20, 0x28, 0x30)) and img[0x38:0x3b] == b"\xfb\xed\x4d" and img[0x66:0x68] == b"\xed\x45")
        check("the boot sector is the mkII's: its ROM signature, and room", b"\xdd\x2a\x29\xff\xcd\xb9\x42\x30" in boot)
        check("the image is on track 1", sectors[(1, 0, 1)][:3] == open("prog", "rb").read()[:3])
        o0 = sectors[(1 + img_tracks, 0, 1)]
        check("overlay 0 starts its track after the program", o0[:8] == bytes(range(0xa0, 0xa8)))
        check("overlay 0 goes on to a second track", sectors[(2 + img_tracks, 0, 1)][:8] == bytes(range(0xa0, 0xa8)))
        check("overlay 1 is on the next track", sectors[(3 + img_tracks, 0, 1)][:4] == b"\xb1" * 4)
        check("overlay 2 is on the next", sectors[(4 + img_tracks, 0, 1)][:4] == b"\xc2" * 4)
        env = dict(os.environ, MK2_DISC="prog.d88", MK2_OUTDIR=d)
        # the program ends in _stop (after the model's port that writes the logs and the disc): run to it
        run(["z88dk-ticks", "-b", "lua", "-lua", MODEL, "-end", "%04x" % sym("_stop"), "-output", "mem.out", "prog"], env=env)
        mem = open("mem.out", "rb").read()
        res = mem[sym("_result"):sym("_result") + 14]
        check("data_track is the first free track", res[0] == first_free, "got %d want %d" % (res[0], first_free))
        check("overlay 0 (two tracks) read", res[1] == 0 and res[2] == 1, str(list(res[:3])))
        check("overlay 2 read", res[3] == 0 and res[4] == 1, str(list(res[3:5])))
        check("overlay 1 read", res[5] == 0 and res[6] == 1, str(list(res[5:7])))
        check("sector written and read back", res[7] == 0 and res[8] == 0 and res[9] == 1, str(list(res[7:10])))
        check("a sector on the next track", res[10] == 0 and res[11] == 0 and res[12] == (200 + 1) & 255, str(list(res[10:13])))
        check("a sector that is not there is an error", res[13] == 0xff, str(res[13]))
        # the disc the program wrote: only the two sectors it wrote differ
        after = d88_sectors("mk2-disc.d88")
        changed = sorted(k for k in sectors if after.get(k) != sectors[k])
        check("only the sectors written changed", changed == [(res[0], 0, 1), (res[0] + 1, 0, 14)], str(changed))
        check("the sector's data", after[(res[0], 0, 1)] == bytes(i ^ 0x5a for i in range(256)))
    return 0 if ok else 1

if __name__ == "__main__":
    sys.exit(main())
