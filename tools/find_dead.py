#!/usr/bin/env python3
"""Find code and data in the portable engine that nothing reaches.

The engine (engine/*.asm) is a copy of the Spectrum program minus its user interface,
so what only the removed interface called is still in it.  This builds a flow graph from
the source with PORTABLE defined:

  * a label starts a chunk; code that falls through into the next label joins it, so a
    routine is a node;
  * every identifier in a chunk that names a label is an edge (calls, jumps, loads of an
    address or a variable, jump tables, self-modifying operands);
  * the roots are what the platforms use: everything engine_c.asm, platform/common and
    target/test name.

Whatever is not reachable from the roots is listed with its size (from the link map of
`make test`).  It is a static, conservative analysis: anything referenced by
name counts as used, even by other dead code in a cycle (those are reported separately
when they can be told apart from a root).

  usage: tools/find_dead.py [--verbose]
         tools/find_dead.py --smc      fail if the engine stores into its own code
"""
import collections
import glob
import os
import re
import sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..'))
os.chdir(ROOT)

DEFINED = {'PORTABLE'}
MNEMONICS = set('''adc add and bit call ccf cp cpd cpdr cpi cpir cpl daa dec di djnz ei ex exx halt im in inc ind
indr ini inir jp jr ld ldd lddr ldi ldir neg nop or otdr otir out outd outi pop push res ret reti retn rl rla rlc
rlca rld rr rra rrc rrca rrd rst sbc scf set sla sll sra srl sub xor defb defw defs defm defc binary include org
equ if ifdef ifndef else endif section public extern macro endm align'''.split())
WORDS = re.compile(r'[A-Za-z_][A-Za-z0-9_]*')


def source_lines():
    """The engine source in assembly order, with IFDEF/IFNDEF/ELSE/ENDIF resolved."""
    order = ['engine_defs.asm']
    out = []

    def read(path):
        stack = []          # (active_before, taken)
        active = True
        for raw in open(path, encoding='latin-1'):
            line = raw.rstrip('\n')
            code = line.split(';', 1)[0]
            tok = code.split()
            u = tok[0].upper() if tok else ''
            if u in ('IFDEF', 'IFNDEF'):
                cond = (tok[1] in DEFINED) == (u == 'IFDEF')
                stack.append((active, cond))
                active = active and cond
                continue
            if u == 'ELSE':
                before, cond = stack[-1]
                active = before and not cond
                continue
            if u == 'ENDIF':
                active, _ = stack.pop()
                continue
            if not active:
                continue
            m = re.match(r'\s*INCLUDE\s+"([^"]+)"', code, re.I)
            if m:
                read(os.path.join('engine', m.group(1)))
                continue
            out.append((path, line, code))

    read('engine/engine.asm')
    return out


def parse(lines):
    """-> chunks: dict(labels, file, line_no, refs, kind, falls)"""
    chunks = []
    cur = None
    labels = {}
    counters = collections.Counter()

    def new_chunk(path):
        nonlocal cur
        cur = {'labels': [], 'file': path, 'refs': set(), 'falls': True, 'has_code': False, 'has_data': False,
               'start': 0}
        chunks.append(cur)

    new_chunk('')
    for path, raw, code in lines:
        counters[path] += 1
        if not code.strip():
            continue
        rest = code
        m = re.match(r'^\.?([A-Za-z_][A-Za-z0-9_]*)\s*:?(.*)$', code) if code[0] not in ' \t' else None
        if m and not re.match(r'\s*(equ|defc)\b', m.group(2), re.I) and m.group(1).lower() not in MNEMONICS:
            name, rest = m.group(1), m.group(2)
            if cur['has_code'] or cur['has_data']:
                new_chunk(path)
            if not cur['labels']:
                cur['file'], cur['start'] = path, counters[path]
            cur['labels'].append(name)
            labels[name] = cur
        elif m and re.match(r'\s*(equ)\b', m.group(2), re.I):
            continue
        rest = rest.strip()
        if not rest:
            continue
        tok = rest.split(None, 1)
        mn = tok[0].lower()
        ops = tok[1] if len(tok) > 1 else ''
        if mn == 'defc' or mn in ('section', 'public', 'extern', 'org', 'macro', 'endm', 'align',
                                  'in_code', 'in_rodata', 'in_data', 'in_bss'):
            continue
        for w in WORDS.findall(ops):
            cur['refs'].add(w)
        if mn in ('defb', 'defw', 'defs', 'defm', 'binary'):
            cur['has_data'] = True
            cur['falls'] = False
        else:
            cur['has_code'] = True
            uncond = (mn in ('ret', 'reti', 'retn') and ',' not in ops and ops == '') or \
                     (mn in ('jp', 'jr') and ',' not in ops)
            cur['falls'] = not uncond
    return chunks, labels


