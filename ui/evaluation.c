/* The evaluation screen.  See evaluation.h.  The numbers are the Spectrum's (print_evaluation_concerns,
   print_city_score, print_mayor_rating): seven problems, each a percentage; their sum, with a quarter
   of the unpowered zones and 4 if there is an alert showing, gives the score; and the approval is
   100 people each voting "yes" if a random number from 0 to 1023 is below the score.

      MAYOR APPROVAL   YES  79%   NO  21%
      TRAFFIC         12%  POLLUTION      3%
      CRIME            5%  FIRE           0%
      TAXES           16%  HOUSE PRICES   4%
      UNEMPLOYMENT     8%  CITY SCORE   808
      POPULATION   12345   MIGRATION   -120
      ASSESSED VALUE $4000000
      VILLAGE  EASY                ENTER OK */
#include <stdint.h>
#include "engine.h"
#include "platform.h"
#include "text.h"
#include "textfmt.h"
#include "evaluation.h"

static const uint8_t class_from[5][3] = {           /* population where each class starts, 24 bit */
    { 0xD0, 0x07, 0x00 },   /* 2000 */
    { 0x10, 0x27, 0x00 },   /* 10000 */
    { 0x50, 0xC3, 0x00 },   /* 50000 */
    { 0xA0, 0x86, 0x01 },   /* 100000 */
    { 0x20, 0xA1, 0x07 },   /* 500000 */
};

static uint16_t rnd = 1;

static uint8_t ge24(const uint8_t *a, const uint8_t *b)     /* a >= b, 24 bit */
{
    uint8_t i = 3;
    while (i--)
        if (a[i] != b[i])
            return a[i] > b[i];
    return 1;
}

static uint8_t clip(int16_t v)                      /* the Spectrum's ckpercent */
{
    return (uint8_t)(v < 0 ? 0 : v > 100 ? 100 : v);
}

void evaluate(struct evaluation *e)
{
    int16_t raw[7], total;
    uint8_t i, yes;

    raw[0] = V_TrafficAverage >> 1;
    raw[1] = V_PolluteAverage >> 1;
    raw[2] = V_concern_crime >> 2;
    raw[3] = (int16_t)(V_LVAverage & 0xFF) * 5;
    raw[4] = ((int16_t)SMC_tax_rate - 3) * 4;
    raw[5] = V_concern_house_price;
    raw[6] = (int16_t)V_unemployment;
    total = (int16_t)(V_unPwrdZCnt >> 2) + (V_alertmessage ? 4 : 0);
    for (i = 0; i < 7; ++i) {
        e->problem[i] = clip(raw[i]);
        total += e->problem[i];
    }
    total = (250 - 3 * total) * 4;
    e->score = (uint16_t)(total < 0 ? 0 : total > 1000 ? 1000 : total);

    e->city_class = 0;
    for (i = 0; i < 5; ++i)
        e->city_class += ge24(V_population, class_from[i]);
    e->has_people = (V_display_population[0] | V_display_population[1] | V_display_population[2]) != 0;

    rnd ^= (uint16_t)(plat_clock() ^ ((uint16_t)V_view_tick << 8) ^ 0x9E37);
    if (!rnd)
        rnd = 1;
    yes = 0;
    for (i = 0; i < 100; ++i) {                     /* a vote each */
        rnd ^= (uint16_t)(rnd << 7);
        rnd ^= (uint16_t)(rnd >> 9);
        rnd ^= (uint16_t)(rnd << 8);
        if ((rnd & 1023) < e->score)
            ++yes;
    }
    if (!e->has_people)
        yes = 0;
    e->yes = yes;
    e->no = (uint8_t)(e->has_people ? 100 - yes : 0);
}

static struct evaluation ev;
static uint8_t migration[3];
static const char *class_name, *level_name;

static const struct field head[] = {
    { 0,  0, F_TEXT, 0,   "MAYOR APPROVAL" },
    { 0, 17, F_TEXT, 0,   "YES" },
    { 0, 25, F_U8,   '%', &ev.yes },
    { 0, 28, F_TEXT, 0,   "NO" },
    { 0, 36, F_U8,   '%', &ev.no },
};

static const struct field body[] = {
    { 1,  0, F_TEXT, 0,   "TRAFFIC" },
    { 1, 15, F_U8,   '%', ev.problem },
    { 1, 18, F_TEXT, 0,   "POLLUTION" },
    { 1, 36, F_U8,   '%', ev.problem + 1 },
    { 2,  0, F_TEXT, 0,   "CRIME" },
    { 2, 15, F_U8,   '%', ev.problem + 2 },
    { 2, 18, F_TEXT, 0,   "FIRE" },
    { 2, 36, F_U8,   '%', ev.problem + 3 },
    { 3,  0, F_TEXT, 0,   "TAXES" },
    { 3, 15, F_U8,   '%', ev.problem + 4 },
    { 3, 18, F_TEXT, 0,   "HOUSE PRICES" },
    { 3, 36, F_U8,   '%', ev.problem + 5 },
    { 4,  0, F_TEXT, 0,   "UNEMPLOYMENT" },
    { 4, 15, F_U8,   '%', ev.problem + 6 },
    { 4, 18, F_TEXT, 0,   "CITY SCORE" },
    { 4, 36, F_U16,  0,   &ev.score },
};

static const struct field nobody[] = {
    { 1,  0, F_TEXT, 0,   "NOBODY LIVES HERE YET" },
};

static const struct field foot[] = {
    { 5,  0, F_TEXT, 0,   "POPULATION" },
    { 5, 17, F_U24,  0,   V_display_population },
    { 5, 20, F_TEXT, 0,   "MIGRATION" },
    { 5, 39, F_S24,  0,   migration },
    { 6,  0, F_TEXT, 0,   "ASSESSED VALUE $" },
    { 6, 16, F_K24,  0,   V_previous_city_score },
    { 7,  0, F_STR,  0,   &class_name },
    { 7, 14, F_STR,  0,   &level_name },
    { 7, 31, F_TEXT, 0,   "ENTER OK" },
};

#define COUNT(a) (sizeof(a) / sizeof(struct field))

static void draw(void)
{
    uint8_t i, borrow = 0;
    int16_t d;

    for (i = 0; i < 3; ++i) {                       /* this year's population less last year's */
        d = (int16_t)V_population[i] - V_prev_year_population[i] - borrow;
        migration[i] = (uint8_t)d;
        borrow = d < 0;
    }
    class_name = text_city_class[ev.city_class];
    level_name = text_levels[V_difficulty > 2 ? 2 : V_difficulty];
    fmt_fields(head, COUNT(head));
    if (ev.has_people)
        fmt_fields(body, COUNT(body));
    else
        fmt_fields(nobody, COUNT(nobody));
    fmt_fields(foot, COUNT(foot));
    plat_flush();
}

uint8_t evaluation_screen(void)
{
    uint8_t k;

    if (plat_text_rows() < 8 || plat_text_cols() < 40)
        return 0;
    evaluate(&ev);
    plat_text_clear();
    draw();
    for (;;) {
        k = plat_key();
        switch (k) {
        case KEY_ENTER: case ' ': case KEY_ESC:
            plat_text_clear();
            return 0;
        case CMD_QUIT:
            return 1;
        case CMD_REDRAW:
            plat_text_clear();
            draw();
            break;
        case 0:
            plat_idle();
            break;
        }
    }
}
