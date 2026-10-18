/* The budget screen.  See budget.h.

      FISCAL BUDGET   TAX COLLECTED $1234
     >TAX RATE  7%
                 REQSTD   ALLCTD   FUND
      TRANSPORT    1234     1234   100%
      POLICE        500      500   100%
      FIRE          500      500   100%
      CASH FLOW $-123  FUNDS $10000>$9877
      Q A SELECT  O P CHANGE  ENTER OK

   The tax rate is 0..20 (the advisor complains from 12) and each funding level 0..100 in tens,
   as the Spectrum's.  Every change asks the engine for the figures again (budget_recalc). */
#include <stdint.h>
#include "engine.h"
#include "platform.h"
#include "budget.h"
#include "textfmt.h"

#define MAX_TAX 20
#define ROWS    8

static uint8_t sel;                     /* 0 tax rate, 1 transport, 2 police, 3 fire */

/* The row for one department: name, requested, allocated and funding level. */
static void dept_row(char *b, uint8_t item, const char *name, uint16_t requested, uint16_t allocated, uint8_t percent)
{
    fmt_blank(b);
    if (sel == item)
        b[0] = '>';
    fmt_str(b, 1, name);
    fmt_num(b, 18, requested);
    fmt_num(b, 26, allocated);
    fmt_num(b, 32, percent);
    b[32] = '%';
}

static void draw(void)
{
    char b[41];
    uint8_t n;

    fmt_blank(b);
    fmt_str(b, 1, "FISCAL BUDGET   TAX COLLECTED $");
    n = 32;
    {
        uint32_t t = fmt_u24(V_tax_collected);
        char tmp[8];
        uint8_t k = 8;
        do {
            tmp[--k] = (char)('0' + (uint8_t)(t % 10));
            t /= 10;
        } while (t && k);
        while (k < 8)
            b[n++] = tmp[k++];
        b[n] = 0;
    }
    plat_text_puts(0, 0, b);

    fmt_blank(b);
    if (sel == 0)
        b[0] = '>';
    fmt_str(b, 1, "TAX RATE");
    fmt_num(b, 12, SMC_tax_rate);
    b[12] = '%';
    plat_text_puts(0, 1, b);

    fmt_blank(b);
    fmt_str(b, 12, "REQSTD   ALLCTD   FUND");
    plat_text_puts(0, 2, b);
    dept_row(b, 1, "TRANSPORT", V_Transport_Funding_Requested, V_Transport_Funding_Allocated, SMC_transport_percent);
    plat_text_puts(0, 3, b);
    dept_row(b, 2, "POLICE", V_Budget_Police_Funding_Requested, V_Police_Funding_Allocated, SMC_police_percent);
    plat_text_puts(0, 4, b);
    dept_row(b, 3, "FIRE", V_Budget_Fire_Funding_Requested, V_Fire_Funding_Allocated, SMC_fire_percent);
    plat_text_puts(0, 5, b);

    fmt_blank(b);
    n = fmt_str(b, 1, "CASH FLOW $");
    {
        int32_t cf = fmt_s24(V_cashflow);
        char tmp[10];
        uint8_t k;
        for (k = 0; k < 10; ++k)
            tmp[k] = ' ';
        fmt_num(tmp, 10, cf);
        for (k = 0; k < 10 && tmp[k] == ' '; ++k)
            ;
        while (k < 10)
            b[n++] = tmp[k++];
    }
    n = fmt_str(b, n, "  FUNDS $");
    {
        uint32_t m[2];
        uint8_t k, j;
        char tmp[8];
        m[0] = fmt_u24(V_previous_money);
        m[1] = fmt_u24(V_money_after_budget);
        for (j = 0; j < 2; ++j) {
            for (k = 0; k < 8; ++k)
                tmp[k] = ' ';
            fmt_num(tmp, 8, (int32_t)m[j]);
            for (k = 0; k < 8 && tmp[k] == ' '; ++k)
                ;
            while (k < 8)
                b[n++] = tmp[k++];
            if (!j)
                n = fmt_str(b, n, ">$");
        }
    }
    b[n] = 0;
    plat_text_puts(0, 6, b);

    plat_text_puts(0, 7, " Q A SELECT  O P CHANGE  ENTER OK    ");
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
        case 'q': case KEY_UP:    if (sel) --sel; break;
        case 'a': case KEY_DOWN:  if (sel < 3) ++sel; break;
        case 'o': case KEY_LEFT: case '-': change(-1); break;
        case 'p': case KEY_RIGHT: case '+': change(1); break;
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
