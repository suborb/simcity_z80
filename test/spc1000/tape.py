#!/usr/bin/env python3
"""Host test of z88dk's SPC-1000 cassette driver (libsrc/target/spc1000/tape_io.asm, tape_save.asm, tape_load_to.asm).

A small Z80 interpreter (only what the driver uses) runs tape_save and tape_load_to with a cassette modelled on the machine's ports:
  $6000 write: bit 0 the output, bit 1 the motor (each rising edge toggles it), bit 6 of port A at $4001 (register 14) says the motor is
  stopped, bit 7 of it is the tape level (the inverse of the output, as the ROM's own save and MAME's .cas have it), and the tape only
  moves while the motor is on.
It checks (1) the waveform tape_save makes, decoded by pulse widths, is the ROM's format (leader, start bits, checksum, second copy), and
(2) tape_load_to reads it back: the data and the program's own header bytes, a file with another name is passed over, a bit flipped in the
first copy is mended by the second.  usage: test/spc1000/tape.py   (a minute or so)"""
import os, re, subprocess, sys, bisect, random
ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
OUT = os.path.join(ROOT, 'build', 'spc1000tape')
LIB = os.path.expanduser('~/z88dk/libsrc/target/spc1000')
SENT = 0x1F00

class Tape:
    def __init__(self):
        self.changes = [(0, 0)]       # (tape time, output bit 0)
        self.motor = False
        self.pos = 0                  # tape time: T-states the motor has been on
    def level(self, pos):             # the tape's level at a tape time (the inverse of the output)
        i = bisect.bisect_right(self.changes, (pos, 2)) - 1
        return 1 - self.changes[i][1]

