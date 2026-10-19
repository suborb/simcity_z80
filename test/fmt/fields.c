/* The table drawing (ui/fmtfields.asm): every kind of field, drawn into rows that test/fmt/run.py reads back. */
#include <stdint.h>
#include "textfmt.h"

char rows[8][41];                       /* what plat_text_puts was given, by row */
uint8_t row_seen[8];

void plat_text_puts(uint8_t col, uint8_t row, const char *s)
{
    uint8_t i;
    (void)col;
    for (i = 0; i < 41 && s[i]; ++i)
        rows[row][i] = s[i];
    rows[row][i] = 0;
    row_seen[row] = 1;
}

uint8_t v8 = 255, v8zero = 0;
uint16_t v16 = 65535, v16small = 7;
uint8_t big24[3] = { 0xFF, 0xFF, 0xFF };            /* 16777215 */
uint8_t neg24[3] = { 0x85, 0xFF, 0xFF };            /* -123 */
uint8_t negbig[3] = { 0x00, 0x00, 0x80 };           /* -8388608 */
uint8_t zero24[3] = { 0, 0, 0 };
uint8_t k24[3] = { 0xA0, 0x0F, 0x00 };              /* 4000 */
uint8_t pos24[3] = { 0x39, 0x30, 0x00 };            /* 12345 */
const char *text = "HELLO";
const char *via_pointer = "THROUGH";

static const struct field table[] = {
    { 0,  0, F_TEXT, 0,   "AB" },
    { 0,  8, F_U8,   '%', &v8 },
    { 0, 12, F_U8,   0,   &v8zero },
    { 1,  6, F_U16,  0,   &v16 },
    { 1, 10, F_U16,  '%', &v16small },
    { 1, 25, F_U24,  0,   big24 },
    { 2, 10, F_S24,  0,   neg24 },
    { 2, 25, F_S24,  '$', negbig },
    { 2, 30, F_S24,  0,   pos24 },
    { 3,  3, F_L24,  0,   pos24 },
    { 3, 10, F_L24,  0,   zero24 },
    { 3, 20, F_K24,  0,   k24 },
    { 3, 30, F_K24,  0,   zero24 },
    { 4,  0, F_STR,  0,   &text },
    { 4, 10, F_STR,  0,   &via_pointer },
    { 4, 20, F_U24,  0,   zero24 },
};

int main(void)
{
    fmt_fields(table, 16);
    return 0;
}
