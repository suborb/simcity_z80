#!/usr/bin/env python3
"""z88dk's Multi 8 tape routines (libsrc/target/multi8/tape_save.asm and tape_load_to.asm) under z88dk-ticks.

The routines sit on five byte-level ones (tape_rx.asm and tape_tx.asm: the 8251 and the recorder's remote control),
which are replaced here by stubs: the transmit stubs record what is sent and the receive stubs play a stream with line
errors and ESC in it.  So this checks the format logic, not the ports (see the notes at the end).

tape_save must write what appmake writes: ':' address and its checksum, blocks of 255 with a ':', the length, the data
and a checksum, a short last block, and ':' 0 0.  tape_load_to reads that into a buffer whatever its address, drops what
does not fit, finds the file after noise, and fails on a bad checksum, a line error inside a file, or ESC.  Both are called
through every entry (assembler, smallc and callee) and the stack and the registers they are not to touch are checked.

  usage: test/multi8/tape.py          (the z88dk tree is $Z88DK, or ~/z88dk)
"""
import os
import random
import re
import subprocess
import sys
import tempfile

Z80ASM = 'z88dk-z80asm'
TICKS = 'z88dk-ticks'
LIB = os.path.join(os.environ.get('Z88DK', os.path.expanduser('~/z88dk')), 'libsrc', 'target', 'multi8')

DATA = 0x8000                  # the buffer saved from and loaded into
TXBUF = 0xA000                 # what the transmit stub was given
RXBUF = 0xB000                 # the receive stub's events: a word each, value then kind (0 byte, 1 line error, 2 ESC)

COMMON = '''        SECTION code_clib
        org     $0100
        PUBLIC  asm_tape_tx_start, asm_tape_tx_byte, asm_tape_tx_end, asm_tape_rx_init, asm_tape_rx_byte
        EXTERN  asm_tape_save, asm_tape_load_to, _tape_save, _tape_save_callee, _tape_load_to, _tape_load_to_callee
start:  ld      sp,$7000
        ld      hl,TXBUF
        ld      (txptr),hl
        ld      hl,RXBUF
        ld      (rxptr),hl
        ld      a,$AA
        ld      bc,$BBBB
        ld      de,$DDDD
%(body)s
fin:    halt

; ---- the stubs: like the real routines they keep everything but what is said
asm_tape_tx_start:
        ld      a,(starts)
        inc     a
        ld      (starts),a
        ld      bc,$5A5A                ; (the real one uses a, bc, de and hl)
        ld      de,$5A5A
        ld      hl,$5A5A
        ret
asm_tape_tx_byte:
        push    hl
        ld      hl,(txptr)
        ld      (hl),a
        inc     hl
        ld      (txptr),hl
        pop     hl
        ret
asm_tape_tx_end:
        ld      a,(ends)
        inc     a
        ld      (ends),a
        ld      bc,$5A5A
        ld      de,$5A5A
        ld      hl,$5A5A
        ret
asm_tape_rx_init:
        push    af
        ld      a,(inits)
        inc     a
        ld      (inits),a
        pop     af
        ret
asm_tape_rx_byte:                       ; uses only a and the flags
        push    hl
        ld      hl,(rxptr)
        ld      a,(hl)
        inc     hl
        ld      (rxkind),a              ; (the value; the kind is next)
        ld      a,(hl)
        inc     hl
        ld      (rxptr),hl
        pop     hl
        or      a
        jr      nz,rx_special
        ld      a,(rxkind)
        and     a                       ; nc
        ret
rx_special:
        cp      1
        ld      a,0
        jr      z,rx_err
        ld      a,1                     ; ESC
rx_err:
        scf
        ret
txptr:  defw    0
rxptr:  defw    0
rxkind: defb    0
starts: defb    0
ends:   defb    0
inits:  defb    0
res_hl: defw    0
res_c:  defb    0
res_sp: defw    0
res_bc: defw    0
res_de: defw    0
'''.replace('TXBUF', str(TXBUF)).replace('RXBUF', str(RXBUF))