class Z80:
    def __init__(self, mem, tape, fast):
        self.m = mem
        self.tape = tape
        self.r = {'a': 0, 'b': 0, 'c': 0, 'd': 0, 'e': 0, 'h': 0, 'l': 0}
        self.f = 0                    # flags as a byte: S Z - H - P N C
        self.sp = 0xF000
        self.pc = 0
        self.t = 0
        self.iff = 1
        self.sel = 0
        self.reg7 = 0xff
        self.fast = fast              # the address of `delay`: the loop is run in one go
        self.last_motor_t = 0

    # -- the machine
    def tick(self, n):
        if self.tape.motor:
            self.tape.pos += n
        self.t += n
    def in_port(self, port):
        if port == 0x4001:
            if self.sel == 14:
                return 0x3f | (0x80 if self.tape.level(self.tape.pos) else 0) | (0 if self.tape.motor else 0x40)
            if self.sel == 7:
                return self.reg7
            return 0xff
        if port == 0x8000:
            return 0xff
        return 0xff
    def out_port(self, port, v):
        if port == 0x6000:
            if (v & 1) != self.tape.changes[-1][1]:
                self.tape.changes.append((self.tape.pos, v & 1))
            was = getattr(self, 'p6000', 0)
            if v & 2 and not was & 2:
                self.tape.motor = not self.tape.motor
            self.p6000 = v
        elif port == 0x4000:
            self.sel = v
        elif port == 0x4001 and self.sel == 7:
            self.reg7 = v

    # -- registers
    def rd(self, a): return self.m[a & 0xffff]
    def wr(self, a, v): self.m[a & 0xffff] = v & 0xff
    def rd16(self, a): return self.rd(a) | self.rd(a + 1) << 8
    def wr16(self, a, v): self.wr(a, v); self.wr(a + 1, v >> 8)
    def get16(self, hi, lo): return self.r[hi] << 8 | self.r[lo]
    def set16(self, hi, lo, v): self.r[hi] = (v >> 8) & 0xff; self.r[lo] = v & 0xff
    def push(self, v): self.sp = (self.sp - 2) & 0xffff; self.wr16(self.sp, v)
    def pop(self):
        v = self.rd16(self.sp); self.sp = (self.sp + 2) & 0xffff; return v
    def fetch(self):
        v = self.rd(self.pc); self.pc = (self.pc + 1) & 0xffff; return v
    def fetch16(self):
        lo = self.fetch(); return lo | self.fetch() << 8

    # -- flags
    def szp(self, v):
        v &= 0xff
        return (v & 0x80) | (0x40 if v == 0 else 0) | (0x04 if bin(v).count('1') % 2 == 0 else 0)
    def alu(self, op, b):
        a = self.r['a']
        if op in (0, 2):            # add, sub (via 2)
            pass
        if op == 0:
            res = a + b; self.f = self.szp(res) & ~4 | (res >> 8 & 1) | ((a ^ b ^ res) & 0x10) | (0x04 if (~(a ^ b) & (a ^ res) & 0x80) else 0)
            self.r['a'] = res & 0xff
        elif op in (2, 7):           # sub, cp
            res = a - b; self.f = (self.szp(res) & ~4) | 2 | (1 if res < 0 else 0) | ((a ^ b ^ res) & 0x10) | (0x04 if ((a ^ b) & (a ^ res) & 0x80) else 0)
            if op == 2: self.r['a'] = res & 0xff
        elif op == 4:
            self.r['a'] = a & b; self.f = self.szp(a & b) | 0x10
        elif op == 5:
            self.r['a'] = a ^ b; self.f = self.szp(a ^ b)
        elif op == 6:
            self.r['a'] = a | b; self.f = self.szp(a | b)
        else:
            raise SystemExit('alu %d' % op)
    def cond(self, c):
        f = self.f
        return [not f & 0x40, bool(f & 0x40), not f & 1, bool(f & 1), not f & 4, bool(f & 4), not f & 0x80, bool(f & 0x80)][c]

    REGS = ['b', 'c', 'd', 'e', 'h', 'l', None, 'a']
    def getr(self, i):
        n = self.REGS[i]
        return self.r[n] if n else self.rd(self.get16('h', 'l'))
    def setr(self, i, v):
        n = self.REGS[i]
        if n: self.r[n] = v & 0xff
        else: self.wr(self.get16('h', 'l'), v)
    PAIRS = [('b', 'c'), ('d', 'e'), ('h', 'l'), None]
    def getp(self, i): return self.sp if i == 3 else self.get16(*self.PAIRS[i])
    def setp(self, i, v):
        v &= 0xffff
        if i == 3: self.sp = v
        else: self.set16(*self.PAIRS[i], v)

    def step(self):
        pc0 = self.pc
        if pc0 == self.fast:         # delay: dec a / jp nz / ret, in one go
            n = self.r['a'] or 256
            self.tick(14 * n - 4 + 10)   # (the last jp is the same 10 states taken or not)
            self.r['a'] = 0
            self.f = (self.f & 1) | 0x40 | 2
            self.pc = (pc0 + 4) & 0xffff   # the ret
            return
        op = self.fetch()
        r = self.r
        if op == 0x00: self.tick(4)
        elif op & 0xc7 == 0x06:      # ld r,n
            d = (op >> 3) & 7; self.setr(d, self.fetch()); self.tick(10 if d == 6 else 7)
        elif op & 0xcf == 0x01:      # ld rr,nn
            self.setp(op >> 4 & 3, self.fetch16()); self.tick(10)
        elif op & 0xc0 == 0x40:      # ld r,r
            if op == 0x76: raise SystemExit('halt')
            d, s = (op >> 3) & 7, op & 7; self.setr(d, self.getr(s)); self.tick(7 if 6 in (d, s) else 4)
        elif op & 0xc7 == 0x04 or op & 0xc7 == 0x05:   # inc/dec r
            d = (op >> 3) & 7; v = self.getr(d); inc = op & 1 == 0
            res = (v + 1 if inc else v - 1) & 0xff
            self.f = (self.f & 1) | (self.szp(res) & ~4) | (0 if inc else 2) | ((v ^ res) & 0x10) | (0x04 if res == (0x80 if inc else 0x7f) else 0)
            self.setr(d, res); self.tick(11 if d == 6 else 4)
        elif op & 0xcf == 0x03: self.setp(op >> 4 & 3, self.getp(op >> 4 & 3) + 1); self.tick(6)
        elif op & 0xcf == 0x0b: self.setp(op >> 4 & 3, self.getp(op >> 4 & 3) - 1); self.tick(6)
        elif op & 0xc0 == 0x80:      # alu a,r
            self.alu((op >> 3) & 7, self.getr(op & 7)); self.tick(7 if op & 7 == 6 else 4)
        elif op & 0xc7 == 0xc6:      # alu a,n
            self.alu((op >> 3) & 7, self.fetch()); self.tick(7)
        elif op == 0x0a: r['a'] = self.rd(self.get16('b', 'c')); self.tick(7)
        elif op == 0x1a: r['a'] = self.rd(self.get16('d', 'e')); self.tick(7)
        elif op == 0x12: self.wr(self.get16('d', 'e'), r['a']); self.tick(7)
        elif op == 0x3a: r['a'] = self.rd(self.fetch16()); self.tick(13)
        elif op == 0x32: self.wr(self.fetch16(), r['a']); self.tick(13)
        elif op == 0x2a: self.set16('h', 'l', self.rd16(self.fetch16())); self.tick(16)
        elif op == 0x22: self.wr16(self.fetch16(), self.get16('h', 'l')); self.tick(16)
        elif op == 0x07:             # rlca
            a = r['a']; c = a >> 7; r['a'] = (a << 1 | c) & 0xff; self.f = (self.f & 0xc4) | c; self.tick(4)
        elif op == 0x17:             # rla
            a = r['a']; c = a >> 7; r['a'] = (a << 1 | (self.f & 1)) & 0xff; self.f = (self.f & 0xc4) | c; self.tick(4)
        elif op == 0x37: self.f = (self.f & 0xc4) | 1; self.tick(4)
        elif op == 0xeb:
            d, e, h, l = r['d'], r['e'], r['h'], r['l']; r['d'], r['e'], r['h'], r['l'] = h, l, d, e; self.tick(4)
        elif op == 0x09 or op == 0x19 or op == 0x29 or op == 0x39:   # add hl,rr
            hl = self.get16('h', 'l'); v = hl + self.getp(op >> 4 & 3)
            self.f = (self.f & 0xc4) | (v >> 16 & 1); self.set16('h', 'l', v); self.tick(11)
        elif op & 0xcf == 0xc5: self.push(self.get16(*self.PAIRS[op >> 4 & 3]) if op != 0xf5 else r['a'] << 8 | self.f); self.tick(11)
        elif op == 0xf5: self.push(r['a'] << 8 | self.f); self.tick(11)
        elif op == 0xf1:
            v = self.pop(); r['a'] = v >> 8; self.f = v & 0xff; self.tick(10)
        elif op & 0xcf == 0xc1: self.set16(*self.PAIRS[op >> 4 & 3], self.pop()); self.tick(10)
        elif op == 0x18: d = self.fetch(); self.pc = (self.pc + (d - 256 if d > 127 else d)) & 0xffff; self.tick(12)
        elif op & 0xe7 == 0x20:      # jr cc
            d = self.fetch()
            if self.cond((op >> 3) & 3): self.pc = (self.pc + (d - 256 if d > 127 else d)) & 0xffff; self.tick(12)
            else: self.tick(7)
        elif op == 0x10:
            d = self.fetch(); r['b'] = (r['b'] - 1) & 0xff
            if r['b']: self.pc = (self.pc + (d - 256 if d > 127 else d)) & 0xffff; self.tick(13)
            else: self.tick(8)
        elif op == 0xc3: self.pc = self.fetch16(); self.tick(10)
        elif op & 0xc7 == 0xc2:
            a = self.fetch16()
            if self.cond((op >> 3) & 7): self.pc = a
            self.tick(10)
        elif op == 0xcd: a = self.fetch16(); self.push(self.pc); self.pc = a; self.tick(17)
        elif op & 0xc7 == 0xc4:
            a = self.fetch16()
            if self.cond((op >> 3) & 7): self.push(self.pc); self.pc = a; self.tick(17)
            else: self.tick(10)
        elif op == 0xc9: self.pc = self.pop(); self.tick(10)
        elif op & 0xc7 == 0xc0:
            if self.cond((op >> 3) & 7): self.pc = self.pop(); self.tick(11)
            else: self.tick(5)
        elif op == 0xdb:             # in a,(n)
            n = self.fetch(); r['a'] = self.in_port(r['a'] << 8 | n); self.tick(11)
        elif op == 0xf3: self.iff = 0; self.tick(4)
        elif op == 0xfb: self.iff = 1; self.tick(4)
        elif op == 0xcb:
            o = self.fetch(); b = (o >> 3) & 7; n = o & 7; v = self.getr(n)
            if o & 0xc0 == 0xc0: v |= 1 << b
            elif o & 0xc0 == 0x80: v &= ~(1 << b)
            else: raise SystemExit('cb %02x' % o)
            self.setr(n, v); self.tick(8)
        elif op == 0xed:
            o = self.fetch()
            if o == 0x57: r['a'] = 0; self.f = (self.f & 1) | (0x04 if self.iff else 0) | 0x40; self.tick(9)   # ld a,i (i = 0)
            elif o == 0x79: self.out_port(self.get16('b', 'c'), r['a']); self.tick(12)
            elif o & 0xcf == 0x43: self.wr16(self.fetch16(), self.getp(o >> 4 & 3)); self.tick(20)
            elif o & 0xcf == 0x4b: self.setp(o >> 4 & 3, self.rd16(self.fetch16())); self.tick(20)
            elif o == 0x42:          # sbc hl,bc
                hl = self.get16('h', 'l'); v = self.getp(o >> 4 & 3); res = hl - v - (self.f & 1)
                self.f = (0x80 if res & 0x8000 else 0) | (0x40 if res & 0xffff == 0 else 0) | 2 | (1 if res < 0 else 0)
                self.set16('h', 'l', res); self.tick(15)
            elif o == 0xb0:          # ldir
                while True:
                    self.wr(self.get16('d', 'e'), self.rd(self.get16('h', 'l')))
                    self.set16('h', 'l', self.get16('h', 'l') + 1); self.set16('d', 'e', self.get16('d', 'e') + 1)
                    bc = (self.get16('b', 'c') - 1) & 0xffff; self.set16('b', 'c', bc)
                    if bc: self.tick(21)
                    else: self.tick(16); break
                self.f &= ~0x04
            else: raise SystemExit('ed %02x at %04x' % (o, pc0))
        else:
            raise SystemExit('opcode %02x at %04x' % (op, pc0))

    def run(self, pc, limit=3_000_000_000):
        self.pc = pc
        while self.pc != SENT:
            self.step()
            if self.t > limit: raise SystemExit('too long')

