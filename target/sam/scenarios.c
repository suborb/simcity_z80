/* SAM Coupe scenario picker and loader (the platform's side of HAVE_SCENARIOS: ui/platform.h).  tools/convert_amiga_scenarios.py --sam makes the data: a file on the disk for
   each scenario (the power map, the traffic map run length coded, the map: read by plat_scenario_read into the spare page, plat_sam_files.asm), and the picker's block (the
   previews and the texts), which is the 32 KB after the pictures' (plat_picker_read and plat_picker_preview, plat_sam.asm).  The picker is in the start-up overlay and
   the end message (scenario_msg.c: its own file, as a file's strings go in the one constant section it ends in) in the modal one (target/sam/plat_config.h); the loader is resident, as the title screen's overlay has gone by the time it is called. */
#include <stdint.h>
#include <string.h>
#include "engine.h"
#include "platform.h"

#define SCENARIO_COUNT 8
#define PREVIEW_BYTES 1500                      /* 60 x 50 pixels of 4 bits */
#define META_AT (SCENARIO_COUNT * PREVIEW_BYTES)
#define META_BYTES 1024
#define HEAD 64                                 /* a scenario's year, lengths, title, event... (tools/convert_amiga_scenarios.py make_meta) */
#define PAGE 256                                /* the text is shown 16 lines of 16 characters at a time */
#define MAP_BYTES (MAP_W * MAP_H)
#define POWER_BYTES (MM_POWER_ROW * MAP_H)
#define TRAFFIC_BYTES MM50_SIZE

extern void plat_picker_read(uint8_t *dst, uint16_t off, uint16_t len);
extern void plat_picker_preview(uint8_t index);
extern uint8_t plat_scenario_read(const char *name, uint8_t *map);
extern void plat_scenario_peek(uint8_t *dst, uint16_t off, uint16_t len);

static uint8_t metadata[HEAD + PAGE];           /* the scenario's header, and a page of its text */

static void read_head(uint8_t index)            /* (resident: the loader uses it too) */
{
    plat_picker_read(metadata, (uint16_t)(META_AT + (uint16_t)index * META_BYTES), HEAD);
}

PLAT_CODE_START_OVERLAY
static uint16_t text_len(void)
{
    return (uint16_t)metadata[4] | ((uint16_t)metadata[5] << 8);
}

static void text_field(uint8_t col, uint8_t row, uint8_t at, uint8_t len)
{
    char s[33];
    uint8_t n = len > 32 ? 32 : len;

    memcpy(s, metadata + at, n);
    s[n] = 0;
    plat_text_puts(col, row, s);
}

/* A page of the description: its 16 columns are written over, blanks to the end, so the other page need not be cleared away. */
static void show_text(uint8_t index, uint8_t page)
{
    uint8_t row;
    uint16_t len = text_len();
    uint16_t start = (uint16_t)page * PAGE;
    uint16_t n = start < len ? (uint16_t)(len - start) : 0;
    uint16_t at = 0;

    if (n > PAGE)
        n = PAGE;
    plat_picker_read(metadata + HEAD, (uint16_t)(META_AT + (uint16_t)index * META_BYTES + HEAD + start), n);
    for (row = 6; row < 22; ++row) {            /* (row 22 is left blank above the key guide) */
        char s[17];
        uint8_t m = 0;

        if (at < n) {
            m = (uint8_t)(n - at > 16 ? 16 : n - at);
            memcpy(s, metadata + HEAD + at, m);
            at += m;
        }
        memset(s + m, ' ', 16 - m);
        s[16] = 0;
        plat_text_puts(0, row, s);
    }
}

static void show_scenario(uint8_t index, uint8_t page)
{
    uint16_t year;
    char y[5];

    read_head(index);
    year = (uint16_t)metadata[0] | ((uint16_t)metadata[1] << 8);
    plat_text_clear();
    plat_text_puts(0, 0, "CHOOSE SCENARIO");
    text_field(0, 2, 8, metadata[2]);
    plat_text_puts(0, 3, "YEAR:");
    y[0] = (char)('0' + year / 1000 % 10);
    y[1] = (char)('0' + year / 100 % 10);
    y[2] = (char)('0' + year / 10 % 10);
    y[3] = (char)('0' + year % 10);
    y[4] = 0;
    plat_text_puts(6, 3, y);
    text_field(0, 4, 32, metadata[3]);
    show_text(index, page);
    plat_text_puts(0, 23, "ARROWS SELECT/PAGE ENTER");
    plat_picker_preview(index);
    plat_flush();
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
            uint8_t pages = (uint8_t)((text_len() + PAGE - 1) / PAGE);

            if (!pages) pages = 1;
            page = (uint8_t)((page + (k == KEY_DOWN ? 1 : pages - 1)) % pages);
            show_text(index, page);
            plat_flush();
        } else if (!k) {
            plat_idle();
        }
    }
}

PLAT_CODE_HOME
/* The scenario's map to levelmap, and its year.  The file stays in the spare page for plat_scenario_restore_state; if it is not on the disk (a copy of the game without
   them) the map is bare ground. */
uint16_t plat_scenario_load(uint8_t index)
{
    char name[6];

    name[0] = 's'; name[1] = 'c'; name[2] = 'e'; name[3] = 'n'; name[4] = (char)('0' + index); name[5] = 0;
    plat_page_data();
    if (plat_scenario_read(name, levelmap))
        memset(levelmap, 2, MAP_BYTES);
    read_head(index);
    return (uint16_t)metadata[0] | ((uint16_t)metadata[1] << 8);
}

/* Restore the scenario's power and congestion after sim_loaded() has cleared all the minimaps; the first simulation tick rebuilds both from live conditions. */
uint8_t plat_scenario_restore_state(uint8_t index)
{
    uint8_t buf[64];
    uint8_t *dst = minimaps + MM_TRAFFIC_AT;
    uint16_t len, pos = POWER_BYTES + 2, left = TRAFFIC_BYTES;

    (void)index;
    plat_page_data();
    plat_scenario_peek(minimaps + MM_POWER_AT, 0, POWER_BYTES);
    plat_scenario_peek((uint8_t *)&len, POWER_BYTES, 2);
    while (len >= 2) {                          /* the traffic map, as pairs of a count and a byte */
        uint8_t i, n = len > 64 ? 64 : (uint8_t)len;

        plat_scenario_peek(buf, pos, n);
        pos += n;
        len -= n;
        for (i = 0; i + 1 < n; i += 2) {
            uint8_t c = buf[i];

            if (c > left) c = (uint8_t)left;
            memset(dst, buf[i + 1], c);
            dst += c;
            left -= c;
        }
    }
    return metadata[6];                         /* (plat_scenario_load read it) */
}

uint16_t plat_scenario_rules(void)
{
    return (uint16_t)((uint16_t)metadata[7] << 8) | metadata[31];
}
