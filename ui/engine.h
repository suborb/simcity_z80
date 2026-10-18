/* The portable engine, as seen from C.  Implemented by engine/engine_c.asm and
   platform/common/hooks.asm.  See engine/PLATFORM_INTERFACE.md. */
#ifndef ENGINE_H
#define ENGINE_H

#include <stdint.h>

#define MAP_W 96
#define MAP_H 96

/* ---- calls ---- */
extern void sim_new_city(void);     /* new random city from V_InitialSeed */
extern void sim_init(void);
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
/* The coverage and density maps (engine/engine_defs or the disassembly's minimaps): fire 24x24 at +0, police 24x24
   at +576, pollution 48x48 at +1152, traffic 48x48 at +3456, power 1 bit a tile (12 bytes a row) at +5760. */
extern uint8_t minimaps[6912];

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