def build():
    os.makedirs(OUT, exist_ok=True)
    open(os.path.join(OUT, 'h.asm'), 'w').write('\tSECTION code_clib\n\torg\t$2000\n\tnop\n')
    subprocess.run(['z88dk-z80asm', '-b', '-m', '-o=h.bin', 'h.asm'] + [os.path.join(LIB, f) for f in ('tape_io.asm', 'tape_save.asm', 'tape_load_to.asm')], cwd=OUT, check=True)
    code = open(os.path.join(OUT, 'h_code_clib.bin'), 'rb').read()
    syms = {n: int(a, 16) for n, a in re.findall(r'^(\w+)\s*= \$([0-9A-Fa-f]+) ;', open(os.path.join(OUT, 'h.map')).read(), re.M)}
    return code, syms

def call(cpu, addr, args):
    """a smallc call: the arguments pushed left to right, then the return address (SENT)"""
    cpu.sp = 0xF000
    for a in args:
        cpu.push(a)
    cpu.push(SENT)
    cpu.run(addr)
    cpu.sp += 2 * len(args) + 2
    cpu.sp &= 0xffff
    return cpu.get16('h', 'l')

def decode(tape):
    """the bits of the tape by the widths of the pulses (the output's high phase: ~840 states a zero, ~1680 a one), with the time the motor ran"""
    ch = tape.changes
    bits = []
    for i in range(len(ch) - 1):
        if ch[i][1] == 1:
            w = ch[i + 1][0] - ch[i][0]
            bits.append(1 if w > 1200 else 0)
    return bits

