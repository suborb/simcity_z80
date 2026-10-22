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
#define ROWS    MODAL_ROWS
/* The compact design is an eight-row grid.  On an intermediate-height screen spread it over the available rows. */
#define BUDGET_ROW(n)  (((n) * (MODAL_ROWS - 1) + 3) / 7)

static uint8_t sel;                     /* 0 tax rate, 1 transport, 2 police, 3 fire */

#if MODAL_COLS < 40
/* The 32 column arrangement: the same groups, with the numbers packed under their headings. */
static const struct field fields[] = {
    {  0,  1, F_TEXT, 0,   "FISCAL BUDGET" },
    {  2,  1, F_TEXT, 0,   "TAX RATE" },
    {  2, 12, F_U8,   '%', &SMC_tax_rate },
    {  4,  1, F_TEXT, 0,   "TAX COLLECTED $" },
    {  4, 16, F_L24,  0,   V_tax_collected },
    {  6, 11, F_TEXT, 0,   "REQSTD ALLCTD FUND" },
    {  8,  1, F_TEXT, 0,   "TRANSPORT" },
    {  8, 17, F_U16,  0,   &V_Transport_Funding_Requested },
    {  8, 24, F_U16,  0,   &V_Transport_Funding_Allocated },
    {  8, 28, F_U8,   '%', &SMC_transport_percent },
    { 10,  1, F_TEXT, 0,   "POLICE" },
    { 10, 17, F_U16,  0,   &V_Budget_Police_Funding_Requested },
    { 10, 24, F_U16,  0,   &V_Police_Funding_Allocated },
    { 10, 28, F_U8,   '%', &SMC_police_percent },
    { 12,  1, F_TEXT, 0,   "FIRE" },
    { 12, 17, F_U16,  0,   &V_Budget_Fire_Funding_Requested },
    { 12, 24, F_U16,  0,   &V_Fire_Funding_Allocated },
    { 12, 28, F_U8,   '%', &SMC_fire_percent },
    { 15,  1, F_TEXT, 0,   "CASH FLOW" },
    { 15, 22, F_S24,  0,   V_cashflow },
    { 17,  1, F_TEXT, 0,   "PREVIOUS FUNDS $" },
    { 17, 17, F_L24,  0,   V_previous_money },
    { 19,  1, F_TEXT, 0,   "CURRENT FUNDS $" },
    { 19, 16, F_L24,  0,   V_money_after_budget },
    { 23,  0, F_TEXT, 0,   "Q A SELECT  O P CHANGE  ENTER OK" },
};
#elif MODAL_ROWS >= 24
/* The full-screen arrangement follows the Spectrum's groups, while using the extra height to make the money
   figures and each service line independently readable. */
