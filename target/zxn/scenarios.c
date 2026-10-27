/* ZX Spectrum Next scenario picker and loader (the platform's side of HAVE_SCENARIOS: ui/platform.h).  Scenario records are packed in
   the NEX's banks 23..34 by tools/convert_amiga_scenarios.py. */
#include <stdint.h>
#include <string.h>
#include "engine.h"
#include "platform.h"

#define SCENARIO_COUNT 8
#define FIRST_PAGE 46
#define MAP_BYTES (MAP_W * MAP_H)
#define PREVIEW_AT MAP_BYTES
#define POWER_AT (MAP_BYTES * 2)
#define POWER_BYTES (MM_POWER_ROW * MAP_H)
#define TRAFFIC_AT (POWER_AT + POWER_BYTES)
#define TRAFFIC_BYTES MM50_SIZE
#define META_AT (TRAFFIC_AT + TRAFFIC_BYTES)
#define META_BYTES 1024
#define RECORD_BYTES (META_AT + META_BYTES)
#define MAP_CHUNK 128

extern void zxn_bank_read(uint8_t *dst, uint8_t page, uint16_t off, uint16_t len);

static uint8_t metadata[META_BYTES];
static uint8_t rowbuf[MAP_W];
static uint8_t mapbuf[MAP_CHUNK];

static void scenario_read(uint32_t offset, uint8_t *dst, uint16_t len)
{
    while (len) {
        uint8_t page = (uint8_t)(FIRST_PAGE + offset / 8192UL);
        uint16_t off = (uint16_t)(offset % 8192UL);
        uint16_t n = (uint16_t)(8192 - off);
        if (n > len) n = len;
        zxn_bank_read(dst, page, off, n);
        dst += n;
        offset += n;
        len -= n;
    }
}

static uint32_t record_at(uint8_t index)
{
    return (uint32_t)index * RECORD_BYTES;
}

static void show_preview(uint8_t index)
{
    uint8_t y;
    uint32_t base = record_at(index) + PREVIEW_AT;
    for (y = 0; y < MAP_H; ++y) {
        scenario_read(base + (uint32_t)y * MAP_W, rowbuf, MAP_W);
        plat_scenario_preview_row((uint8_t)(64 + y), 136, rowbuf);
    }
}

static void text_field(uint8_t col, uint8_t row, uint8_t at, uint8_t len)
{
    char s[33];
    uint8_t n = len > 32 ? 32 : len;
    memcpy(s, metadata + at, n);
    s[n] = 0;
    plat_text_puts(col, row, s);
}

static void show_scenario(uint8_t index, uint8_t page)
{
    uint8_t title_len, event_len, row = 7;
    uint16_t desc_len, start;
    uint16_t year;

    scenario_read(record_at(index) + META_AT, metadata, META_BYTES);
    year = (uint16_t)metadata[0] | ((uint16_t)metadata[1] << 8);
    title_len = metadata[2];
    event_len = metadata[3];
    desc_len = (uint16_t)metadata[4] | ((uint16_t)metadata[5] << 8);
    plat_text_clear();
    plat_text_puts(0, 0, "CHOOSE SCENARIO");
    text_field(0, 2, 8, title_len);
    plat_text_puts(0, 3, "YEAR:");
    /* Numeric year without pulling in printf on the Z80. */
    {
        char y[5];
        y[0] = (char)('0' + year / 1000 % 10);
        y[1] = (char)('0' + year / 100 % 10);
        y[2] = (char)('0' + year / 10 % 10);
        y[3] = (char)('0' + year % 10);
        y[4] = 0;
        plat_text_puts(6, 3, y);
    }
    text_field(0, 4, 32, event_len);
    start = (uint16_t)page * 256;
    while (start < desc_len && row < 23) {
        uint8_t n = (uint8_t)(desc_len - start);
        char s[17];
        if (n > 16) n = 16;
        memcpy(s, metadata + 64 + start, n);
        s[n] = 0;
        plat_text_puts(0, row++, s);
        start += n;
    }
    plat_text_puts(0, 23, "ARROWS SELECT/PAGE ENTER");
    show_preview(index);
    plat_flush();
}

static uint8_t text_pages(void)
{
    uint16_t len = (uint16_t)metadata[4] | ((uint16_t)metadata[5] << 8);
    uint8_t pages = (uint8_t)((len + 255) >> 8);
    return pages ? pages : 1;
}

uint8_t plat_scenario_choose(void)
{
    uint8_t index = 0, page = 0, k;
    show_scenario(index, page);
    for (;;) {
        k = plat_key();
        if (k == KEY_ESC) return 0xff;
        if (k == KEY_ENTER) return index;
        if (k == KEY_LEFT || k == KEY_RIGHT) {
            index = (uint8_t)((index + (k == KEY_RIGHT ? 1 : SCENARIO_COUNT - 1)) % SCENARIO_COUNT);
            page = 0;
            show_scenario(index, page);
        } else if (k == KEY_UP || k == KEY_DOWN) {
            uint8_t pages = text_pages();
            page = (uint8_t)((page + (k == KEY_DOWN ? 1 : pages - 1)) % pages);
            show_scenario(index, page);
        } else if (!k) {
            plat_idle();
        }
    }
}

uint16_t plat_scenario_load(uint8_t index)
{
    uint16_t year, offset = 0;

    /* zxn_bank_read's source is mapped at $C000, so its destination must stay
       below $C000.  Stage small blocks there, then copy with bank 0 restored:
       levelmap itself lives in the upper bank-0 RAM window. */
    while (offset < MAP_BYTES) {
        uint16_t n = (uint16_t)(MAP_BYTES - offset);
        if (n > MAP_CHUNK) n = MAP_CHUNK;
        scenario_read(record_at(index) + offset, mapbuf, n);
        memcpy(levelmap + offset, mapbuf, n);
        offset += n;
    }
    scenario_read(record_at(index) + META_AT, metadata, META_BYTES);
    year = (uint16_t)metadata[0] | ((uint16_t)metadata[1] << 8);
    return year;
}

/* Restore saved scenario power and congestion after sim_loaded() clears all
   minimaps. The first simulation tick rebuilds both from live conditions. */
void plat_scenario_restore_state(uint8_t index)
{
    uint16_t offset = 0;
    while (offset < POWER_BYTES) {
        uint16_t n = (uint16_t)(POWER_BYTES - offset);
        if (n > MAP_CHUNK) n = MAP_CHUNK;
        scenario_read(record_at(index) + POWER_AT + offset, mapbuf, n);
        memcpy(minimaps + MM_POWER_AT + offset, mapbuf, n);
        offset += n;
    }
    offset = 0;
    while (offset < TRAFFIC_BYTES) {
        uint16_t n = (uint16_t)(TRAFFIC_BYTES - offset);
        if (n > MAP_CHUNK) n = MAP_CHUNK;
        scenario_read(record_at(index) + TRAFFIC_AT + offset, mapbuf, n);
        memcpy(minimaps + MM_TRAFFIC_AT + offset, mapbuf, n);
        offset += n;
    }
}