def check_format(bits, fcb, payload):
    """the first file of the tape against the ROM's format: for the header block and the data block, a leader (zero bits, `ones` ones, `ones` zeros and a one), the
    bytes each as a one bit and eight, the checksum (the one bits of the data) as two bytes, a one bit, 256 zero bits and the same all again"""
    pos = 0
    def leader(zeros, ones):
        nonlocal pos
        n = 0
        while bits[pos] == 0: pos += 1; n += 1
        assert n == zeros, 'leader zeros %d, not %d' % (n, zeros)
        for _ in range(ones): assert bits[pos] == 1; pos += 1
        for _ in range(ones): assert bits[pos] == 0; pos += 1
        assert bits[pos] == 1; pos += 1             # the leader's last one bit
    def byte():
        nonlocal pos
        assert bits[pos] == 1, 'start bit'; pos += 1
        v = 0
        for _ in range(8): v = v << 1 | bits[pos]; pos += 1
        return v
    def block(data):
        nonlocal pos
        ones = sum(bin(b).count('1') for b in data)
        for copy in range(2):
            assert bytes(byte() for _ in data) == bytes(data), 'copy %d differs' % copy
            assert byte() << 8 | byte() == ones, 'checksum'
            assert bits[pos] == 1; pos += 1         # the end bit
            if copy == 0:
                for _ in range(256): assert bits[pos] == 0; pos += 1
    leader(22000, 40)
    block(fcb)
    leader(11000, 20)
    block(payload)
    return pos

