/* The budget screen.  See budget.h.

      FISCAL BUDGET   TAX COLLECTED $1234
     >TAX RATE  7%
                 REQSTD   ALLCTD   FUND
      TRANSPORT    1234     1234   100%
      POLICE        500      500   100%
      FIRE          500      500   100%
      CASH FLOW $-123  FUNDS $10000>$9877
      Q A SELECT  O P CHANGE  ENTER OK   (the cursor keys on a platform with menus)

   The tax rate is 0..20 (the advisor complains from 12) and each funding level 0..100 in tens,
   as the Spectrum's.  Every change asks the engine for the figures again (budget_recalc). */
#include <stdint.h>
#include "engine.h"
#include "platform.h"
#include "budget.h"
#include "textfmt.h"
#ifdef HAVE_BUDGET
#define MAX_TAX 20
#define ROWS    8

static uint8_t sel;                     /* 0 tax rate, 1 transport, 2 police, 3 fire */

static const struct field fields[] = {
    { 0,  1, F_TEXT, 0,   "FISCAL BUDGET   TAX COLLECTED $" },
    { 0, 32, F_L24,  0,   V_tax_collected },
    { 1,  1, F_TEXT, 0,   "TAX RATE" },
    { 1, 12, F_U8,   '%', &SMC_tax_rate },
    { 2, 12, F_TEXT, 0,   "REQSTD   ALLCTD   FUND" },
    { 3,  1, F_TEXT, 0,   "TRANSPORT" },
    { 3, 18, F_U16,  0,   &V_Transport_Funding_Requested },
    { 3, 26, F_U16,  0,   &V_Transport_Funding_Allocated },
    { 3, 32, F_U8,   '%', &SMC_transport_percent },
    { 4,  1, F_TEXT, 0,   "POLICE" },
    { 4, 18, F_U16,  0,   &V_Budget_Police_Funding_Requested },
    { 4, 26, F_U16,  0,   &V_Police_Funding_Allocated },
    { 4, 32, F_U8,   '%', &SMC_police_percent },
    { 5,  1, F_TEXT, 0,   "FIRE" },
    { 5, 18, F_U16,  0,   &V_Budget_Fire_Funding_Requested },
    { 5, 26, F_U16,  0,   &V_Fire_Funding_Allocated },
    { 5, 32, F_U8,   '%', &SMC_fire_percent },
    { 6,  1, F_TEXT, 0,   "CASH FLOW $" },
    { 6, 19, F_S24,  0,   V_cashflow },
    { 6, 21, F_TEXT, 0,   "FUNDS $" },
    { 6, 29, F_U24,  0,   V_previous_money },
    { 6, 29, F_TEXT, 0,   ">$" },
    { 6, 39, F_U24,  0,   V_money_after_budget },
#ifdef HAVE_MENUS
    { 7,  1, F_TEXT, 0,   "CURSORS SELECT AND CHANGE  ENTER OK" },
#else
    { 7,  1, F_TEXT, 0,   "Q A SELECT  O P CHANGE  ENTER OK" },
#endif
};

static void draw(void)
{
    static const uint8_t item_row[4] = { 1, 3, 4, 5 };

    fmt_fields(fields, sizeof(fields) / sizeof(struct field));
    plat_text_puts(0, item_row[sel], ">");              /* the selected item */
    plat_flush();
}

/* Change the selected item by one step: 1 for tax, 10 for a funding level. */
static void change(int8_t dir)
{
    int16_t v, step;
    uint8_t *p;

    p = sel == 0 ? &SMC_tax_rate : sel == 1 ? &SMC_transport_percent :
        sel == 2 ? &SMC_police_percent : &SMC_fire_percent;
    step = sel == 0 ? 1 : 10;
    v = (int16_t)*p + dir * step;
    if (v < 0)
        v = 0;
    if (v > (sel == 0 ? MAX_TAX : 100))
        v = (sel == 0 ? MAX_TAX : 100);
    *p = (uint8_t)v;
    budget_recalc();
}

uint8_t budget_screen(void)
{
    uint8_t k;

    if (plat_text_rows() < ROWS || plat_text_cols() < 40)
        return 0;                       /* nowhere to put it: the engine's figures stand */
    sel = 0;
    budget_recalc();
    plat_text_clear();
    draw();
    for (;;) {
        k = plat_key();
        if (!k) {
            plat_idle();
            continue;
        }
        switch (k) {
        case KEY_UP:    if (sel) --sel; break;
        case KEY_DOWN:  if (sel < 3) ++sel; break;
        case KEY_LEFT: case '-': change(-1); break;
        case KEY_RIGHT: case '+': change(1); break;
#ifndef HAVE_MENUS
        case 'q': if (sel) --sel; break;
        case 'a': if (sel < 3) ++sel; break;
        case 'o': change(-1); break;
        case 'p': change(1); break;
#endif
        case KEY_ENTER: case ' ': case KEY_ESC:
            plat_text_clear();
            return 0;
        case CMD_QUIT:
            return 1;
        case CMD_REDRAW:
            plat_text_clear();
            break;
        default:
            continue;
        }
        draw();
    }
}

#endif
