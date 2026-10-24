#!/usr/bin/env python3
"""Boot the real Z88 card image (build/z88rom/simcity.epr) under z88dk-ticks with OZ stubbed.

Not OZ and not a Z88: the card image is loaded flat at 0x8000 (so no bank switching), RAM is
zero from 0x2000 up as OZ would give it, and the stack starts just below the app's safe
workspace.  RST 20h, which every OZ call goes through, is a stub that skips the call's
operand bytes and answers the few calls that matter:

    os_tin ($2D)  returns the next key of a script (first the level choice '2'), then "no key"
    os_in  ($2A)  returns 0
    os_bye ($21)  stops
    everything else (screen output, window setup, error handler...) just succeeds

Not covered, because the stub does not have them: bank switching, OZ's interrupts, its stack and
register rules (the Developer Notes say the application stack is in the 2K area $1800-$2000 shared
with workspaces and the system, and that OZ calls corrupt the alternate registers).

What it exercises is the application's own start-up code (clear the BSS, copy the initial
data from ROM to RAM, call main), the title screen, the choice of level and the landscape
generator, with the code in ROM at its real addresses.  The check afterwards is that the
game got past the landscape into its main loop, the map looks like a landscape, and nothing
below the RAM was written.

  usage: test/z88/boot.py [--cycles N]       (builds `make z88rom` first)
"""
import os
import re
import subprocess
import sys
import tempfile

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
BUILD = os.path.join(ROOT, 'build', 'z88rom')
KEYS = bytes([ord('2')])            # the level choice; the city name prompt is OZ's GN_Sip, which the stub answers with an empty line
SP_START = 0x1F80                   # just below the safe workspace (0x1F85..0x1FFC)
OUT_END = 0x0F00                    # the capture buffer is OUT..OUT_END; the stub's variables and the stack are above
VARS, SCRIPT, OUT = 0x1000, 0x1100, 0x0800     # the stub's variables, the key script, and the captured os_out text (RAM below the app)