def main():
    random.seed(1)
    code, syms = build()
    mem = bytearray(65536)
    mem[0x2000:0x2000 + len(code)] = code
    tape = Tape()
    cpu = Z80(mem, tape, syms['delay'])
    data = bytes(random.randrange(256) for _ in range(200))
    user = bytes(random.randrange(256) for _ in range(31))
    mem[0x9000:0x9000 + len(data)] = data
    mem[0xA000:0xA000 + len(user)] = user
    for i, c in enumerate(b'CITY\0'): mem[0x8000 + i] = c
    for i, c in enumerate(b'OTHER\0'): mem[0x8100 + i] = c
    # a file named OTHER first, then CITY
    print('saving OTHER ...', flush=True)
    r = call(cpu, syms['_tape_save'], [0x8100, 0x9000, 20, 0, 0])
    assert r == 0, r
    print('saving CITY ...', flush=True)
    r = call(cpu, syms['_tape_save'], [0x8000, 0x9000, len(data), 0xA000, len(user)])
    assert r == 0, r
    bits = decode(tape)
    print('tape: %d bits, %.1f s of motor; the motor is %s' % (len(bits), tape.pos / 4e6, 'on' if tape.motor else 'off'))
    assert not tape.motor
    zeros = 0
    while bits[zeros] == 0: zeros += 1
    print('header leader zeros', zeros)
    assert zeros == 22000
    fcb = bytearray(128)
    fcb[0] = 1
    fcb[1:6] = b'OTHER'
    fcb[0x12:0x14] = (20).to_bytes(2, 'little')
    fcb[0x14:0x16] = (0x9000).to_bytes(2, 'little')
    end = check_format(bits, fcb, data[:20])
    print('the first file is the ROM format, %d bits' % end)
    saved = list(tape.changes)
    def fresh():
        t = Tape(); t.changes = saved; t.pos = 0
        c = Z80(mem, t, syms['delay']); c.p6000 = 0
        return c, t
    for a in range(0xB000, 0xB400): mem[a] = 0
    for a in range(0xC000, 0xC040): mem[a] = 0
    cpu, t = fresh()
    print('loading CITY (passing OTHER) ...', flush=True)
    r = call(cpu, syms['_tape_load_to'], [0x8000, 0xB000, 400, 0xC000, 31])
    print('returned', r)
    assert r == len(data), r
    assert bytes(mem[0xB000:0xB000 + len(data)]) == data, 'data'
    assert bytes(mem[0xC000:0xC000 + 31]) == user, 'user bytes'
    assert not t.motor
    # a buffer smaller than the file: the rest is dropped
    for a in range(0xB000, 0xB400): mem[a] = 0
    cpu, t = fresh()
    print('loading CITY into a short buffer ...', flush=True)
    r = call(cpu, syms['_tape_load_to'], [0x8000, 0xB000, 50, 0, 0])
    assert r == 50, r
    assert bytes(mem[0xB000:0xB000 + 50]) == data[:50] and mem[0xB000 + 50] == 0
    # any name: the first file (OTHER, 20 bytes)
    cpu, t = fresh()
    print('loading the first file ...', flush=True)
    r = call(cpu, syms['_tape_load_to'], [0, 0xB000, 400, 0, 0])
    assert r == 20, r
    # a bit flipped in the first copy of the header and in the first copy of the data: the second copies are read
    ch = saved
    hi, per = {0: [], 1: []}, {0: [], 1: []}
    for i in range(len(ch) - 2):
        if ch[i][1] == 1:
            b = 1 if ch[i + 1][0] - ch[i][0] > 1200 else 0
            hi[b].append(ch[i + 1][0] - ch[i][0]); per[b].append(ch[i + 2][0] - ch[i][0])
    avg = lambda l: sum(l) // len(l)
    flipped = list(bits)
    first = 22000 + 81 + 9 * 10 + 4                 # a bit in the header's tenth byte
    data_first = 22000 + 81 + 2 * (130 * 9) + 2 + 256 + 11000 + 41 + 9 * 3 + 4   # a bit in the data's fourth byte
    for k in (first, data_first):
        flipped[k] ^= 1
    t, changes = 0, [(0, 0)]
    for b in flipped:
        changes += [(t, 1), (t + avg(hi[b]), 0)]
        t += avg(per[b])
    bad = Tape(); bad.changes = changes
    cpu = Z80(mem, bad, syms['delay']); cpu.p6000 = 0
    for a in range(0xB000, 0xB400): mem[a] = 0
    print('loading the first file with a bit flipped in each block ...', flush=True)
    r = call(cpu, syms['_tape_load_to'], [0, 0xB000, 400, 0, 0])
    assert r == 20 and bytes(mem[0xB000:0xB014]) == data[:20], (r, bytes(mem[0xB000:0xB014]).hex())
    print('ok')

if __name__ == '__main__':
    main()