static const struct field fields[] = {
    {  0,  1, F_TEXT, 0,   "FISCAL BUDGET" },
    {  2,  1, F_TEXT, 0,   "TAX RATE" },
    {  2, 12, F_U8,   '%', &SMC_tax_rate },
    {  4,  1, F_TEXT, 0,   "TAX COLLECTED $" },
    {  4, 16, F_L24,  0,   V_tax_collected },
    {  6, 11, F_TEXT, 0,   "REQUESTED  ALLOCATED  FUNDING" },
    {  8,  1, F_TEXT, 0,   "TRANSPORT" },
    {  8, 20, F_U16,  0,   &V_Transport_Funding_Requested },
    {  8, 31, F_U16,  0,   &V_Transport_Funding_Allocated },
    {  8, 39, F_U8,   '%', &SMC_transport_percent },
    { 10,  1, F_TEXT, 0,   "POLICE" },
    { 10, 20, F_U16,  0,   &V_Budget_Police_Funding_Requested },
    { 10, 31, F_U16,  0,   &V_Police_Funding_Allocated },
    { 10, 39, F_U8,   '%', &SMC_police_percent },
    { 12,  1, F_TEXT, 0,   "FIRE" },
    { 12, 20, F_U16,  0,   &V_Budget_Fire_Funding_Requested },
    { 12, 31, F_U16,  0,   &V_Fire_Funding_Allocated },
    { 12, 39, F_U8,   '%', &SMC_fire_percent },
    { 15,  1, F_TEXT, 0,   "CASH FLOW" },
    { 15, 20, F_S24,  0,   V_cashflow },
    { 17,  1, F_TEXT, 0,   "PREVIOUS FUNDS $" },
    { 17, 18, F_L24,  0,   V_previous_money },
    { 19,  1, F_TEXT, 0,   "CURRENT FUNDS $" },
    { 19, 18, F_L24,  0,   V_money_after_budget },
#ifdef HAVE_MENUS
    { 23,  1, F_TEXT, 0,   "CURSORS SELECT AND CHANGE  ENTER OK" },
#else
    { 23,  1, F_TEXT, 0,   "Q A SELECT  O P CHANGE  ENTER OK" },
#endif
};
#else
static const struct field fields[] = {
    { BUDGET_ROW(0),  1, F_TEXT, 0,   "FISCAL BUDGET   TAX COLLECTED $" },
    { BUDGET_ROW(0), 32, F_L24,  0,   V_tax_collected },
    { BUDGET_ROW(1),  1, F_TEXT, 0,   "TAX RATE" },
    { BUDGET_ROW(1), 12, F_U8,   '%', &SMC_tax_rate },
    { BUDGET_ROW(2), 12, F_TEXT, 0,   "REQSTD   ALLCTD    FUND" },
    { BUDGET_ROW(3),  1, F_TEXT, 0,   "TRANSPORT" },
    { BUDGET_ROW(3), 18, F_U16,  0,   &V_Transport_Funding_Requested },
    { BUDGET_ROW(3), 27, F_U16,  0,   &V_Transport_Funding_Allocated },
    { BUDGET_ROW(3), 34, F_U8,   '%', &SMC_transport_percent },
    { BUDGET_ROW(4),  1, F_TEXT, 0,   "POLICE" },
    { BUDGET_ROW(4), 18, F_U16,  0,   &V_Budget_Police_Funding_Requested },
    { BUDGET_ROW(4), 27, F_U16,  0,   &V_Police_Funding_Allocated },
    { BUDGET_ROW(4), 34, F_U8,   '%', &SMC_police_percent },
    { BUDGET_ROW(5),  1, F_TEXT, 0,   "FIRE" },
    { BUDGET_ROW(5), 18, F_U16,  0,   &V_Budget_Fire_Funding_Requested },
    { BUDGET_ROW(5), 27, F_U16,  0,   &V_Fire_Funding_Allocated },
    { BUDGET_ROW(5), 34, F_U8,   '%', &SMC_fire_percent },
    { BUDGET_ROW(6),  1, F_TEXT, 0,   "CASH FLOW" },                   /* room for 7 digit funds: the row is 40 wide */
    { BUDGET_ROW(6), 18, F_S24,  0,   V_cashflow },
    { BUDGET_ROW(6), 20, F_TEXT, 0,   "FUNDS" },
    { BUDGET_ROW(6), 32, F_U24,  0,   V_previous_money },
    { BUDGET_ROW(6), 32, F_TEXT, 0,   ">" },
    { BUDGET_ROW(6), 40, F_U24,  0,   V_money_after_budget },
#ifdef HAVE_MENUS
    { BUDGET_ROW(7),  1, F_TEXT, 0,   "CURSORS SELECT AND CHANGE  ENTER OK" },
#else
    { BUDGET_ROW(7),  1, F_TEXT, 0,   "Q A SELECT  O P CHANGE  ENTER OK" },
#endif
};
#endif

static void draw(void)
{
#if MODAL_COLS < 40 || MODAL_ROWS >= 24
    static const uint8_t item_row[4] = { 2, 8, 10, 12 };
#else
    static const uint8_t item_row[4] = { BUDGET_ROW(1), BUDGET_ROW(3), BUDGET_ROW(4), BUDGET_ROW(5) };
#endif

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

    if (plat_text_rows() < ROWS || plat_text_cols() < MODAL_COLS)
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