STUB = f'''
        org     $0000
        jp      stop                    ; a jump to 0 (a wild return) stops the run
        defs    $0008-ASMPC
        jp      stop                    ; RST 8: the unused ROM space is filled with it, so running into it stops the run
        defs    $0020-ASMPC               ; the RST $20 vector
        jp      oz20
        defs    $0038-ASMPC               ; the interrupt vector
        jp      isr
        defs    $0051-ASMPC               ; OZ_DI: disable interrupts, return the previous state in AF
        jp      ozdi
        defs    $0054-ASMPC               ; OZ_EI: restore the state OZ_DI returned
        jp      ozei
        defs    $0200-ASMPC
start:  ld      sp,${SP_START:04x}
        ld      ix,$1200                ; OZ gives the app a table: byte 2 = pages of bad memory it got
        ld      hl,$1200
        ld      (hl),0
        inc     hl
        ld      (hl),0
        inc     hl
        ld      (hl),200
        xor     a
        ld      (${VARS:04x}),a            ; key script index
        ld      hl,${OUT:04x}
        ld      (${VARS+8:04x}),hl         ; capture pointer
        im      1
        ei                              ; OZ runs applications with interrupts on
        jp      $8000                   ; app_entrypoint

ozdi:   push    hl
        ld      hl,${VARS+18:04x}
        inc     (hl)                    ; calls to OZ_DI
        pop     hl
        ld      a,i                     ; P/V = the interrupt flip-flop (as on a real Z80)
        push    af
        di
        pop     af
        ret
ozei:   push    af
        jp      po,eioff                ; (state from OZ_DI: P/V clear = interrupts were off)
        pop     af
        ei
        ret
eioff:  pop     af
        ret

; An OZ interrupt.  OZ's interrupt handling needs the stack to be in the system area (below $2000: the
; application stack is in the 2K at $1800-$2000), so an interrupt that arrives with SP at $2000 or above
; (such as while the simulation runs on its own stack in application RAM) crashes it.  Record any.
isr:    push    af
        push    hl
        ld      hl,4+2                  ; SP at the interrupt = SP now + AF + HL + the return address
        add     hl,sp
        ld      a,h
        cp      $20
        jr      c,isrok
        ld      a,(${VARS+12:04x})
        inc     a
        jr      z,isrok                 ; (count, saturating)
        ld      (${VARS+12:04x}),a
        ld      (${VARS+14:04x}),hl        ; the last offending SP
isrok:  ld      a,(${VARS+16:04x})
        inc     a
        ld      (${VARS+16:04x}),a         ; interrupts seen (low byte)
        pop     hl
        pop     af
        ei
        reti

; every OZ call is  rst $20 ; defb call  (or defb prefix,hi for GN_/DC_ calls: prefixes 6, 9, $C)
oz20:   ld      (${VARS+10:04x}),a         ; keep the caller's A (os_out's character)
        ld      (${VARS+2:04x}),hl         ; keep the caller's HL
        pop     hl                      ; -> the operand byte(s)
        xor     a
        ld      (${VARS+5:04x}),a          ; the second byte, if the call has one
        ld      a,(hl)
        inc     hl
        ld      (${VARS+4:04x}),a          ; the call number (first byte)
        cp      6
        jr      z,two
        cp      9
        jr      z,two
        cp      $0c
        jr      nz,go
two:    ld      a,(hl)
        ld      (${VARS+5:04x}),a
        inc     hl
go:     push    hl                      ; return after the operands
        ld      a,(${VARS+4:04x})
        cp      $2d
        jr      z,tin
        cp      $2a
        jr      z,doin
        cp      $21
        jp      z,bye
        cp      $27
        jr      z,out
        cp      9
        jr      z,gn9
        cp      6
        jr      z,gn6
ok:     xor     a                       ; A=0, Z set, carry clear
        ld      hl,(${VARS+2:04x})
        ret
doin:   jr      ok
gn9:    ld      a,(${VARS+5:04x})
        cp      $38                     ; GN_Sip ($3809): the line editor.  The player types nothing and presses ENTER
        jr      z,sip
        cp      $3a                     ; GN_Sop ($3A09): append the string to the capture, then a $FE separator
        jr      nz,ok
        ld      de,(${VARS+2:04x})         ; the caller's HL: the string
sopl:   ld      a,(de)
        or      a
        jr      z,sopend
        ld      (${VARS+10:04x}),a
        call    appendc
        inc     de
        jr      sopl
sopend: ld      a,$fe
        ld      (${VARS+10:04x}),a
        call    appendc
        jr      ok
sip:    xor     a
        ld      (de),a                  ; an empty line (DE = the buffer)
        ld      b,a
        ld      c,a
        ld      a,13                    ; ended by ENTER
        ld      hl,(${VARS+2:04x})
        or      a                       ; carry clear
        ret
gn6:    ld      a,(${VARS+5:04x})
        cp      $d4                     ; OS_Sci ($D406): the address of the map: bank in B, address in HL
        jr      nz,ok
        xor     a
        ld      b,a
        ld      hl,$3000                ; the map is then at $7000 (segment 1 | $3000)
        ret
tin:    ld      a,(${VARS:04x})            ; next key of the script
        ld      l,a
        ld      h,0
        ld      de,${SCRIPT:04x}
        add     hl,de
        ld      a,(hl)
        or      a
        jr      z,nokey
        ld      hl,${VARS:04x}
        inc      (hl)
        or      a                       ; carry clear: a key
        ld      hl,(${VARS+2:04x})
        ret
nokey:  scf                             ; carry set: no key
        ld      hl,(${VARS+2:04x})
        ret
out:    call    appendc                 ; os_out: append the character (saved on entry in VARS+10)
        jp      ok
appendc:ld      hl,(${VARS+8:04x})         ; append VARS+10 to the capture buffer, but stop at the end
        ld      a,h                     ; of its space (it is followed by the stub's variables and the stack)
        cp      ${OUT_END >> 8:02x}
        ret     nc
        ld      a,(${VARS+10:04x})
        ld      (hl),a
        inc     hl
        ld      (${VARS+8:04x}),hl
        ret
bye:    ld      a,1
        ld      (${VARS+6:04x}),a          ; the app called os_bye
        jp      stop
stop:   jr      stop                    ; the run ends here (jump to 0 comes here too)
'''


def symbols(path):
    syms = {}
    for line in open(path):
        m = re.match(r'(\S+)\s*=\s*\$([0-9A-Fa-f]+)', line)
        if m:
            syms[m.group(1)] = int(m.group(2), 16)
    return syms


