#!/usr/bin/env python3
"""Check the Einstein 256 map: the COM and its BSS in the standard layout, the overlay window above the BSS,
and the window and the stack under the BDOS.

usage: check_einstein_layout.py simcity-home.map [BDOS_BASE]   (BDOS_BASE: the TPA top, default $E000)"""
import re
import sys
from pathlib import Path

STACK = 0x200                  # what the UI stack and the BDOS calls need below the BDOS entry
VRAM_STAGE_SIZE = 0x2000       # $6000-$7FFF: both overlays, in whole 128-byte records


def symbols(path):
    result = {}
    pattern = re.compile(r"^(\S+)\s*=\s*\$([0-9A-Fa-f]+)")
    for line in Path(path).read_text().splitlines():
        match = pattern.match(line)
        if match:
            result[match.group(1)] = int(match.group(2), 16)
    return result


def fail(message):
    print(f"einstein256 layout error: {message}", file=sys.stderr)
    raise SystemExit(1)


def main():
    if len(sys.argv) not in (2, 3):
        raise SystemExit(__doc__)
    sym = symbols(sys.argv[1])
    top = int(sys.argv[2].lstrip("$"), 16) if len(sys.argv) == 3 else 0xE000

    def get(name):
        if name not in sym:
            fail(f"the map has no {name}")
        return sym[name]

    if get("__head") != 0x0100:
        fail("the COM must start at $0100")
    bss_head, bss_end = get("__BSS_head"), get("__BSS_END_tail")
    if bss_end < bss_head:
        fail("BSS ends before it starts")
    window = get("__EINSTEIN_GAME_OVL_head")
    if get("__EINSTEIN_MODAL_OVL_head") != window:
        fail("the two overlays must share one window")
    sizes = [(get(f"__EINSTEIN_{n}_OVL_size") + 127) & ~127 for n in ("GAME", "MODAL")]
    stage = sum(sizes)
    if stage > VRAM_STAGE_SIZE:
        fail(f"the overlays need {stage} bytes of VRAM; there are {VRAM_STAGE_SIZE}")
    window_end = window + max(sizes)
    if window < bss_end:
        fail(f"the window (${window:04X}) is inside the BSS, which ends at ${bss_end:04X}: set OVERLAY_WINDOW in mmap.inc to ${(bss_end + 255) & ~255:04X}")
    if window_end + STACK > top:
        fail(f"the window ends at ${window_end:04X}; with {STACK} bytes of stack that is above the BDOS at ${top:04X}")

    com = bss_head - 0x100
    if bss_head > 0x8000:
        print(f"einstein256 layout WARNING: the COM ends at ${bss_head:04X}, past $8000: the DOS did not load a COM that big "
              f"(ones ending at $7DC7-$7F6F loaded, one ending at $8153 did not)", file=sys.stderr)
    print(f"einstein256 layout: COM ${0x100:04X}-${com + 0x100:04X} ({com} bytes), BSS ${bss_head:04X}-${bss_end:04X} "
          f"({bss_end - bss_head}), window ${window:04X}-${window_end:04X}, VRAM stage {stage}; "
          f"{top - window_end} bytes left below ${top:04X}")


if __name__ == "__main__":
    main()
