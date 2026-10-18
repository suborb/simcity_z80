#!/usr/bin/env python3
"""Split disassembly/sim_game.asm into platform-independent engine files and
Spectrum UI files, following tools/split_manifest.txt.

The disassembly itself is never modified.  Output:
  engine/<name>.asm            engine segments (copied verbatim, with a one line header)
  platform/zx/<name>.asm       Spectrum UI segments
  platform/zx/zx_game.asm      INCLUDEs every segment in the original order, so that
                               assembling it reproduces the original binary exactly.
  engine/engine_all.asm        INCLUDEs all engine segments (for the other platforms)

Hand-written files in engine/ (engine.asm, engine_api.asm, engine_defs.asm,
PLATFORM_INTERFACE.md) are never touched.

Usage: tools/split_engine.py   (run from the repository root)
"""
import re, sys, os

SRC = 'disassembly/sim_game.asm'
MAN = 'tools/split_manifest.txt'


# ---------------------------------------------------------------------------
# Patches applied to the extracted engine files.  Everything else is a verbatim
# copy of the disassembly.  Each patch keeps the Spectrum build byte-identical
# (checked by test/check_zx_identical.sh); PORTABLE-only changes sit inside
# IFDEF/IFNDEF PORTABLE.
# ---------------------------------------------------------------------------
PATCHES = [
 # D_autobulldoze_tile_types is 6 bytes but is searched with bc=7: the seventh byte examined is
 # V_auto_bulldoze_flag, which follows it.  Table and flag live in different sections in a PORTABLE
 # build, so search the table and then compare the flag explicitly.
 ('tools_c.asm', """        ld      hl,D_autobulldoze_tile_types
        ld      bc,7
        cpir    
        pop     bc
        pop     hl
""", """        ld      hl,D_autobulldoze_tile_types
        IFDEF PORTABLE
        ld      bc,6
        cpir    
        jr      z,L7141_found
        ld      hl,V_auto_bulldoze_flag ;the original's 7th byte: the flag after the table
        cp      (hl)
L7141_found:
        ELSE
        ld      bc,7
        cpir    
        ENDIF
        pop     bc
        pop     hl
"""),
 # literal addresses -> the symbols they stand for
 ('earthquake.asm', ".L9144  ld      a,(42045)",
  "; Entry used by the UI frame dispatcher: maybe pick a disaster for later\n"
  "sim_random_disaster:\n.L9144  ld      a,(V_disaster_reset)"),
 ('transport.asm', ".L785d  ld      a,(37650)",
  ".L785d  ld      a,(V_Transport_Funding_Requested+1)"),
 ('simulation.asm', "        ld      a,(32046)\n",
  "        ld      a,(V_zone_size_to_scan+1)\n"),
 ('simulation.asm', "        ld      ix,31899\n",
  "        ld      ix,D_stadium_effect_kernel+36   ;second (tighter) kernel\n"),
 # the cooperative task switcher exists only on the Spectrum
 ('simulation.asm', """.L830c  ld      a,1             ;Enable the simulation task
        ld      (V_simulation_disabled),a
        ld      hl,63214
        ld      (V_task1_stack),hl
        ld      hl,start_simulation
        ld      (63234),hl
""", """.L830c
        IFNDEF PORTABLE
        ; Spectrum only: prime the cooperative task switcher so the simulation
        ; task starts at start_simulation with its own stack.
        ld      a,1             ;Enable the simulation task
        ld      (V_simulation_disabled),a
        ld      hl,63214
        ld      (V_task1_stack),hl
        ld      hl,start_simulation
        ld      (63234),hl
        ENDIF
"""),
 # no second task: the budget dialog becomes a call into the UI
 ('simulation.asm', """        jr      nz,L8ee9                ; (13)
        ld      a,1
        ld      (V_wait_for_budget_confirm),a

        ; Busy loop waiting for other process to complete budget
.L8ee1  ld      a,(V_wait_for_budget_confirm)
        and     a
        jr      nz,L8ee1                ; (-6)
        jr      apply_budget_to_money                   ; (6)
""", """        jr      nz,L8ee9                ; (13)
        IFDEF PORTABLE
        ; Portable builds have no second task: ask the UI to run the budget
        ; dialog (cooperative task in coop.asm, or a direct call).  It must
        ; leave the final funds in V_money_after_budget.
        call    sim_budget_wait
        jr      apply_budget_to_money
        ELSE
        ld      a,1
        ld      (V_wait_for_budget_confirm),a

        ; Busy loop waiting for other process to complete budget
.L8ee1  ld      a,(V_wait_for_budget_confirm)
        and     a
        jr      nz,L8ee1                ; (-6)
        jr      apply_budget_to_money                   ; (6)
        ENDIF
"""),
 # let the UI run between map rows (coop.asm); a no-op unless sim_step is driving
 ('simulation.asm', """        jr      nz,L86d4                ; (-52)
        inc     d
        djnz    L86d0                   ; (-59)
""", """        jr      nz,L86d4                ; (-52)
        inc     d
        IFDEF PORTABLE
        call    sim_yield               ;end of a map row
        ENDIF
        djnz    L86d0                   ; (-59)
"""),
 ('tools_e.asm', "        ld      ix,29811\n", "        ld      ix,default_stadium_tiles\n"),
 ('tools_e.asm', "        ld      ix,29959\n", "        ld      ix,default_airport_tiles\n"),
 # the bit-mask table lives in the Spectrum's keyboard buffer ($5B11); portable
 # builds use the engine's own copy (D_bit_masks in engine_api.asm)
 ('mapaccess.asm', """        ld      a,c
        and     7
        add     a,17
        ld      l,a
        ld      h,$5b            ;23296+17 -> 23296+17+8 FIXME RELOC
        ld      a,(hl)          
""", """        ld      a,c
        and     7
        IFDEF PORTABLE
        ld      e,a
        ld      d,0
        ld      hl,D_bit_masks
        add     hl,de
        ELSE
        add     a,17
        ld      l,a
        ld      h,$5b            ;23296+17 -> 23296+17+8 FIXME RELOC
        ENDIF
        ld      a,(hl)          
"""),
 ('mapaccess.asm', """        ld      a,l
        and     7
        add     a,17
        ld      e,a
        ld      d,$5b           ;Bit set 80 40 20 10 8 4 2 1
        ld      a,(de)
""", """        ld      a,l
        and     7
        IFDEF PORTABLE
        push    hl
        ld      e,a
        ld      d,0
        ld      hl,D_bit_masks
        add     hl,de
        ld      a,(hl)
        pop     hl
        ELSE
        add     a,17
        ld      e,a
        ld      d,$5b           ;Bit set 80 40 20 10 8 4 2 1
        ld      a,(de)
        ENDIF
"""),
 # the power plant type is chosen from a menu on the Spectrum; elsewhere a hook
 ('tools_e.asm', """        ld      ix,menu_power
        call    open_menu
""", """        IFDEF PORTABLE
        call    ui_choose_power_plant   ;sets V_power_type_chosen (0 = cancel, 1 = nuclear, else coal)
        ELSE
        ld      ix,menu_power
        call    open_menu
        ENDIF
"""),
 ('tools_c.asm', "        jr      nz,play_place_sound                ; It's not dirt",
  "        IFDEF PORTABLE\n        jp      nz,play_place_sound     ; It's not dirt (platform hook: out of jr range)\n"
  "        ELSE\n        jr      nz,play_place_sound                ; It's not dirt\n        ENDIF"),
 # the sound hook is supplied by the platform and may be out of jr range
 ('disasters.asm', "        jr      play_crash_sound                   ; (-103)",
  "        IFDEF PORTABLE\n        jp      play_crash_sound\n        ELSE\n"
  "        jr      play_crash_sound                   ; (-103)\n        ENDIF"),
]