def show(mem, text_bytes):
    """Draw what OZ would have shown: the text window built from the VDU codes the game sent, and the map bitmap."""
    win = [[' '] * 51 for _ in range(8)]
    x = y = 0
    i = 0
    t = [b for b in text_bytes if b != 0xFE]
    while i < len(t):
        c = t[i]
        if c == 1 and i + 1 < len(t):
            k = chr(t[i + 1])
            if k == '3' and i + 4 < len(t) and chr(t[i + 2]) == '@':        # SOH 3 @ x y: position the cursor
                x, y = t[i + 3] - 32, t[i + 4] - 32
                i += 5
            elif k == '7' and i + 8 < len(t):                              # SOH 7 # n x y w h flags: define a window
                i += 9
            elif k == '2' and i + 3 < len(t):                              # SOH 2 C n / SOH 2 + S / SOH 2 - C ...
                i += 4
            else:
                i += 2
        elif c == 12:
            win = [[' '] * 51 for _ in range(8)]
            x = y = 0
            i += 1
        else:
            if 0 <= y < 8 and 0 <= x < 51 and 32 <= c < 127:
                win[y][x] = chr(c)
            x += 1
            i += 1
    print('  text window (51x8) as the game last drew it:')
    for r in win:
        print('  |' + ''.join(r) + '|')
    base = 0x7000
    print('  map (256x64 bitmap, 2x2 pixels per character; each cell is 8 bytes at base + y*256 + x*8):')
    ramp = ' .:#'
    for y in range(8):
        for r in range(0, 8, 2):
            line = ''
            for x in range(32):
                for b in range(0, 8, 2):
                    n = 0
                    for dr in (0, 1):
                        byte = mem[base + y * 256 + x * 8 + r + dr]
                        for db in (0, 1):
                            n += (byte >> (7 - b - db)) & 1
                    line += ramp[min(n, 3)]
            print('  ' + line)


