#!/usr/bin/env python3
"""Unpacks the data files of the Amiga SimCity (1.2.2) and of its "SimCity Graphics Sets" disk (Ancient Asia, Medieval Times, Wild West,
and the original set, 'OrigPart1.SimData'): the 44 byte header (a 4 letter tag, the 28 byte name of the file, the packed and the unpacked
length) and then Haruhiko Okumura's LZSS (4096 byte ring pre-filled with spaces, starting at 4078, matches of 3 to 18) whose bytes are
exclusive-or'd with the key AB FE 13 FF AE by their position in the stream.  Found in the disk's installer ("Install Graphics", a
68000 program: the routines at hunk 10 +0x116, +0x17c) and checked: each file comes out at exactly its stated length.

  tools/unpack_amiga.py FILE.dat [...]        writes FILE.dat.out beside each file; the disk (ADF) itself is not read: extract its
                                              files first (an OFS disk, 512 byte blocks, root at block 880)
The Amiga files are the game's, not ours: keep them (and what is unpacked from them) out of the repository."""
import struct
import sys

KEY = (0xab, 0xfe, 0x13, 0xff, 0xae)


def unpack(data):
    tag, name = data[:4], data[4:32].rstrip(b'\0').decode('latin-1')
    packed, size = struct.unpack('>II', data[36:44])
    src = data[44:44 + packed]
    ring = bytearray(b' ' * 4096)
    r, flags, pos, out = 4096 - 18, 0, 0, bytearray()

    def getc():
        nonlocal pos
        if pos >= len(src):
            return -1
        b = src[pos] ^ KEY[pos % 5]
        pos += 1
        return b

    while len(out) < size:
        flags >>= 1
        if not flags & 0x100:
            c = getc()
            if c < 0:
                break
            flags = c | 0xff00
        if flags & 1:
            c = getc()
            if c < 0:
                break
            out.append(c)
            ring[r] = c
            r = (r + 1) & 4095
        else:
            i, j = getc(), getc()
            if i < 0 or j < 0:
                break
            i |= (j & 0xf0) << 4
            j = (j & 0x0f) + 2
            for k in range(j + 1):
                c = ring[(i + k) & 4095]
                out.append(c)
                ring[r] = c
                r = (r + 1) & 4095
    return tag, name, bytes(out[:size]), size


def main():
    status = 0
    for f in sys.argv[1:]:
        tag, name, out, size = unpack(open(f, 'rb').read())
        ok = len(out) == size
        status |= not ok
        print(f'{f}: {tag.decode("latin-1")} "{name}": {len(out)} of {size} bytes' + ('' if ok else '  SHORT'))
        open(f + '.out', 'wb').write(out)
    return status


if __name__ == '__main__':
    sys.exit(main())
