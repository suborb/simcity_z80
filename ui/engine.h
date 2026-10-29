/* The portable engine, as seen from C.  Implemented by engine/engine_c.asm and
   platform/common/hooks.asm.  See engine/PLATFORM_INTERFACE.md. */
#ifndef ENGINE_H
#define ENGINE_H

#include <stdint.h>

/* The size of the map: the Spectrum's 96x96 unless a platform builds a bigger one (-DMAP_W=120 -DMAP_H=100 for the C and the assembler: the
   engine's code is made for 96 and 120 wide, engine/mapsize.inc).  The minimaps' layout follows from it, as engine/mapsize.inc has it. */
#ifndef MAP_W
#define MAP_W 96
#endif
#ifndef MAP_H
#define MAP_H 96
#endif
#define MM25_W        (MAP_W / 4)               /* the coverage maps: a cell to 4x4 tiles */
#define MM25_H        (MAP_H / 4)
#define MM25_SIZE     (MM25_W * MM25_H)
#define MM50_W        (MAP_W / 2)               /* pollution and traffic: 2x2 */
#define MM50_H        (MAP_H / 2)
#define MM50_SIZE     (MM50_W * MM50_H)
#define MM_POWER_ROW  (MAP_W / 8)               /* the power map: a bit a tile */
#define MM_FIRE_AT      0                       /* where each begins in minimaps[] */
#define MM_POLICE_AT    MM25_SIZE
#define MM_POLLUTION_AT (2 * MM25_SIZE)
#define MM_TRAFFIC_AT   (2 * MM25_SIZE + MM50_SIZE)
#define MM_POWER_AT     (2 * MM25_SIZE + 2 * MM50_SIZE)
#ifdef POWER_SHOWN                      /* a second power map, which the mini map draws from (engine/mapsize.inc) */
#define MM_POWER_SHOWN_AT (MM_POWER_AT + MM_POWER_ROW * MAP_H)
#define MM_BYTES        (MM_POWER_SHOWN_AT + MM_POWER_ROW * MAP_H)
#else
#define MM_POWER_SHOWN_AT MM_POWER_AT
#define MM_BYTES        (MM_POWER_AT + MM_POWER_ROW * MAP_H)
#endif

/* ---- calls ---- */
extern void sim_new_city(void);     /* new random city from V_InitialSeed */
extern void sim_init(void);
extern void sim_loaded(void);       /* a city is in levelmap: abandon the tick and reset the simulation (money, date) */
extern void sim_tick(void);         /* one simulation tick (about 6 million T-states), blocks */
extern uint8_t sim_step(void);      /* run the simulation one slice (a map row); 1 = a tick has just completed;
                                       2 = it is waiting for the budget (V_wait_for_budget_confirm) */
extern void sim_periodic(void);     /* uses engine_a = frame counter */
extern void tool_apply(void);       /* uses V_selected_tool, V_pointer_charxy, V_view_topleft */
extern void view_fetch(void);       /* view_x, view_y -> view_art, view_attr */

/* ---- call arguments and results ---- */
extern uint8_t engine_a;
extern uint8_t view_x, view_y;
extern uint8_t *view_art;           /* 8 bytes of 1bpp art */
extern uint8_t view_attr;
/* The engine's pictures: NUM_TILE_ART map tiles then NUM_ZONE_ART large-zone pieces,
   8 bytes each, contiguous.  view_art always points into this table. */
#define NUM_TILE_ART 94
#define NUM_ZONE_ART 251
extern const uint8_t view_tile_art[];           /* Spectrum-style attribute byte */

/* ---- the map ---- */
extern uint8_t levelmap[MAP_W * MAP_H];
/* The coverage and density maps (engine/buffers.asm): fire and police a cell to 4x4 tiles, pollution and traffic to 2x2, and power
   a bit a tile (a row is MAP_W / 8 bytes); at 96x96 that is 24x24 at +0 and +576, 48x48 at +1152 and +3456, and the power map at +5760. */
extern uint8_t minimaps[MM_BYTES];

/* ---- state ---- */
extern uint8_t  V_month;            /* 0..11 */
extern uint16_t V_year;
extern uint8_t  V_money[3];         /* 24 bit, little endian */
extern uint8_t  V_CityPop[3];
extern int16_t  V_RValve, V_CValve, V_IValve;   /* demand */
extern uint8_t  V_alertmessage;     /* index into text_alerts */
extern uint8_t  V_selected_tool;
extern uint8_t  V_pointer_charxy[2];            /* column in view, row in view + 8 */
extern uint8_t  V_view_topleft[2];              /* column, row of the view's top left */
extern uint16_t V_InitialSeed;
extern uint8_t  V_view_tick;
extern uint8_t  V_sim_loop_counter;
extern uint8_t  V_TrafficAverage, V_PolluteAverage, V_concern_crime;
extern uint8_t  V_transport_active;
extern uint8_t  V_CCxy[2];                      /* the city's centre: x then y */
extern const uint8_t *V_disaster_at;            /* the cell a fire, flood or meltdown last set (0: none yet); the UI clears it */
extern uint8_t  V_meltdown_triggered;           /* 1 from a meltdown starting until the fallout is down */
extern uint8_t  V_aircrash_active, V_CrashXY[2];
extern uint8_t  V_tornado_pos[2];
extern uint8_t  V_disaster_option;              /* a disaster to start (1 fire .. 6 meltdown); the engine takes it and clears it */

/* ---- settings ---- */
extern uint8_t V_difficulty;        /* 0 easy, 1 medium, 2 hard */
extern uint8_t SMC_tax_rate;
extern uint8_t SMC_transport_percent, SMC_police_percent, SMC_fire_percent;
extern uint8_t V_simulation_speed;  /* 0 fast, 1 normal, 2 slow, 3 paused */
extern uint8_t V_auto_budget;
extern uint8_t V_disaster_reset;    /* non-zero: no random disasters */
extern uint8_t V_auto_bulldoze;
extern uint8_t V_power_type_chosen; /* power plant tool: 1 nuclear, else coal */
/* ---- the evaluation (see disassembly: print_evaluation_concerns) ---- */
extern uint8_t  V_display_population[3], V_population[3], V_prev_year_population[3], V_previous_city_score[3];
extern uint16_t V_LVAverage, V_unPwrdZCnt, V_unemployment;
extern uint8_t  V_concern_house_price;

/* ---- the budget (see engine/budget.asm) ---- */
extern uint8_t V_wait_for_budget_confirm;   /* sim_step returns 2 while set; the UI clears it once it has shown the budget */
extern void budget_recalc(void);    /* figures from the tax rate and funding levels; not V_money */
extern uint8_t  V_tax_collected[3];             /* 24 bit */
extern uint16_t V_Transport_Funding_Requested, V_Budget_Police_Funding_Requested, V_Budget_Fire_Funding_Requested;
extern uint16_t V_Transport_Funding_Allocated, V_Police_Funding_Allocated, V_Fire_Funding_Allocated;
extern uint8_t  V_expenditure[3], V_cashflow[3];    /* cash flow is signed */
extern uint8_t  V_previous_money[3], V_money_after_budget[3];
extern uint8_t map_dirty;           /* set by the engine whenever the map changes */

#endif
