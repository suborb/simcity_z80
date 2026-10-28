#!/usr/bin/env python3
"""assets/map_art.bin: the part of assets/udgs.bin the portable engine uses.

udgs.bin is the Spectrum program's graphics block.  Its first 536 bytes are the menu and
icon characters and its last 123 bytes are unused; the engine's view_cell needs only the
map tiles (94 x 8 bytes), the large-zone pieces (251 x 8) and their attribute bytes.

assets/map_attrs.bin: the attribute bytes alone (the last 345 of map_art.bin), for the Next, which draws its own
pictures and has no use for the art (engine/art.asm).
"""
import os
root = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..')
d = open(os.path.join(root, 'assets', 'udgs.bin'), 'rb').read()
open(os.path.join(root, 'assets', 'map_art.bin'), 'wb').write(d[536:3641])
open(os.path.join(root, 'assets', 'map_attrs.bin'), 'wb').write(d[536 + 2760:3641])
