# Engine / platform interface

The engine in this directory is a copy of the simulation half of the Spectrum
program (see `PORTING.md`; `disassembly/sim_game.asm` is the original it was taken from).  Build it with
`PORTABLE` defined, include `engine/engine.asm` in the platform's program, and
supply what is listed here.  `target/test/test_platform.asm` is the smallest
complete example: every item below is either a fixed value or a `ret`.

The engine contains no keyboard, screen, sound or timing code.

## What the engine provides

### Entry points (engine/engine_api.asm)

| Routine | Does |
|---|---|
| `sim_new_city` | Reset date and funds (from `V_difficulty`), generate a random landscape from `V_InitialSeed`. Calls the landscape hooks below for its progress display. |
| `sim_init` | Reset date, funds and all simulation variables; the map is left alone. |
| `sim_tick` | One simulation tick: a full 96x96 pass. Every month-length it runs the budget and advances the month. |
| `sim_task_reset` | Cooperative mode (below): abandon any tick in progress. Call after `sim_init`/`sim_new_city`. |
| `sim_step` | Cooperative mode: run the simulation to its next yield, about one map row (1/96 of a tick). Returns `L` = 1 when a whole tick has just completed. Preserves all registers except `HL`. |
| `sim_periodic` | `A` = frame counter. Moves the aircrash, tornado and transport sprites when `A & 15 = 0`; starts a pending disaster at `4`; draws the next random disaster at `5`. |
| `place_zone_direct` | `HL` = levelmap address, `BC` = (rows, columns), `IX` = tile data. Copies a rectangle of tiles. |

Registers are not preserved (except as noted for `sim_step`). Call with interrupts in any state.

`sim_tick` blocks for a whole tick (about two seconds at 3.5MHz).  To keep the
UI responsive call `sim_task_reset` once and then `sim_step` a few times per
UI frame until it reports a completed tick; the simulation runs on its own
256-byte stack (`engine/coop.asm`) and switches back at the end of each map
row.  `sim_init` must be called before the first tick either way.  If a budget
needs the player (`V_auto_budget` = 0) `sim_step` returns 2 (instead of 0 or 1) and goes on
returning 2 until the caller has shown the budget and set `V_wait_for_budget_confirm` to 0;
nothing is called back.  (A `sim_tick` run directly calls `ui_budget_confirm`.)  The tools (`tool_apply`) may be used
between slices, as on the Spectrum.

### State the platform may read (all plain labels)

| Label | Meaning |
|---|---|
| `levelmap` (9216 bytes) | The 96x96 map, row major. Tile numbers: 0 water, 2 dirt, 7/8 road, 20.. rail, 33.. power line, bit 7 set = part of a large zone. |
| `minimaps` (6912 bytes) | Coverage and density maps; see the comment at its definition. |
| `V_month`, `V_year`, `V_money` (3 bytes) | Date and funds. |
| `V_CityPop` (3 bytes), `V_display_population` | Population. |
| `V_RValve`, `V_CValve`, `V_IValve` | Residential/commercial/industrial demand (signed 16 bit). |
| `V_alertmessage` | Last advisor message number (see `text_table` in the Spectrum UI for the wording). |
| `V_transport_active`, `V_transport_pos`, `V_transport_sprite` | Moving transport sprite request. |
| `V_money_after_budget`, `V_Transport_Funding_*`, `V_Budget_*_Funding_Requested`, `V_Police_Funding_Allocated`, `V_Fire_Funding_Allocated`, `V_tax_collected`, `V_expenditure`, `V_cashflow` | Budget state for the budget dialog. |

## What the platform must provide

### Settings (read by the engine; write them as the player changes options)

| Label | Size | Meaning |
|---|---|---|
| `V_difficulty` | byte | 0 easy, 1 medium, 2 hard (start funds, tax penalty). |
| `SMC_tax_rate` | byte | Tax rate in percent. |
| `SMC_transport_percent`, `SMC_police_percent`, `SMC_fire_percent` | byte | Budget funding levels, 0-100. |
| `V_simulation_speed` | byte | 0 fast, 1 normal, 2 slow, 3 paused. |
| `V_auto_budget` | byte | Non-zero: the engine runs the budget itself. Zero: it waits for the player (`sim_step` returns 2; `sim_tick` calls `ui_budget_confirm`). |
| `V_disaster_reset` | byte | Non-zero disables random disasters. |
| `V_InitialSeed` | word | Seed for landscape generation (defined by the engine; the platform writes it before `sim_new_city`). |

(`SMC_` is historical: on the Spectrum these live inside the budget screen's code.)

### Hooks (the engine `call`s these)

| Label | Called when | Contract |
|---|---|---|
| `ui_budget_confirm` | Annual budget with `V_auto_budget = 0` | Modal. Show the budget (the engine's `calculate_tax`, `run_budget` compute it), let the player adjust, and return with the final funds in `V_money_after_budget`. |
| `play_place_sound` | A tool is refused (the place is taken, or it is not dirt) | May do nothing. |
| `play_built_sound` | Money was spent by a tool: something was placed (`PORTABLE` builds only) | Keeps every register and flag. May do nothing. |
| `play_crash_sound` | Aircrash | May do nothing. |
| `play_rising_tone` | Fire starts | May do nothing. |
| `play_falling_tone` | Flood starts | May do nothing. |
| `soundfx1` | Earthquake rumble, once per step | `E` = pitch. May do nothing. |
| `cls_map`, `cls_print_topbox`, `render_status_bar` | Start of `sim_new_city` | Progress display for landscape generation; `IX` = `text_generating_landscape`. May do nothing. |
| `text_generating_landscape` | (data label) | Any bytes; passed in `IX` to the above. |
| `textcol`, `print_budget_amounts` | Budget recalculation | May do nothing; `textcol` is a byte. |

## Memory layout: sections

The engine can run from ROM.  In a PORTABLE build (`engine/sections.asm`) every piece goes in
the z88dk section it belongs in:

| Section | Contents |
|---|---|
| `code_user` | instructions |
| `rodata_user` | tables nothing writes (`D_*`, the zone tile tables, the map art) |
| `data_user` | variables (`V_*`), which start with the values in the source |
| `bss_user` | buffers: `levelmap`, `minimaps`, the power queue, the coroutine stack |

A platform with a ROM puts `code_user` and `rodata_user` there and gives the rest RAM; the
crt copies `data_user` from ROM and clears `bss_user`.  The engine has no self-modifying
code in this build: the nine operands the Spectrum program patches are ordinary variables
(the `V_` variables in `engine/engine_api.asm`).  `test/golden` runs the engine from an image laid out
this way and fails if anything below `__data_user_head` changes, and
`tools/find_dead.py --smc` fails if any instruction stores into a label that is code.

Two things to remember when changing the engine:

* a table and the variable after it are no longer neighbours.  If code reads a table with a
  count larger than the table (the original's auto-bulldoze search does, and reads the next
  variable as a seventh entry), say so explicitly, as in the patch for `D_autobulldoze_tile_types`;
* the platform's own variables (`V_difficulty` and the other settings) belong in `data_user`
  too: `platform/common/hooks.asm` shows how.

## Rules for engine changes

* Never rename or remove an `Lxxxx` label; they are the original addresses.
* No absolute addresses: use labels.
* Anything platform specific goes inside `IFDEF PORTABLE` / `IFNDEF PORTABLE`
  so that the Spectrum build stays byte-identical. `test/golden/run.py`
  checks that, and that the portable engine behaves exactly like the original.
