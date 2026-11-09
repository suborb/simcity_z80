#!/usr/bin/env python3
"""Makes the Camputers Lynx game disc: a CP/M format disk image (z88dk's appmake +cpmdisk -f lynx: 40 tracks of 10 sectors of 512 bytes, single sided, a plain .ldf)
with target/lynx/boot.asm as its boot sector (EXT BOOT runs it) and the program and the art as files that it reads by sector: appmake lays the first file out from
sector 24 (two system tracks and the directory), in blocks of 1 KB, the next file after it.  The boot sector is assembled with where they are, and the image is checked.

usage: lynx_disc.py simcity.bin art.bin boot.asm out.ldf
"""
import math, os, subprocess, sys

SECTOR, PER_TRACK, DIR_SECTORS, SYSTEM_SECTORS, BLOCK_SECTORS = 512, 10, 4, 20, 2

def main():
    prog, art, boot_asm, out = sys.argv[1:5]
    psz, asz = os.path.getsize(prog), os.path.getsize(art)
    img = SYSTEM_SECTORS + DIR_SECTORS
    img_n = math.ceil(psz / SECTOR)
    art_at = img + BLOCK_SECTORS * math.ceil(psz / (BLOCK_SECTORS * SECTOR))
    art_n = math.ceil(asz / SECTOR)
    defs = ['-DIMG_T=%d' % (img // PER_TRACK), '-DIMG_S=%d' % (img % PER_TRACK + 1), '-DIMG_N=%d' % img_n,
            '-DART_T=%d' % (art_at // PER_TRACK), '-DART_S=%d' % (art_at % PER_TRACK + 1), '-DART_N=%d' % art_n]
    boot_bin = os.path.splitext(out)[0] + '_boot.bin'
    subprocess.check_call(['z88dk-z80asm', '-b'] + defs + ['-o' + boot_bin, boot_asm])
    boot = open(boot_bin, 'rb').read()
    assert len(boot) <= SECTOR, 'the boot sector is %d bytes' % len(boot)
    subprocess.check_call(['z88dk-appmake', '+cpmdisk', '-f', 'lynx', '--linear', '-b', prog, '-o', out, '--container', 'raw', '-s', boot_bin,
                           '-a', art + ':ART     BIN'], stdout=subprocess.DEVNULL)
    d = open(out, 'rb').read()
    assert len(d) == 40 * PER_TRACK * SECTOR, 'the image is %d bytes' % len(d)
    p, a = open(prog, 'rb').read(), open(art, 'rb').read()
    assert d[:len(boot)] == boot, 'the boot sector is not on the disk'
    assert d[img * SECTOR:img * SECTOR + len(p)] == p, 'the program is not at sector %d' % img
    assert d[art_at * SECTOR:art_at * SECTOR + len(a)] == a, 'the art is not at sector %d' % art_at
    print('lynx disc %s: program %d bytes at sector %d (%d sectors), art at sector %d (%d sectors), the saves from sector 200: ends at %d' %
          (out, psz, img, img_n, art_at, art_n, art_at + art_n))
    assert art_at + art_n <= 200, 'the program and art run into the save slots'
    os.remove(boot_bin)

main()
