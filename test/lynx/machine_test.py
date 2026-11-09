#!/usr/bin/env python3
"""z88dk's Lynx 128K model (lib/ticks/memory/lynx.lua) itself, with the sequences the game uses: the drawing window ($82 = $C8: a write goes to the video planes at the same address and the
user RAM is read), the screen copy that reads the planes (VCOPY: a RAM half sets $82 = $0E and carries on in the alternate green plane, where `ldir; ld a,8; out ($82),a` is, and the
copy is written to user RAM), the screen as pixels (the red, blue and green planes, the green one alternate with port $80 bit 4), the frame interrupt (ticks -int 120000: IM 1 at
$0038, EI; HALT waits for it) and the keyboard lines (a key goes down at a cycle count: LYNX_KEYS).
"""
import os, subprocess, sys, tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
CFG = os.environ.get('ZCCCFG', os.path.expanduser('~/z88dk/lib/config'))
MODEL = os.path.join(CFG, '..', 'ticks', 'memory', 'lynx.lua')

PLANES = """
        org     $2000
start:  ld      sp,$7000
        ; the stub of VCOPY, as the game has it: the RAM half at $FC00, the plane's half at $FC04 of the alternate green plane
        ld      hl,vc_ram
        ld      de,$FC00
        ld      bc,4
        ldir
        ld      a,$C9
        ld      ($FC0A),a
        ld      a,$C8
        out     ($82),a                 ; the drawing window: from here the stores go to the planes (no stack)
        ld      a,$81                   ; red pixel 0 of the picture's first row ($0100), blue pixel 1, green 2
        ld      ($0100),a
        ld      a,$44
        ld      ($4100),a
        ld      a,$28
        ld      ($8100),a
        ld      hl,vc_plane             ; and the plane's half of the stub, written through the window
        ld      de,$FC04
        ld      bc,6
        ldir
        ld      a,$5A
        ld      ($C200),a               ; a byte of the alternate green plane to copy back
        ld      a,$08
        out     ($82),a                 ; user RAM again
        ld      a,$77
        ld      ($0100),a               ; (this goes to RAM only: the red plane keeps $81)
        ld      hl,$C200                ; VCOPY: hl = the video address, de = the RAM destination, bc = the count
        ld      de,$3000
        ld      bc,1
        call    $FC00
        ld      hl,$0100                ; and the red plane's byte
        ld      de,$3001
        ld      bc,1
        call    $FC00
        ld      a,3
        out     ($F0),a                 ; the logs, the screen and the planes
done:   jp      done
vc_ram: defb    $3E,$0E,$D3,$82         ; ld a,$0E ; out ($82),a
vc_plane: defb  $ED,$B0,$3E,$08,$D3,$82 ; ldir ; ld a,8 ; out ($82),a
"""

FRAMES = """
        org     $2000
start:  ld      sp,$7000
        ld      a,$C3
        ld      ($0038),a
        ld      hl,isr
        ld      ($0039),hl
        im      1
        ei
        halt
        halt
        halt
        halt
        halt
        di
        ld      a,(count)
        ld      ($3F00),a
        ld      a,1
        out     ($F0),a
done:   jp      done
isr:    push    af
        ld      a,(count)
        inc     a
        ld      (count),a
        pop     af
        ei
        reti
count:  defb    0
"""

KEYS = """
        org     $2000
start:  ld      sp,$7000
        ld      hl,$3000
        ld      bc,$0080                ; line 0 ... 9: a row each, read now and again after the wait
rd1:    in      a,(c)
        ld      (hl),a
        inc     hl
        inc     b
        ld      a,b
        cp      10
        jr      nz,rd1
        ld      de,0
wait:   dec     de                      ; (1.7 million T-states)
        ld      a,d
        or      e
        jr      nz,wait
        ld      hl,$3010
        ld      b,0
rd2:    in      a,(c)
        ld      (hl),a
        inc     hl
        inc     b
        ld      a,b
        cp      10
        jr      nz,rd2
        ld      a,1
        out     ($F0),a
done:   jp      done
"""


