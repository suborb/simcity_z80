#!/usr/bin/env python3
"""The Z88's menus (platform/console/z88_dor.c) must send the commands the game understands
(CMD_* in ui/platform.h).  Nothing can run OZ menus here, so check the two files agree:

  * every command except CMD_REDRAW (which OZ sends itself) has exactly one menu item, and
    every menu item sends a command that exists;
  * the shortcut keys (typed after the [] key) are letter sequences, each different, none the
    start of another, and each begins with its menu's initial, which is not M, I or J (ENTER, TAB
    and LF are <>M, <>I and <>J);
  * the menus stay within OZ's limits (7 topics, 24 items each, command codes 0x81..0xB0).

  usage: test/z88/run.py
"""
import os
import re
import sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
read = lambda p: open(os.path.join(ROOT, p), encoding='latin-1').read()

platform_h, dor, text_h = read('ui/platform.h'), read('platform/console/z88_dor.c'), read('ui/text.c')
failures = []


def check(name, ok, detail=''):
    print(('PASS  ' if ok else 'FAIL  ') + name + ((' ' + detail) if detail and not ok else ''))
    if not ok:
        failures.append(name)


cmds = {m.group(1): int(m.group(2), 16) for m in re.finditer(r'#define\s+(CMD_\w+)\s+(0x[0-9A-Fa-f]+)', platform_h)}
topics = {int(m.group(1)): m.group(2) for m in re.finditer(r'#define\s+TOPIC(\d+)\s+"([^"]*)"', dor)}
items = {}
shortcuts = {}
for m in re.finditer(r'#define\s+TOPIC(\d+)_(\d+)\s+"([^"]*)"', dor):
    t, i = int(m.group(1)), int(m.group(2))
    code = re.search(r'#define\s+TOPIC%d_%dCODE\s+(0x[0-9A-Fa-f]+)' % (t, i), dor)
    items[(t, i)] = (m.group(3), int(code.group(1), 16) if code else None)
    key = re.search(r'#define\s+TOPIC%d_%dKEY\s+"([^"]*)"' % (t, i), dor)
    shortcuts[(t, i)] = key.group(1) if key else None

check('the descriptor defines menus and items', len(topics) >= 3 and len(items) >= 20)
check('every item has a command code', all(c is not None for _, c in items.values()))
codes = [c for _, c in items.values()]
check('no two items send the same command', len(codes) == len(set(codes)))
tool0 = cmds['CMD_TOOL']
map0 = cmds['CMD_MAP']
singles = {n: v for n, v in cmds.items() if n not in ('CMD_TOOL', 'CMD_MAP', 'CMD_REDRAW')}
sent = set(codes)
check('every game command has a menu item', all(v in sent for v in singles.values()),
      str([n for n, v in singles.items() if v not in sent]))
known = set(singles.values()) | {tool0 + n for n in range(14)} | {map0 + n for n in range(6)}
check('every menu item sends a command the game knows', sent <= known, str(sorted(hex(c) for c in sent - known)))
check('command codes are in the range OZ gives menu commands (0x81..0xB0)', all(0x81 <= c <= 0xB0 for c in sent | set(cmds.values())))
seqs = list(shortcuts.values())
check('every item has a shortcut of capital letters', all(k and re.fullmatch('[A-Z]+', k) for k in seqs), str(seqs))
check('no two shortcuts are the same', len(seqs) == len(set(seqs)))
clash = [(a, b) for a in seqs if a for b in seqs if b and a != b and b.startswith(a)]
check('no shortcut is the start of another', not clash, str(clash[:3]))
check('each shortcut starts with its menu initial',
      all(k and k[0] == topics[t][0] for (t, _), k in shortcuts.items()),
      str([(topics[t], k) for (t, _), k in shortcuts.items() if not k or k[0] != topics[t][0]]))
check('no shortcut starts with M, I or J (the ENTER, TAB and LF keys are <>M, <>I and <>J, which OZ would take for them)',
      not [k for k in seqs if k and k[0] in 'MIJ'], str([k for k in seqs if k and k[0] in 'MIJ']))
check('at most 7 menus of 24 items', len(topics) <= 7 and all(sum(1 for (t, _) in items if t == k) <= 24 for k in topics))

check('there is no Tools menu (the icons and TAB choose a tool)', 'Tools' not in topics.values() and not any(tool0 <= c < tool0 + 14 for c in sent))

# The icons the text window shows: the Spectrum's 16x16 tool icons, frame cut off, as 2x2 Z88 cells of 6x8.
icons = open(os.path.join(ROOT, 'assets', 'z88_icons.bin'), 'rb').read()
udgs = open(os.path.join(ROOT, 'assets', 'udgs.bin'), 'rb').read()
check('the icon file is 14 icons of 4 cells of 8 rows', len(icons) == 14 * 4 * 8)
bad = []
for icon in range(14):
    for y in range(16):
        for x in range(12):
            cell = (y // 8) * 2 + x // 6                                # which of the four cells
            z88 = icons[icon * 32 + cell * 8 + y % 8] >> (5 - x % 6) & 1
            zx_x, zx_y = x + 2, y                                       # the frame is two pixels wide
            zx = 0
            if 2 <= zx_y <= 13:
                zx = udgs[(icon * 4 + (zx_y // 8) * 2 + zx_x // 8) * 8 + zx_y % 8] >> (7 - zx_x % 8) & 1
            if z88 != zx:
                bad.append((icon, x, y))
check('every icon pixel is the Spectrum icon pixel (the picture inside the frame, 12x12 of the 16x16)', not bad, str(bad[:4]))
check('no icon cell uses bits above the six pixels', all(b < 64 for b in icons))
print('FAILED: ' + ', '.join(failures) if failures else 'Z88 menus agree with the game commands')
sys.exit(1 if failures else 0)
