#!/usr/bin/env python3
"""Render a vram.bin from game_run.lua (three planes of 40x25 cells of 8 bytes, 1 = lit; blue, red, green) to a PNG: render.py vram.bin out.png [scale]"""
import struct, sys, zlib


def png(w, h, rgb, path):
    raw = b''.join(b'\0' + rgb[y * w * 3:(y + 1) * w * 3] for y in range(h))
    def chunk(t, d):
        c = struct.pack('>I', len(d)) + t + d
        return c + struct.pack('>I', zlib.crc32(t + d) & 0xffffffff)
    open(path, 'wb').write(b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', struct.pack('>IIBBBBB', w, h, 8, 2, 0, 0, 0)) + chunk(b'IDAT', zlib.compress(raw)) + chunk(b'IEND', b''))


def main():
    d = open(sys.argv[1], 'rb').read()
    scale = int(sys.argv[3]) if len(sys.argv) > 3 else 2
    W, H = 320, 200
    img = bytearray(W * H * 3)
    for y in range(H):
        for x in range(W):
            cell = (y // 8) * 40 + x // 8
            line = y % 8
            bit = x % 8                  # the leftmost pixel is bit 0 on this machine
            b = (d[cell * 8 + line] >> bit) & 1
            r = (d[8000 + cell * 8 + line] >> bit) & 1
            g = (d[16000 + cell * 8 + line] >> bit) & 1
            o = (y * W + x) * 3
            img[o:o + 3] = bytes((255 * r, 255 * g, 255 * b))
    if scale > 1:
        big = bytearray()
        for y in range(H):
            row = b''.join(bytes(img[(y * W + x) * 3:(y * W + x) * 3 + 3]) * scale for x in range(W))
            big += row * scale
        png(W * scale, H * scale, bytes(big), sys.argv[2])
    else:
        png(W, H, bytes(img), sys.argv[2])


main()