def apply_patches(force=False):
    for fname, old, new in PATCHES:
        path = 'engine/' + fname
        s = open(path, encoding='latin-1').read()
        if s.count(old) != 1:
            raise SystemExit(f'patch does not apply to {path}: {old[:50]!r} ({s.count(old)} matches)')
        open(path, 'w', encoding='latin-1').write(s.replace(old, new))


# ---------------------------------------------------------------------------
# Sections.  A PORTABLE build can put code and tables in ROM and variables in RAM
# (engine/sections.asm defines IN_CODE, IN_RODATA, IN_DATA, IN_BSS, IN_SMC; they
# expand to nothing in the Spectrum build, which stays one flat, identical block).
#
#   * (the Spectrum program patches its own operands in nine places; a PORTABLE build uses
#     plain variables instead, see SMC_PATCHES, so no code needs to live in RAM;)
#   * every labelled run of defb/defw/defs/defm is a variable (V_*: data_user,
#     bss_user when it is only reserved space), a table (D_* and RODATA_TABLES:
#     rodata_user), or one of the BUFFERS (bss_user).  A new name that fits none
#     of these stops the tool, so nothing lands in the wrong place by accident.
# ---------------------------------------------------------------------------
RODATA_TABLES = {
    'zone_costs', 'zone_action_jump_table', 'unbulldozeable_tiles', 'D29565',
    'default_residential_tiles', 'default_commercial_tiles', 'default_industrial_tiles',
    'default_police_tiles', 'default_fire_tiles', 'default_stadium_tiles',
    'default_coal_power_station_tile', 'default_nuclear_power_station_tiles',
    'default_seaport_tiles', 'default_airport_tiles',
    'residential_zone_1', 'residential_zone_2', 'commercial_zone_1', 'industrial_zone_1',
}
BUFFERS = {'minimaps', 'levelmap'}

