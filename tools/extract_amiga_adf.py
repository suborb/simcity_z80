#!/usr/bin/env python3
"""Extract files from an Amiga OFS ADF disk image.

    tools/extract_amiga_adf.py simclassics_scc_1meg.adf --outdir build/amiga_1meg

Supports standard 880 KiB OFS images, including the 1.2.2 SimCity disk. File
contents are copied as stored; unpack game resource files separately with
tools/unpack_amiga.py when needed. Disk images and extracted game data should
stay out of the repository.
"""
import argparse
import os
import sys

BLOCK = 512
ROOT_BLOCK = 880
HASH_START = 24
HASH_END = 312
HASH_NEXT = 496
NAME_LEN = 432
NAME = 433
SECONDARY = 508


class OFSImage:
    def __init__(self, path):
        self.path = path
        self.data = open(path, 'rb').read()
        if len(self.data) != 1760 * BLOCK:
            raise ValueError(f'{path}: expected an 880 KiB, 1760-block ADF')
        if self.data[3] != 0:
            raise ValueError(f'{path}: not an OFS disk (DOS type {self.data[3]})')

    def block(self, n):
        if not 0 < n < len(self.data) // BLOCK:
            raise ValueError(f'{self.path}: invalid block number {n}')
        return self.data[n * BLOCK:(n + 1) * BLOCK]

    @staticmethod
    def word(b, at):
        return int.from_bytes(b[at:at + 4], 'big')

    @staticmethod
    def filename(b):
        size = b[NAME_LEN]
        return b[NAME:NAME + size].decode('latin1')

    def files(self, root=ROOT_BLOCK):
        seen_dirs = set()

        def walk(directory, parent):
            if directory in seen_dirs:
                raise ValueError(f'{self.path}: directory cycle at block {directory}')
            seen_dirs.add(directory)
            d = self.block(directory)
            for at in range(HASH_START, HASH_END, 4):
                entry = self.word(d, at)
                chain_seen = set()
                while entry:
                    if entry in chain_seen:
                        raise ValueError(f'{self.path}: hash chain cycle at block {entry}')
                    chain_seen.add(entry)
                    h = self.block(entry)
                    name = self.filename(h)
                    path = os.path.join(parent, name)
                    kind = int.from_bytes(h[SECONDARY:SECONDARY + 4], 'big', signed=True)
                    if kind == 2:              # ST_USERDIR
                        yield from walk(entry, path)
                    elif kind == -3:            # ST_FILE
                        yield path, self.read_file(entry, h)
                    elif kind not in (3, 4, -4):  # links are not used by the game disk
                        raise ValueError(f'{self.path}: unsupported entry type {kind} for {path}')
                    entry = self.word(h, HASH_NEXT)

        yield from walk(root, '')

    def read_file(self, header_block, header):
        block_num = self.word(header, 16)
        contents = bytearray()
        seq = 1
        seen = set()
        while block_num:
            if block_num in seen:
                raise ValueError(f'{self.path}: data chain cycle for block {header_block}')
            seen.add(block_num)
            d = self.block(block_num)
            if self.word(d, 0) != 8 or self.word(d, 4) != header_block or self.word(d, 8) != seq:
                raise ValueError(f'{self.path}: invalid OFS data block {block_num} for block {header_block}')
            size = self.word(d, 12)
            if size > 488:
                raise ValueError(f'{self.path}: invalid data length {size} in block {block_num}')
            contents.extend(d[24:24 + size])
            block_num = self.word(d, 16)
            seq += 1
            if seq > len(self.data) // BLOCK:
                raise ValueError(f'{self.path}: data chain too long for block {header_block}')
        return bytes(contents)


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('adf')
    ap.add_argument('--outdir', default='build/amiga_adf')
    args = ap.parse_args()
    try:
        image = OFSImage(args.adf)
        files = list(image.files())
        os.makedirs(args.outdir, exist_ok=True)
        for path, data in files:
            out = os.path.join(args.outdir, path)
            os.makedirs(os.path.dirname(out), exist_ok=True)
            with open(out, 'wb') as f:
                f.write(data)
            print(f'{len(data):7} bytes  {path or "."}')
        print(f'{len(files)} files extracted to {args.outdir}')
    except (OSError, ValueError) as e:
        sys.exit(str(e))


if __name__ == '__main__':
    main()
