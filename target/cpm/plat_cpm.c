/* Generic CP/M platform (the display; the keys and files are in cpm_common.c): the BDOS console (function 6) and an ANSI terminal, or a VT52 with -DCPM_VT52.  The terminal needs 80x24 and cursor addressing;
   everything else (the map, the panel, the menus) is characters.  Output is collected and written at the end of a frame, a run of cells in a row
   sharing one cursor move. */
#include <stdint.h>
#include "platform.h"

#define OUT_MAX 128

extern void cpm_conout(uint8_t c) __z88dk_fastcall;

static uint8_t out[OUT_MAX];
static uint8_t out_n;
static uint8_t cur_col = 255, cur_row;     /* where the terminal's cursor is, if known */

void plat_flush(void)
{
    uint8_t i;

    for (i = 0; i < out_n; ++i)
        cpm_conout(out[i]);
    out_n = 0;
}

static void emit(uint8_t c)
{
    if (out_n == OUT_MAX)
        plat_flush();
    out[out_n++] = c;
}

static void emit_num(uint8_t n)
{
    if (n >= 100) {
        emit((uint8_t)('0' + n / 100));
        n %= 100;
        emit((uint8_t)('0' + n / 10));
    } else if (n >= 10)
        emit((uint8_t)('0' + n / 10));
    emit((uint8_t)('0' + n % 10));
}

static void move(uint8_t col, uint8_t row)
{
    if (col == cur_col && row == cur_row)
        return;
#ifdef CPM_VT52
    emit(27); emit('Y'); emit((uint8_t)(32 + row)); emit((uint8_t)(32 + col));
#else
    emit(27); emit('['); emit_num((uint8_t)(row + 1)); emit(';'); emit_num((uint8_t)(col + 1)); emit('H');
#endif
    cur_col = col;
    cur_row = row;
}

void plat_clear(void)
{
#ifdef CPM_VT52
    emit(27); emit('H'); emit(27); emit('J');
#else
    emit(27); emit('['); emit('2'); emit('J'); emit(27); emit('['); emit('H');
#endif
    cur_col = 0;
    cur_row = 0;
}

void plat_init(void)
{
    plat_clear();
}

void plat_exit(void)
{
    plat_clear();
    plat_flush();
}

void plat_put(uint8_t col, uint8_t row, uint8_t ch)
{
    move(col, row);
    emit(ch);
    if (++cur_col >= PLAT_FIXED_COLS)       /* (the terminal's cursor would wrap or stick there: unknown) */
        cur_col = 255;
}

void plat_puts(uint8_t col, uint8_t row, const char *s)
{
    while (*s)
        plat_put(col++, row, (uint8_t)*s++);
}

void plat_text_puts(uint8_t col, uint8_t row, const char *s) { plat_puts(col, row, s); }
void plat_text_clear(void) { plat_clear(); }