STORE_RE = [
    re.compile(r'\bld\s+\(\s*([A-Za-z_]\w*)\s*(?:[+-]\s*\w+)?\s*\)\s*,'),
    re.compile(r'\b(?:inc|dec|set|res|sla|sra|srl|sll|rl|rr|rlc|rrc)\s+(?:\w+\s*,\s*)?\(\s*([A-Za-z_]\w*)\s*(?:[+-]\s*\w+)?\s*\)'),
]


def check_smc():
    """A PORTABLE engine must run from ROM, so nothing may store into a label that is code."""
    lines = source_lines()
    chunks, labels = parse(lines)
    bad = []
    for path, raw, code in lines:
        for rx in STORE_RE:
            for m in rx.finditer(code):
                c = labels.get(m.group(1))
                if c is not None and c['has_code']:
                    bad.append((path, raw.strip(), m.group(1)))
    for path, raw, name in bad:
        print(f'  stores into code: {name:28} {path}: {raw}')
    print(('FAIL' if bad else 'PASS') + f'  engine does not modify its own code ({len(bad)} stores into code labels)')
    return 1 if bad else 0


def main():
    if '--smc' in sys.argv:
        sys.exit(check_smc())
    verbose = '--verbose' in sys.argv
    chunks, labels = parse(source_lines())

    # merge fall-through chunks into nodes
    node_of = {}
    nodes = []
    prev = None
    for c in chunks:
        if prev is not None and prev['falls'] and not prev['has_data'] and (c['has_code'] or not c['has_data']):
            n = node_of[id(prev)]
        else:
            n = {'chunks': [], 'labels': [], 'refs': set()}
            nodes.append(n)
        n['chunks'].append(c)
        n['labels'] += c['labels']
        n['refs'] |= c['refs']
        node_of[id(c)] = n
        prev = c
    label_node = {name: node_of[id(c)] for name, c in labels.items()}

    # roots: every name in the platform-facing files
    roots = set()
    for f in ['engine/engine_c.asm'] + glob.glob('platform/common/*.asm') + glob.glob('target/test/*.asm'):
        txt = re.sub(r';[^\n]*', '', open(f, encoding='latin-1').read())
        roots |= set(WORDS.findall(txt))
    live = set()
    stack = [label_node[r] for r in roots if r in label_node]
    for n in stack:
        live.add(id(n))
    while stack:
        n = stack.pop()
        for w in n['refs']:
            t = label_node.get(w)
            if t is not None and id(t) not in live:
                live.add(id(t))
                stack.append(t)

    # sizes from the test build's link map
    addr = {}
    mp = 'build/test/simcity.map'
    if os.path.exists(mp):
        for line in open(mp):
            m = re.match(r'(\S+)\s*=\s*\$([0-9A-Fa-f]+) ; addr', line)
            if m:
                addr[m.group(1)] = int(m.group(2), 16)
    ordered = sorted((addr[n['labels'][0]] if n['labels'] and n['labels'][0] in addr else None, i, n)
                     for i, n in enumerate(nodes))
    starts = sorted({a for a, _, _ in ordered if a is not None})

    def size(n):
        a = next((addr[l] for l in n['labels'] if l in addr), None)
        if a is None:
            return None
        last = max((addr[l] for c in n['chunks'] for l in c['labels'] if l in addr), default=a)
        later = [s for s in starts if s > last]
        return (later[0] - a) if later else None

    dead = [n for n in nodes if id(n) not in live and n['labels']]
    by_file = collections.defaultdict(list)
    total = 0
    for n in dead:
        sz = size(n)
        total += sz or 0
        c0 = n['chunks'][0]
        kind = 'code' if any(c['has_code'] for c in n['chunks']) else 'data'
        by_file[c0['file']].append((c0['start'], n['labels'][0], sz, kind, n['labels']))
    print(f'{len(dead)} unreferenced routines/blocks, about {total} bytes\n')
    for f in sorted(by_file):
        items = sorted(by_file[f])
        print(f'{f}: {sum(i[2] or 0 for i in items)} bytes in {len(items)} blocks')
        for start, name, sz, kind, names in items:
            if verbose or (sz or 0) >= 40:
                extra = '' if len(names) < 2 else '  (also ' + ', '.join(names[1:3]) + ')'
                print(f'   {kind:4} {start:5} {name:32} {sz if sz is not None else "?":>5}{extra}')


if __name__ == '__main__':
    main()