def main():
    cycles = int(sys.argv[sys.argv.index('--cycles') + 1]) if '--cycles' in sys.argv else 600_000_000
    subprocess.run(['make', '-s', '-C', ROOT, 'z88rom'], check=True, capture_output=True)
    epr_path, map_path = os.path.join(BUILD, 'simcity.epr'), os.path.join(BUILD, 'simcity.map')
    syms = symbols(map_path)
    tmp = tempfile.mkdtemp(prefix='z88boot_')
    asm = os.path.join(tmp, 'stub.asm')
    open(asm, 'w').write(STUB)
    r = subprocess.run(['z88dk-z80asm', '-b', '-m', asm], capture_output=True, text=True)
    if r.returncode:
        sys.exit(r.stdout + r.stderr)
    stub_syms = symbols(os.path.join(tmp, 'stub.map'))
    image = bytearray(65536)
    stub = open(os.path.join(tmp, 'stub.bin'), 'rb').read()
    image[:len(stub)] = stub
    epr = open(epr_path, 'rb').read()
    image[0x8000:0x8000 + len(epr)] = epr
    used = syms['__ROMABLE_END_tail'] + (syms['__DATA_END_tail'] - syms['__DATA_head']) - 0x8000    # code + tables + the data image
    image[0x8000 + used:0x8000 + len(epr)] = bytes([0xCF]) * (len(epr) - used)                      # RST 8 everywhere else
    image[SCRIPT:SCRIPT + len(KEYS)] = KEYS
    STACK_FLOOR = 0x1400
    image[STACK_FLOOR:SP_START] = bytes([0xA5]) * (SP_START - STACK_FLOOR)     # to see how deep the stack goes
    img_path, dump = os.path.join(tmp, 'z88.img'), os.path.join(tmp, 'z88.out')
    open(img_path, 'wb').write(image)
    r = subprocess.run(['z88dk-ticks', '-pc', '200', '-end', f'{stub_syms["stop"]:x}', '-counter', str(cycles), '-int', '20000',
                        '-output', dump, img_path], capture_output=True, text=True)
    if '--trace' in sys.argv:
        n = int(sys.argv[sys.argv.index('--trace') + 1])
        import collections
        p = subprocess.Popen(['z88dk-ticks', '-trace', '-pc', '200', '-end', f'{stub_syms["stop"]:x}',
                              '-counter', str(cycles), '-int', '20000', '-x', map_path, img_path],
                             stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, text=True, errors='replace')
        tail = collections.deque(p.stdout, maxlen=n * 4)
        p.wait()
        print(''.join(tail))
    mem = open(dump, 'rb').read()

    data_image = open(os.path.join(BUILD, 'simcity_DATA.bin'), 'rb').read()      # (the initial data as the linker made it; the image holds it packed in the ROM build with CRT_MODEL 3)
    ok = True

    def check(name, good, detail=''):
        nonlocal ok
        print(('PASS  ' if good else 'FAIL  ') + name + ((' ' + detail) if detail and not good else ''))
        ok = ok and good

    lm = mem[syms['levelmap']:syms['levelmap'] + 9216]
    water, land = lm.count(0), sum(1 for t in lm if t in (2, 6) or 3 <= t <= 5)
    frame = mem[syms['_frame']]
    year = mem[syms['_V_year']] | mem[syms['_V_year'] + 1] << 8
    print(f'  after {cycles:,} cycles: frame counter {frame}, year {year}, map: {water} water, {land} land cells, '
          f'{sum(1 for t in lm if t == 0x80)} zone cells; os_bye called: {bool(mem[VARS + 6])}')
    check('the app did not call os_bye (no crash through OZ error path)', not mem[VARS + 6])
    check('the title screen took the level key', mem[syms['_V_difficulty']] == 1, f'difficulty {mem[syms["_V_difficulty"]]}')
    check('the map is a landscape (water and land)', water > 500 and land > 500, f'{water} water, {land} land')
    check('the game reached its main loop (frame counter running)', frame > 0, f'frame {frame}')
    deepest = next((i for i in range(STACK_FLOOR, SP_START) if mem[i] != 0xA5), SP_START)
    print(f'  stack: the deepest byte written is {deepest:#06x}, {SP_START - deepest} bytes below the start')
    table = syms['D_shoreline_lookup']                  # (a table nothing writes: the unpacked initial data must equal the linker's image)
    check('the initial data was copied from ROM to RAM',
          bytes(mem[table:table + 64]) == data_image[table - syms['__DATA_head']:][:64])
    end = mem[VARS + 8] | mem[VARS + 9] << 8
    text = bytes(mem[OUT:end])
    print(f'  os_out received {len(text)} characters')
    check('the text window got its text whole (the level choice, the status panel), not a character repeated',
          b'CHOOSE A LEVEL:' in text and b'EASY' in text and b'FUNDS $10000' in text, text[:300].decode('latin-1'))
    if '--text' in sys.argv:
        print('  ' + ''.join(chr(c) if 32 <= c < 127 else f'<{c}>' for c in text))
    bad_irqs, bad_sp = mem[VARS + 12], mem[VARS + 14] | mem[VARS + 15] << 8
    print(f'  interrupts seen: {mem[VARS + 16]} (low byte); with SP at $2000 or above: {bad_irqs}' + (f' (last SP {bad_sp:#06x})' if bad_irqs else ''))
    check('no interrupt arrives while the stack is above $2000 (the simulation runs with interrupts off)', bad_irqs == 0,
          f'{bad_irqs} did, e.g. with SP={bad_sp:#06x}: the simulation stack is {syms["sim_stack"]:#06x}..{syms["sim_stack_top"]:#06x}')
    check('the simulation slices call OZ_DI (and the state is restored: interrupts still arrive)', mem[VARS + 18] > 0 and mem[VARS + 16] > 0)
    print(f'  OZ_DI calls: {mem[VARS + 18]} (low byte)')
    if '--show' in sys.argv:
        show(mem, text_bytes=text)
    rom_changed = sum(1 for i in range(0x8000, 0x8000 + len(epr)) if mem[i] != image[i])
    defs = text.count(b'\x01\x8a=')
    check('the 63 user defined characters are defined: the icons\' 56 (64..119) and the demand bars\' 7 (120..126)', defs == 63, f'{defs} definitions')
    icons_art = open(os.path.join(ROOT, 'assets', 'z88_icons.bin'), 'rb').read()
    ok_defs = all(bytes([1, 138, ord('='), 64 + c]) + bytes(b | 0x80 for b in icons_art[c * 8:c * 8 + 8]) in text for c in range(56))
    check('each of them has its rows from assets/z88_icons.bin', ok_defs)
    check('the icons are printed, the selected one (the road, icon 1: characters 68 and 69) between reverse toggles',
          b'\x01R\x012?D\x012?E\x01R' in text, 'not found')
    check('the icons are on row 3 of the text window (positioned with 1,"3","@",32+3,32+1+3: inside the bars, below the banner; the capture ends before row 4)',
          b'\x013@#$\x01' in text, 'not found')
    check('nothing in the card image was written', rom_changed == 0, f'{rom_changed} bytes changed')
    sys.exit(0 if ok else 1)


if __name__ == '__main__':
    main()