def run(body, setup_mem, extra=''):
    """Assemble the harness with `body`, run it, return (memory, symbols)."""
    src = COMMON % {'body': body} + extra
    with tempfile.TemporaryDirectory() as tmp:
        open(os.path.join(tmp, 'h.asm'), 'w').write(src)
        files = [os.path.join(LIB, f) for f in ('tape_save.asm', 'tape_load_to.asm')]
        out = subprocess.run([Z80ASM, '-b', '-m', '-oh.bin', 'h.asm'] + files, cwd=tmp, capture_output=True, text=True)
        if out.returncode or out.stderr.strip():
            print(out.stdout + out.stderr)
            raise SystemExit('FAIL  does not assemble')
        syms = {}
        for line in open(os.path.join(tmp, 'h.map')):
            m = re.match(r'(\S+)\s+= \$([0-9A-F]+) ;', line)
            if m:
                syms[m.group(1)] = int(m.group(2), 16)
        img = bytearray(65536)
        code = open(os.path.join(tmp, 'h_code_clib.bin'), 'rb').read()   # (z80asm -b names the file after the section)
        img[0x100:0x100 + len(code)] = code
        for addr, data in setup_mem:
            img[addr:addr + len(data)] = data
        open(os.path.join(tmp, 'img.bin'), 'wb').write(img)
        subprocess.run([TICKS, '-pc', '100', '-end', f'{syms["fin"]:x}', '-counter', '100000000', '-output', 'mem.out',
                        'img.bin'], cwd=tmp, capture_output=True)
        return open(os.path.join(tmp, 'mem.out'), 'rb').read(), syms


def word(mem, a):
    return mem[a] | mem[a + 1] << 8


def expected_tape(addr, data):
    """What appmake's write_block writes."""
    out = bytearray([0x3A, addr >> 8, addr & 255, (-(addr >> 8) - (addr & 255)) & 255])
    pos = 0
    while len(data) - pos > 0:
        n = min(255, len(data) - pos)
        chunk = data[pos:pos + n]
        out += bytes([0x3A, n]) + chunk + bytes([(-(n + sum(chunk))) & 255])
        pos += n
    out += bytes([0x3A, 0, 0])
    return bytes(out)


def stream(data, addr=0x1234, junk=b'', mangle=None):
    """A tape file as the receive stub's events, with junk first; mangle(list of bytes) can change it."""
    raw = bytearray(junk) + bytearray(expected_tape(addr, data))
    if mangle:
        raw = mangle(raw)
    return raw


def events(raw, line_errors=(), esc_at=None):
    out = bytearray()
    for i, b in enumerate(raw):
        if i in line_errors:
            out += bytes([0, 1])
        else:
            out += bytes([b, 0])
    out += bytes([0, 2])            # ESC when the tape runs out, so nothing waits for ever
    return bytes(out)


