#!/usr/bin/env python3
"""Exercise the SAM Coupé LMPR and HMPR paging model in z88dk-ticks."""
import os
import re
import subprocess
import tempfile

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
Z88DK = os.environ.get('Z88DK', os.path.expanduser('~/z88dk'))
os.environ.setdefault('ZCCCFG', os.path.join(Z88DK, 'lib', 'config'))
MODEL = 'sam.lua'

HARNESS = '''        org     $8000
start:  ld      sp,$7000
        in      a,($FA)
        ld      (initial_lmpr),a
        in      a,($FB)
        ld      (initial_hmpr),a
        ld      a,$11
        ld      ($0200),a
        ld      a,$22
        ld      ($4200),a
        ld      a,$24
        out     ($FA),a
        in      a,($FA)
        ld      (selected_lmpr),a
        ld      a,$55
        ld      ($0200),a
        ld      a,$66
        ld      ($4200),a
        ld      a,($0200)
        ld      (page4_a),a
        ld      a,($4200)
        ld      (page5_b),a
        ld      a,$20
        out     ($FA),a
        ld      a,($0200)
        ld      (page0_a),a
        ld      a,($4200)
        ld      (page1_b),a
        ld      a,$33
        ld      ($9000),a
        ld      a,$44
        ld      ($D000),a
        ld      a,($9000)
        ld      (page8_c),a
        ld      a,($D000)
        ld      (page9_d),a
        xor     a
        out     ($FA),a
        ld      a,($0200)
        ld      (rom0_a),a
        ld      a,$77
        ld      ($0200),a
        ld      a,($0200)
        ld      (rom0_after_write),a
        ld      a,$40
        out     ($FA),a
        ld      a,($D000)
        ld      (rom1_d),a
        ld      a,$88
        ld      ($D000),a
        ld      a,($D000)
        ld      (rom1_after_write),a
        ld      a,$20
        out     ($FA),a
        ld      a,($D000)
        ld      (page9_after_rom1),a
        ld      a,($0200)
        ld      (page0_after_rom0),a
        in      a,($FB)
        ld      (read_hmpr),a
        ld      a,$A5
        out     ($EE),a
fin:    halt
initial_lmpr: defb 0
initial_hmpr: defb 0
selected_lmpr: defb 0
page4_a:      defb 0
page5_b:      defb 0
page0_a:      defb 0
page1_b:      defb 0
rom0_a:       defb 0
rom0_after_write: defb 0
rom1_d:       defb 0
rom1_after_write: defb 0
page0_after_rom0: defb 0
page9_after_rom1: defb 0
page8_c:      defb 0
page9_d:      defb 0
read_hmpr:    defb 0
'''


def main():
    with tempfile.TemporaryDirectory() as tmp:
        asm = os.path.join(tmp, 'h.asm')
        open(asm, 'w').write(HARNESS)
        built = subprocess.run(['z88dk-z80asm', '-b', '-m', '-oh.bin', 'h.asm'], cwd=tmp, capture_output=True, text=True)
        if built.returncode:
            print('FAIL  assembling SAM paging harness:', built.stderr[-500:])
            return 1
        symbols = {}
        for line in open(os.path.join(tmp, 'h.map')):
            match = re.match(r'(\S+)\s+= \$([0-9A-Fa-f]+)', line)
            if match:
                symbols[match.group(1)] = int(match.group(2), 16)
        image = bytearray(65536)
        binary = open(os.path.join(tmp, 'h.bin'), 'rb').read()
        image[0x8000:0x8000 + len(binary)] = binary
        open(os.path.join(tmp, 'image.bin'), 'wb').write(image)
        rom0, rom1 = bytearray(0x4000), bytearray(0x4000)
        rom0[0x0200], rom1[0x1000] = 0xa1, 0xb2
        open(os.path.join(tmp, 'rom0.bin'), 'wb').write(rom0)
        open(os.path.join(tmp, 'rom1.bin'), 'wb').write(rom1)
        env = os.environ.copy()
        env.update({'SAM_HMPR': '8', 'SAM_LMPR': '32', 'SAM_RAM_PAGES': '16'})
        run = subprocess.run(['z88dk-ticks', '-b', 'lua', '-lua', MODEL, '-pc', '8000', '-end', f'{symbols["fin"]:x}',
                              '-counter', '100000', '-output', 'mem.out', 'image.bin'],
                             cwd=tmp, env=env, capture_output=True, text=True)
        if run.returncode:
            print('FAIL  running SAM paging harness:', run.stdout, run.stderr)
            return 1
        ram = open(os.path.join(tmp, 'sam-ram.bin'), 'rb').read()
    offsets = {name: symbols[name] - 0x8000 for name in
               ('initial_lmpr', 'initial_hmpr', 'selected_lmpr', 'page4_a', 'page5_b', 'page0_a', 'page1_b',
                'rom0_a', 'rom0_after_write', 'rom1_d', 'rom1_after_write', 'page0_after_rom0', 'page9_after_rom1',
                'page8_c', 'page9_d', 'read_hmpr')}
    results = [ram[8 * 0x4000 + offsets[name]] for name in offsets]
    want = [0x20, 8, 0x24, 0x55, 0x66, 0x11, 0x22, 0xa1, 0xa1, 0xb2, 0xb2, 0x11, 0x44, 0x33, 0x44, 8]
    expected_ram = {0x0200: 0x11, 0x4000 + 0x0200: 0x22, 4 * 0x4000 + 0x0200: 0x55,
                    5 * 0x4000 + 0x0200: 0x66, 8 * 0x4000 + 0x1000: 0x33, 9 * 0x4000 + 0x1000: 0x44}
    bad_ram = [(offset, ram[offset], value) for offset, value in expected_ram.items() if ram[offset] != value]
    ok = results == want and len(ram) == 16 * 0x4000 and not bad_ram
    print(('PASS' if ok else 'FAIL') + f'  SAM LMPR/HMPR own the full address space: page pairs, ROM reads, ignored ROM writes and register readback (got {results}, wanted {want}; bad RAM {bad_ram})')
    return 0 if ok else 1


if __name__ == '__main__':
    raise SystemExit(main())
