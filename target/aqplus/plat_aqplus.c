/* Aquarius+ platform: 320x200 bitmap tiles and the z88dk generic console for text. */
#include <stdint.h>
#include <conio.h>
#include <input.h>
#include <sys/ioctl.h>
#include "engine.h"
#include "platform.h"

static uint16_t aq_mode;
static uint16_t clock_count;

/* Aquarius+ palette entries for Spectrum colours, without and with BRIGHT. */
static const uint8_t aq_colours[16] = {
    0, 11, 14, 10, 13, 9, 3, 8,
    0, 4, 1, 5, 2, 6, 3, 7
};

static uint8_t aq_attr_byte(uint8_t attr)
{
    static uint8_t last_in = 0xFF, last_out;

    if (attr != last_in) {
        uint8_t b = (attr & 0x40) ? 8 : 0;

        last_in = attr;
        last_out = (uint8_t)((aq_colours[(attr & 7) | b] << 4) | aq_colours[((attr >> 3) & 7) | b]);
    }
    return last_out;
}

/* target/aqplus/plat_aqplus.asm */
extern void aq_blit8(uint8_t col, uint8_t row, const uint8_t *art, uint8_t colour, uint8_t inverse) __smallc;
extern void plat_aq_printc(uint8_t col, uint8_t row, uint8_t ch) __smallc;
extern const uint8_t aq_icons[];

static void aq_set_mode(uint16_t m)
{
    aq_mode = m;
    console_ioctl(IOCTL_GENCON_SET_MODE, &aq_mode);
}

void plat_init(void) { aq_set_mode(4); clrscr(); }
void plat_exit(void) { aq_set_mode(1); clrscr(); }

uint8_t plat_cols(void)
{
    unsigned int x, y;
    screensize(&x, &y);
    return (uint8_t)x;
}

uint8_t plat_rows(void)
{
    unsigned int x, y;
    screensize(&x, &y);
    return (uint8_t)y;
}

void plat_clear(void) { clrscr(); }
void plat_put(uint8_t col, uint8_t row, uint8_t ch) { plat_aq_printc(col, row, ch); }

void plat_puts(uint8_t col, uint8_t row, const char *s)
{
    for (; *s && col < 40; ++col)       /* not past the right edge: it would wrap */
        plat_aq_printc(col, row, (uint8_t)*s++);
}

uint8_t plat_text_cols(void) { return plat_cols(); }
uint8_t plat_text_rows(void) { return plat_rows(); }
void plat_text_clear(void) { plat_clear(); }
void plat_text_puts(uint8_t col, uint8_t row, const char *s) { plat_puts(col, row, s); }

void plat_put_tile(uint8_t col, uint8_t row, const uint8_t *art, uint8_t attr, uint8_t inverse)
{
    aq_blit8(col, row, art, aq_attr_byte(attr), inverse);
}

static void put_bitmap(uint8_t col, uint8_t row, const uint8_t *art, uint8_t attr)
{
    aq_blit8(col, row, art, aq_attr_byte(attr), 0);
}

void plat_put_bitmap(uint8_t col, uint8_t row, const uint8_t *art)
{
    put_bitmap(col, row, art, 0x07);                    /* white on black */
}

/* The tool icons: 16x16 pictures, four cells each. */
#define NUM_ICONS 14

void plat_icons(uint8_t selected)
{
    uint8_t i, r, c, k, cell;
    uint8_t art[8];

    for (i = 0; i < NUM_ICONS; ++i)
        for (r = 0; r < 2; ++r)
            for (c = 0; c < 2; ++c) {
                cell = (uint8_t)(i * 4 + r * 2 + c);
                for (k = 0; k < 8; ++k)
                    art[k] = i == selected ? (uint8_t)(aq_icons[cell * 8 + k] ^ 0xFF) : aq_icons[cell * 8 + k];
                put_bitmap((uint8_t)(i * 2 + c), (uint8_t)(1 + r), art, (uint8_t)(aq_icons[NUM_ICONS * 32 + cell] & 0x7F));
            }
}

uint8_t plat_key(void) { return (uint8_t)in_Inkey(); }
uint16_t plat_clock(void) { return clock_count; }
void plat_idle(void) { ++clock_count; }
void plat_flush(void) {}