DATA_RE = re.compile(r'^(?:\.?([A-Za-z_]\w*)\s*:?)?\s*(defb|defw|defs|defm)\b', re.I)
LABEL_RE = re.compile(r'^\.?([A-Za-z_]\w*)\s*:?\s*(?:;.*)?$')

def is_terminator(line):
    c = line.split(';')[0].strip()
    m = re.match(r'(?:\.?\w+\s*:?\s+)?(ret|reti|retn|jp|jr)\b(.*)', c, re.I) if c else None
    if not m:
        return False
    op, rest = m.group(1).lower(), m.group(2)
    return rest.strip() == '' if op.startswith('ret') else ',' not in rest

def classify(labels, kinds):
    names = [l for l in labels]
    if any(n in BUFFERS for n in names):
        return 'bss'
    if any(n.startswith('D_') or n in RODATA_TABLES for n in names):
        return 'rodata'
    if any(n.startswith('V_') for n in names):
        return 'bss' if kinds == {'defs'} else 'data'
    raise SystemExit(f'cannot place data {names}: add it to RODATA_TABLES, BUFFERS or name it V_/D_')

def wrap_data(fname, lines, report):
    """Wrap each labelled run of data directives in the section for its class."""
    chunks = []      # (first_line, last_line, class, labels)
    cur = None       # dict(start, end, labels, kinds)
    def close():
        nonlocal cur
        if cur and cur['kinds'] and cur['labels']:
            chunks.append((cur['start'], cur['end'], classify(cur['labels'], cur['kinds']), cur['labels']))
        cur = None
    for i, l in enumerate(lines):
        if not l.strip() or l.lstrip().startswith(';'):
            continue
        code = l.split(';')[0]
        m = DATA_RE.match(code)
        lm = LABEL_RE.match(code) if code[:1] not in ' \t' else None
        if m:
            if m.group(1) and cur and cur['kinds']:
                close()
            if cur is None:
                cur = dict(start=i, end=i, labels=[], kinds=set())
            if m.group(1):
                cur['labels'].append(m.group(1))
            cur['kinds'].add(m.group(2).lower())
            cur['end'] = i
        elif lm and lm.group(1).lower() not in ('org', 'section'):
            if cur and cur['kinds']:
                close()
            if cur is None:
                cur = dict(start=i, end=i, labels=[], kinds=set())
            cur['labels'].append(lm.group(1))
        else:
            close()
    close()
    # merge neighbours of the same class separated only by comments/blank lines
    merged = []
    for c in chunks:
        if merged and merged[-1][2] == c[2] and all(
                not lines[k].strip() or lines[k].lstrip().startswith(';')
                for k in range(merged[-1][1] + 1, c[0])):
            merged[-1] = (merged[-1][0], c[1], c[2], merged[-1][3] + c[3])
        else:
            merged.append(c)
    # report data of different classes that sit side by side (code might index across them)
    for p, q in zip(merged, merged[1:]):
        if all(not lines[k].strip() or lines[k].lstrip().startswith(';') for k in range(p[1] + 1, q[0])):
            report.append(f'{fname}: {p[3][0]} ({p[2]}) is directly followed by {q[3][0]} ({q[2]})')
    mac = {'rodata': 'IN_RODATA', 'data': 'IN_DATA', 'bss': 'IN_BSS'}
    for a, b, cls, labels in reversed(merged):
        lines.insert(b + 1, '        IN_CODE')
        lines.insert(a, '        ' + mac[cls])
    return lines

