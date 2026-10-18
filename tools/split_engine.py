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
        for owner, path, name in order:
            rel = os.path.relpath(path, 'platform/zx')
            f.write(f'        INCLUDE "{rel}"\n')
    with open('engine/engine_all.asm', 'w', encoding='latin-1') as f:
        f.write('; All engine segments, in source order.\n')
        for owner, path, name in order:
            if owner == 'engine':
                f.write(f'        INCLUDE "{os.path.basename(path)}"\n')
    apply_patches()
    print(f'{len(order)} segments:',
          sum(1 for o in order if o[0] == 'engine'), 'engine,',
          sum(1 for o in order if o[0] != 'engine'), 'zx')

if __name__ == '__main__':
    main()