def run(source, env=None, extra=()):
    with tempfile.TemporaryDirectory() as tmp:
        open(os.path.join(tmp, 'h.asm'), 'w').write(source)
        r = subprocess.run(['z88dk-z80asm', '-b', '-m', os.path.join(tmp, 'h.asm')], capture_output=True, text=True)
        if r.returncode:
            sys.exit(r.stdout + r.stderr)
        img = open(os.path.join(tmp, 'h.bin'), 'rb').read()
        open(os.path.join(tmp, 'img.bin'), 'wb').write(bytes(0x2000) + img)
        done = [l for l in open(os.path.join(tmp, 'h.map')) if l.startswith('done ')][0].split('$')[1][:4]
        r = subprocess.run(['z88dk-ticks', '-b', 'lua', '-lua', MODEL, '-pc', '2000', '-end', done, '-counter', '100000000', *extra, '-output', os.path.join(tmp, 'mem.out'),
                            os.path.join(tmp, 'img.bin')], capture_output=True, text=True, cwd=tmp, env=dict(os.environ, ZCCCFG=CFG, LYNX_OUTDIR=tmp, **(env or {})))
        mem = open(os.path.join(tmp, 'mem.out'), 'rb').read() if os.path.exists(os.path.join(tmp, 'mem.out')) else b''
        files = {}
        for f in ('lynx-screen.ppm', 'lynx-planes.bin'):
            if os.path.exists(os.path.join(tmp, f)):
                files[f] = open(os.path.join(tmp, f), 'rb').read()
        return mem, files, r.stdout + r.stderr


def main():
    bad = 0

    def check(n, c, x=''):
        nonlocal bad
        print(('ok   ' if c else 'FAIL ') + n + ('' if c else '  ' + str(x)))
        bad += not c

    mem, files, out = run(PLANES)
    planes = files.get('lynx-planes.bin', b'')
    if not planes:
        sys.exit('no planes:\n' + out)
    red, blue, green, alt = (planes[i * 16384:(i + 1) * 16384] for i in range(4))
    check('a write in the window ($C8) goes to the red plane at the same address', red[0x100] == 0x81, hex(red[0x100]))
    check('... to the blue plane ($4100)', blue[0x100] == 0x44, hex(blue[0x100]))
    check('... to the green plane ($8100)', green[0x100] == 0x28, hex(green[0x100]))
    check('... to the alternate green plane ($C200)', alt[0x200] == 0x5A, hex(alt[0x200]))
    check('a write in the window does not reach the user RAM', mem[0x4100] == 0 and mem[0x8100] == 0 and mem[0xC200] == 0, (hex(mem[0x4100]), hex(mem[0xC200])))
    check('a write in $08 reaches the user RAM ($0100 = $77), and not the red plane', mem[0x0100] == 0x77 and red[0x100] == 0x81)
    check('VCOPY: the alternate green byte came back into RAM ($3000)', mem[0x3000] == 0x5A, hex(mem[0x3000]))
    check('VCOPY: the red byte came back too ($3001: the plane\'s $81, not the RAM\'s $77)', mem[0x3001] == 0x81, hex(mem[0x3001]))
    ppm = files['lynx-screen.ppm']
    head = b'P6\n512 252\n255\n'
    px = lambda x, y: tuple(ppm[len(head) + (y * 512 + x) * 3:len(head) + (y * 512 + x) * 3 + 3])
    check('the screen: $81 red = pixels 0 and 7 red, $44 blue = pixels 1 and 5, $28 green = pixels 2 and 4 (colours added: pixel 7 red)', px(0, 0) == (255, 0, 0) and px(7, 0) == (255, 0, 0) and px(1, 0) == (0, 0, 255) and px(2, 0) == (0, 255, 0) and px(3, 0) == (0, 0, 0),
          [px(i, 0) for i in range(8)])

    mem, files, out = run(FRAMES, extra=('-int', '120000'))
    check('the frame interrupt: five HALTs, five interrupts', mem[0x3F00] == 5, mem[0x3F00])

    # shift is down from the start, A goes down at 200000 cycles (the first reads are at about 100: before it; the wait is 1.7 million: the second reads are after it) and up at 9 million
    mem, files, out = run(KEYS, env={'LYNX_KEYS': '0:shift:1,200000:a:1,9000000:a:0'})
    first, second = mem[0x3000:0x300A], mem[0x3010:0x301A]
    check('keyboard: nothing but shift (line 0 bit 7) down at the first read', first[0] == 0x7F and all(b == 0xFF for b in first[1:]), first.hex())
    check('keyboard: A (line 2 bit 5) down at the second read, shift still down', second[2] == 0xDF and second[0] == 0x7F, second.hex())
    print('FAILED' if bad else 'all ok')
    return 1 if bad else 0


if __name__ == '__main__':
    sys.exit(main())
