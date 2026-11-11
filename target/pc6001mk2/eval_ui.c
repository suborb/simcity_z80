/* The evaluation screen in the EVAL overlay (a track of its own), with copies of what it shares with the budget screen (which is in the MODAL overlay): the colouring of text and the
   bars (plat_text.c) and the loop over a screen's fields (fmt_fields_each, fmt_attr_runs: ui/textfmt.c), so that neither overlay has to hold both screens' colour code.  One translation unit:
   the shared names are renamed here, so that they do not clash with the budget's copies. */
#define MK2_EVAL_UNIT
#include <stdint.h>
#define plat_text_attr  eplat_text_attr
#define plat_bar        eplat_bar
#define fmt_fields_each efmt_fields_each
#define fmt_attr_runs   efmt_attr_runs
#include "platform.h"
#include "textfmt.h"
#include "plat_text.c"

#ifdef HAVE_TEXT_COLOUR
void fmt_fields_each(const struct field *f, uint8_t n, void (*done)(uint8_t row))
{
    uint8_t i = 0, j, row;

    while (i < n) {
        row = f[i].row;
        for (j = i; j < n && f[j].row == row; ++j)
            ;
        fmt_fields(f + i, (uint8_t)(j - i));
        done(row);
        i = j;
    }
}

void fmt_attr_runs(const struct attr_run *r, uint8_t n, uint8_t row)
{
    for (; n; --n, ++r)
        if (r->row == row)
            plat_text_attr((uint8_t)(r->col + fmt_col0), row, r->len, r->attr);   /* (fmt_col0: the screen is centred) */
}
#endif

#include "evaluation.c"