def apply_sections(engine_files):
    report = []
    for fname in engine_files:
        path = 'engine/' + fname
        lines = open(path, encoding='latin-1').read().split('\n')
        lines = wrap_data(fname, lines, report)
        open(path, 'w', encoding='latin-1').write('\n'.join(lines))
    for r in report:
        print('  note:', r)

# The Spectrum program patches nine operands of its own instructions: six loop widths
# (ld c,0 once per row), an AND mask, the running dx/dy of the landscape ellipse and an
# ADD offset.  Each is a variable kept in the operand.  PORTABLE builds keep them in real
# variables instead (defined in engine_api.asm), so the engine runs from ROM.
def _smc(file, old, new):
    return (file, old, "        IFDEF PORTABLE\n" + new + "        ELSE\n" + old + "        ENDIF\n")

SMC_PATCHES = [
 _smc('landscape.asm', "        ld      (SMC_27367+1),a     ; patch the AND mask used for step size\n",
      "        ld      (V_stroke_step_mask),a     ; AND mask used for step size\n"),
 _smc('landscape.asm', "        and     7                   ; SMC: mask = e parameter (7 or 3)\n",
      "        push    hl\n        ld      hl,V_stroke_step_mask\n        and     (hl)                ; mask = e parameter (7 or 3)\n        pop     hl\n"),
 _smc('landscape.asm', "        ld      (SMC_27676+1),hl ; initialise dy = s (high byte), dx low byte = 0\n        ld      h,l\n        ld      (SMC_27673+1),hl ; initialise dx = 0\n",
      "        ld      (V_ellipse_dy),hl ; initialise dy = s (high byte), dx low byte = 0\n        ld      h,l\n        ld      (V_ellipse_dx),hl ; initialise dx = 0\n"),
 _smc('landscape.asm', "        ld      hl,0            ; SMC: current dx (updated each iteration)\n",
      "        ld      hl,(V_ellipse_dx) ; current dx (updated each iteration)\n"),
 _smc('landscape.asm', "        ld      de,0            ; SMC: current dy (updated each iteration)\n",
      "        ld      de,(V_ellipse_dy) ; current dy (updated each iteration)\n"),
 _smc('landscape.asm', "        ld      (SMC_27673+1),hl ; save updated dx for next iteration\n        ld      (SMC_27676+1),de ; save updated dy for next iteration\n",
      "        ld      (V_ellipse_dx),hl ; save updated dx for next iteration\n        ld      (V_ellipse_dy),de ; save updated dy for next iteration\n"),
 _smc('landscape.asm', "        ld      a,(SMC_27673+2) ; dx_high (high byte of stored dx)\n",
      "        ld      a,(V_ellipse_dx+1) ; dx_high (high byte of stored dx)\n"),
 _smc('tools_c.asm', "        ld      (auto_bulldoze_nun_columns+1),a\n",
      "        ld      (V_autobulldoze_width),a\n"),
 _smc('tools_c.asm', "        ld      c,0         ;SMC\n",
      "        ld      a,(V_autobulldoze_width)\n        ld      c,a\n"),
 _smc('tools_c.asm', "        ld      (SMC_29056+1),a\n.L717f  push    hl\nSMC_29056:\n        ld      c,0\n",
      "        ld      (V_width_29056),a\n.L717f  push    hl\n        ld      a,(V_width_29056)\n        ld      c,a\n"),
 _smc('tools_c.asm', "        ld      (SMC_29092+1),a\n.L71a3  push    hl\nSMC_29092:\n        ld      c,0\n",
      "        ld      (V_width_29092),a\n.L71a3  push    hl\n        ld      a,(V_width_29092)\n        ld      c,a\n"),
 _smc('tools_d.asm', "        ld      (SMC_29270+1),a\n",
      "        ld      (V_path_tile_offset),a\n"),
 _smc('tools_d.asm', "        add     a,11\n",
      "        push    hl\n        ld      hl,V_path_tile_offset\n        add     a,(hl)\n        pop     hl\n"),
 _smc('tools_e.asm', ".L7337  ld      (SMC_bulldoze_zone_width+1),a\n        ld      b,a\n",
      ".L7337  ld      (V_bulldoze_zone_width),a\n        ld      b,a\n"),
 _smc('tools_e.asm', "        ld      c,0             ;SMC\n",
      "        ld      a,(V_bulldoze_zone_width)\n        ld      c,a\n"),
 _smc('simulation.asm', "        ld      (SMC_31652+1),a\n        ld      b,a\n.L7ba2  push    ix\nSMC_31652:\n        ld      c,0\n",
      "        ld      (V_width_31652),a\n        ld      b,a\n.L7ba2  push    ix\n        ld      a,(V_width_31652)\n        ld      c,a\n"),
 _smc('simulation.asm', "        ld      (SMC_31705+1),a\n        ld      b,a\n.L7bd7  push    ix\nSMC_31705:\n        ld      c,0\n",
      "        ld      (V_width_31705),a\n        ld      b,a\n.L7bd7  push    ix\n        ld      a,(V_width_31705)\n        ld      c,a\n"),
]
PATCHES += SMC_PATCHES