def main():
    if not os.path.isdir(LIB):
        print(f'SKIP  no z88dk tree at {LIB}')
        return 0
    rng = random.Random(8251)
    ok = True

    # ---- tape_save through the assembler entry: the stream written is appmake's
    bad = []
    for n in (0, 1, 2, 253, 254, 255, 256, 257, 509, 510, 511, 1000, 3000):
        data = bytes(rng.randrange(256) for _ in range(n))
        for addr in (DATA, 0x80FF):
            body = f'''        ld      hl,{addr}
        ld      bc,{n}
        ld      de,$DDDD
        call    asm_tape_save
        ld      (res_hl),hl
        sbc     a,a
        ld      (res_c),a
        ld      (res_sp),sp
'''
            mem, syms = run(body, [(addr, data)], '')
            want = expected_tape(addr, data)
            got = bytes(mem[TXBUF:word(mem, syms['txptr'])])
            if got != want or word(mem, syms['res_hl']) != 0 or mem[syms['res_c']] != 0 or mem[syms['starts']] != 1 or mem[syms['ends']] != 1:
                bad.append(n)
            if word(mem, syms['res_sp']) != 0x7000:
                bad.append(('sp', n))
    print(('PASS' if not bad else 'FAIL') + f'  tape_save writes appmake\'s format for 13 lengths (0, 1, 254..257, 509..511, 1000, 3000), starts and ends the recorder once, returns 0'
          + (f' (bad: {bad})' if bad else ''))
    ok &= not bad

    # ---- the header address: any address, high byte first, with a checksum that makes the three add up to zero
    mem, syms = run(f'''        ld      hl,$12FF
        ld      bc,0
        call    asm_tape_save
''', [])
    got = bytes(mem[TXBUF:word(mem, syms['txptr'])])
    same = got == expected_tape(0x12FF, b'')
    print(('PASS' if same else 'FAIL') + f'  an empty file at $12FF is {got.hex()}')
    ok &= same

    # ---- the smallc and callee entries of tape_save: the arguments, the return value, the stack
    data = bytes(rng.randrange(256) for _ in range(300))
    for name, cleans in (('_tape_save', False), ('_tape_save_callee', True)):
        body = f'''        ld      hl,{DATA}
        push    hl
        ld      hl,300
        push    hl
        call    {name}
        ld      (res_hl),hl
        ld      (res_sp),sp
'''
        mem, syms = run(body, [(DATA, data)])
        got = bytes(mem[TXBUF:word(mem, syms['txptr'])])
        sp = word(mem, syms['res_sp'])
        good = got == expected_tape(DATA, data) and word(mem, syms['res_hl']) == 0 and sp == (0x7000 if cleans else 0x7000 - 4)
        print(('PASS' if good else 'FAIL') + f'  {name}(addr, len): the file, 0, and the stack is ' + ('popped' if cleans else 'left to the caller'))
        ok &= good

    # ---- tape_load_to: the file into a buffer
    def load(raw_events, cap, entry='asm_tape_load_to', fill=0xEE):
        if entry == 'asm_tape_load_to':
            body = f'''        ld      hl,{DATA}
        ld      bc,{cap}
        ld      de,$DDDD
        call    asm_tape_load_to
        ld      (res_hl),hl
        sbc     a,a
        ld      (res_c),a
        ld      (res_sp),sp
'''
        else:
            body = f'''        ld      hl,{DATA}
        push    hl
        ld      hl,{cap}
        push    hl
        call    {entry}
        ld      (res_hl),hl
        sbc     a,a
        ld      (res_c),a
        ld      (res_sp),sp
'''
        mem, syms = run(body, [(RXBUF, raw_events), (DATA, bytes([fill]) * 4200)])
        return mem, syms

    cases = []
    for n in (0, 1, 254, 255, 256, 510, 1000, 3000):
        data = bytes(rng.randrange(256) for _ in range(n))
        for cap in (n, n + 10, max(0, n - 1), n // 2, 0):
            cases.append((n, cap, data))
    bad = []
    for n, cap, data in cases:
        mem, syms = load(events(stream(data)), cap)
        stored = min(n, cap)
        good = (mem[syms['res_c']] == 0 and word(mem, syms['res_hl']) == stored and bytes(mem[DATA:DATA + stored]) == data[:stored]
                and all(b == 0xEE for b in mem[DATA + stored:DATA + 4200]) and word(mem, syms['res_sp']) == 0x7000)
        if not good:
            bad.append((n, cap))
    print(('PASS' if not bad else 'FAIL') + f'  tape_load_to stores min(file, buffer) bytes and no more, for {len(cases)} file and buffer sizes, with the stack balanced'
          + (f' (bad: {bad[:6]})' if bad else ''))
    ok &= not bad

    # ---- noise before the file, a line error before it (it listens again), ESC
    data = bytes(rng.randrange(256) for _ in range(600))
    junk = bytes(rng.randrange(256) for _ in range(40)).replace(b':', b'\x00')
    mem, syms = load(events(stream(data, junk=junk)), 600)
    good = mem[syms['res_c']] == 0 and word(mem, syms['res_hl']) == 600 and bytes(mem[DATA:DATA + 600]) == data
    print(('PASS' if good else 'FAIL') + '  tape_load_to skips noise before the file')
    ok &= good
    mem, syms = load(events(stream(data, junk=b'\x01\x02\x03'), line_errors={1}), 600)
    good = mem[syms['res_c']] == 0 and word(mem, syms['res_hl']) == 600 and mem[syms['inits']] == 2
    print(('PASS' if good else 'FAIL') + f'  a line error before the file restarts the receiver (rx_init called {mem[syms["inits"]]} times)')
    ok &= good

    # ---- failures: nothing is claimed to have been read
    def fails(name, raw_events, cap=600):
        nonlocal ok
        mem, syms = load(raw_events, cap)
        good = mem[syms['res_c']] != 0 and word(mem, syms['res_sp']) == 0x7000
        print(('PASS' if good else 'FAIL') + f'  tape_load_to fails: {name}')
        ok &= good

    fails('ESC with no file', bytes([0, 2]))
    fails('the tape ends in the middle of a block (ESC)', events(stream(data)[:300]))
    fails('a bad data checksum', events(stream(data, mangle=lambda r: r[:100] + bytearray([r[100] ^ 1]) + r[101:])))
    fails('a bad block checksum byte', events(stream(data, mangle=lambda r: r[:4 + 1 + 1 + 255] + bytearray([r[4 + 1 + 1 + 255] ^ 0x80]) + r[4 + 1 + 1 + 255 + 1:])))
    fails('a bad header checksum', events(stream(data, mangle=lambda r: bytearray([r[0], r[1], r[2], r[3] ^ 4]) + r[4:])))
    fails('a block that does not start with a colon', events(stream(data, mangle=lambda r: r[:4] + bytearray([0x3B]) + r[5:])))
    fails('a line error inside the file', events(stream(data), line_errors={50}))

    # ---- the smallc and callee entries of tape_load_to: -1 for failure, the count for success
    data = bytes(rng.randrange(256) for _ in range(300))
    for entry, cleans in (('_tape_load_to', False), ('_tape_load_to_callee', True)):
        mem, syms = load(events(stream(data)), 300, entry)
        sp = word(mem, syms['res_sp'])
        good = word(mem, syms['res_hl']) == 300 and bytes(mem[DATA:DATA + 300]) == data and sp == (0x7000 if cleans else 0x7000 - 4)
        print(('PASS' if good else 'FAIL') + f'  {entry}(buf, len) returns the count and ' + ('pops its arguments' if cleans else 'leaves them to the caller'))
        ok &= good
        mem, syms = load(bytes([0, 2]), 300, entry)
        good = word(mem, syms['res_hl']) == 0xFFFF and word(mem, syms['res_sp']) == (0x7000 if cleans else 0x7000 - 4)
        print(('PASS' if good else 'FAIL') + f'  {entry} returns -1 when it fails')
        ok &= good

    # ---- a file saved by tape_save is read back by tape_load_to
    data = bytes(rng.randrange(256) for _ in range(777))
    mem, syms = run(f'''        ld      hl,{DATA}
        ld      bc,777
        call    asm_tape_save
        ld      hl,TXBUF_
        ld      de,RXBUF_
copy:   ld      a,(hl)
        ld      (de),a
        inc     de
        xor     a
        ld      (de),a
        inc     de
        ld      a,(txptr)
        ld      c,a
        ld      a,l
        cp      c
        jr      nz,more
        ld      a,(txptr+1)
        cp      h
        jr      z,copied
more:   inc     hl
        jr      copy
copied: ld      a,2                     ; ESC after the file
        ld      (de),a
        ld      hl,RXBUF_
        ld      (rxptr),hl
        ld      hl,{DATA + 0x1000}
        ld      bc,2000
        call    asm_tape_load_to
        ld      (res_hl),hl
        sbc     a,a
        ld      (res_c),a
'''.replace('TXBUF_', str(TXBUF)).replace('RXBUF_', str(RXBUF + 0x800)), [(DATA, data)])
    good = mem[syms['res_c']] == 0 and word(mem, syms['res_hl']) == 777 and bytes(mem[DATA + 0x1000:DATA + 0x1000 + 777]) == data
    print(('PASS' if good else 'FAIL') + '  what tape_save writes, tape_load_to reads back (777 bytes, through the stubs)')
    ok &= good
    return 0 if ok else 1


if __name__ == '__main__':
    sys.exit(main())
