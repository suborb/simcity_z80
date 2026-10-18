#!/usr/bin/env python3
"""The Z88's menus (platform/console/z88_dor.c) must send the commands the game understands
(CMD_* in ui/platform.h).  Nothing can run OZ menus here, so check the two files agree:

  * every command except CMD_REDRAW (which OZ sends itself) has exactly one menu item, and
    every menu item sends a command that exists;
  * the Tools menu lists the game's tools in order: item n sends CMD_TOOL + n and is named
    like tool n in ui/text.h;
  * the shortcut keys (typed after the [] key) are letter sequences, each different, none the
    start of another, and each begins with its menu's initial;
  * the menus stay within OZ's limits (7 topics, 24 items each, command codes 0x81..0xB0).

  usage: test/z88/run.py
"""
import os
import re
import sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
read = lambda p: open(os.path.join(ROOT, p), encoding='latin-1').read()

platform_h, dor, text_h = read('ui/platform.h'), read('platform/console/z88_dor.c'), read('ui/text.h')
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
check('at most 7 menus of 24 items', len(topics) <= 7 and all(sum(1 for (t, _) in items if t == k) <= 24 for k in topics))

tools_topic = next((k for k, v in topics.items() if v == 'Tools'), None)
names = re.findall(r'"([^"$]*?)\s*\$\d+"', text_h[text_h.index('text_tools'):text_h.index('};', text_h.index('text_tools'))])
tool_items = sorted((i, v) for (t, i), v in items.items() if t == tools_topic)
check('the Tools menu has one item per tool', len(tool_items) == len(names) == 14, f'{len(tool_items)} items, {len(names)} tools')
bad = [(n, name, code) for n, ((_, (name, code)), tool) in enumerate(zip(tool_items, names))
       if code != tool0 + n or not (name.lower().replace('-', ' ').startswith(tool.lower()[:5]) or tool.lower().startswith(name.lower()[:5]))]
check('tool item n sends CMD_TOOL + n and is named like tool n', not bad, str(bad[:3]))

print('FAILED: ' + ', '.join(failures) if failures else 'Z88 menus agree with the game commands')
sys.exit(1 if failures else 0)
