#!/usr/bin/env python3
"""Make z88dk's SPC-1500 keyboard tables from MAME's matrix
(src/mame/samsung/spc1500.cpp, ports LINE.0-9: row n is read at I/O port
$1900 + n, bit set = key down).

  tools/spc1500_keys.py [spc1500.cpp] > in_keytranstbl.asm
      the tables of libsrc/target/spc1500/input/in_keytranstbl.asm:
      unshifted, SHIFT and CTRL, 80 keys each, 255 for no code

(The game reads its keys through z88dk's in_Inkey too.)
"""
import re, sys, os
args = [a for a in sys.argv[1:] if not a.startswith('--')]
src = args[0] if args else os.path.expanduser('~/Projects/mame/src/mame/samsung/spc1500.cpp')
text = open(src, encoding='utf-8', errors='replace').read()

def parse():
    rows = {}
    cur = None
    for line in text.split('\n'):
        m = re.search(r'PORT_START\("LINE\.(\d)"\)', line)
        if m: cur = int(m.group(1)); rows[cur] = {}; continue
        if cur is None: continue
        if 'PORT_START' in line: cur = None; continue
        m = re.search(r'PORT_BIT\(0x([0-9a-f]+), IP_ACTIVE_HIGH, (\w+)\)(.*)', line)
        if not m: continue
        bit = int(m.group(1), 16); kind = m.group(2); rest = m.group(3)
        if kind != 'IPT_KEYBOARD': continue
        name = re.search(r'PORT_NAME\((.*?)\)\s+PORT_CODE', rest)
        name = name.group(1) if name else ''
        chars = re.findall(r"PORT_CHAR\(('(?:\\.|[^'])+'|0x[0-9a-f]+|\d+|UCHAR_\w+(?:\(\w+\))?)\)", rest)
        rows[cur][bit] = (name, chars)
    return rows

def char(c):
    if c.startswith("'"):
        v = ord(c[1:-1].encode().decode('unicode_escape'))
        return v if v < 128 else None
    return None

SPECIAL = {'UTF8_UP': 11, '"Right"': 9, '"Left"': 8, '"Down"': 10, '"Return"': 13, '"Space"': 32, '"ESC"': 27,
           '"F1"': 128, '"F2"': 129, '"F3"': 130, '"F4"': 131, '"F5"': 132}
def z_code(name, chars, table):
    """table 0 unshifted, 1 SHIFT, 2 CTRL"""
    for k, v in SPECIAL.items():
        if k in name:
            return v
    if name == '"Backspace"': return 12 if table != 1 else 127       # (z88dk's DEL is 12)
    if chars:
        v = char(chars[0])
        if v is None: return 255
        if chr(v).isalpha():
            if table == 2: return ord(chr(v).lower()) - 96
            return ord(chr(v).lower()) if table == 0 else ord(chr(v).upper())
        if table == 1 and len(chars) > 1:
            w = char(chars[1])
            return w if w is not None else 255
        if table == 2: return 255 if v not in (13,) else v
        if v < 32: return 255
        return v
    return 255

rows = parse()
HEADER = """\
; Samsung SPC-1500 keyboard: the codes for in_Inkey and in_LookupKey
;
; Three tables of 80 (10 rows of 8 keys: row n is read at I/O port
; $1900 + n and a key down is a 1 bit): unshifted, SHIFT, CTRL.  255 = no
; code.  Made by tools/spc1500_keys.py from MAME's matrix
; (samsung/spc1500.cpp).  Cursor keys 11 up, 10 down, 8 left, 9 right,
; RETURN 13, ESC 27, Backspace 12 (z88dk's DEL; shifted 127), F1-F5 128-132.
; The modifiers are in row 0: SHIFT bit 1, CTRL bit 2, Break bit 4, Graph
; bit 6.  No code: Caps, Tab, Home, Del/Ins, Hangul, Graph, Break.
"""
print(HEADER)
print('    SECTION rodata_clib')
print('    PUBLIC  in_keytranstbl')
print()
print('in_keytranstbl:')
for t, title in enumerate((' ; Unshifted', ' ; SHIFT', ' ; CTRL')):
    print(title)
    for r in range(10):
        codes = []
        names = []
        for b in range(8):
            name, chars = rows[r].get(1 << b, ('', []))
            c = z_code(name, chars, t) if name else 255
            codes.append(c)
            names.append((name.strip('"') or '-').replace(' ', ''))
        def fmt(c):
            if c == 255: return '255'
            if 32 < c < 127 and chr(c) not in "'\\\"": return "'%s'" % chr(c)
            if c == 39: return '39'
            if c == 92: return "'\\\\'"
            return str(c)
        print('    defb    %s    ; %d: %s' % (', '.join(fmt(c) for c in codes), r, ' '.join(names)))
    print()