def main():
    lines = open(SRC, encoding='latin-1').read().split('\n')
    segs = []
    for raw in open(MAN):
        raw = raw.rstrip('\n')
        if not raw.strip() or raw.lstrip().startswith('#'):
            continue
        if raw.startswith('re:'):
            m = re.match(r're:(\S.*?)\s{2,}(\w+)\s+(\w+)\s*$', raw)
            pat, owner, name = m.group(1), m.group(2), m.group(3)
            start = next(i for i, l in enumerate(lines) if re.search(pat, l)) + 1
        else:
            a, owner, name = raw.split()[:3]
            start = int(a)
        segs.append((start, owner, name))
    segs.sort()
    assert segs[0][0] == 1
    os.makedirs('engine', exist_ok=True)
    os.makedirs('platform/zx', exist_ok=True)
    order = []
    for k, (start, owner, name) in enumerate(segs):
        end = segs[k + 1][0] - 1 if k + 1 < len(segs) else len(lines)
        body = lines[start - 1:end]
        d = 'engine' if owner == 'engine' else 'platform/zx'
        path = f'{d}/{name}.asm'
        header = f'; {name}: lines {start}-{end} of disassembly/sim_game.asm ({owner})'
        # keep the first line of each file a comment so INCLUDE is harmless
        open(path, 'w', encoding='latin-1').write(header + '\n' + '\n'.join(body) + '\n')
        order.append((owner, path, name))
    with open('platform/zx/zx_game.asm', 'w', encoding='latin-1') as f:
        f.write('; Spectrum build: all segments in their original order.\n')
        f.write('; Assembles to exactly the same bytes as disassembly/sim_game.asm.\n')
        f.write('        INCLUDE "../../engine/sections.asm"        ; IN_CODE etc.: empty here\n')
        for owner, path, name in order:
            rel = os.path.relpath(path, 'platform/zx')
            f.write(f'        INCLUDE "{rel}"\n')
    with open('engine/engine_all.asm', 'w', encoding='latin-1') as f:
        f.write('; All engine segments, in source order.\n')
        for owner, path, name in order:
            if owner == 'engine':
                f.write(f'        INCLUDE "{os.path.basename(path)}"\n')
    apply_patches()
    apply_sections([os.path.basename(p) for o, p, n in order if o == 'engine'])
    print(f'{len(order)} segments:',
          sum(1 for o in order if o[0] == 'engine'), 'engine,',
          sum(1 for o in order if o[0] != 'engine'), 'zx')

if __name__ == '__main__':
    main()
