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
#include "textfmt.h"
#include "evaluation.h"

/* Not text.h, which would put a second copy of all its strings in the program. */
static const char *const city_classes[6] = { "VILLAGE", "TOWN", "CITY", "CAPITAL", "METROPOLIS", "MEGALOPOLIS" };
static const char *const levels[3] = { "EASY", "MEDIUM", "HARD" };

static const uint8_t class_from[5][3] = {           /* population where each class starts, 24 bit */
    { 0xD0, 0x07, 0x00 },   /* 2000 */
    { 0x10, 0x27, 0x00 },   /* 10000 */
    { 0x50, 0xC3, 0x00 },   /* 50000 */
    { 0xA0, 0x86, 0x01 },   /* 100000 */
    { 0x20, 0xA1, 0x07 },   /* 500000 */
};

static uint16_t rnd = 1;

static uint8_t clip(int16_t v)                      /* the Spectrum's ckpercent */
{
    return (uint8_t)(v < 0 ? 0 : v > 100 ? 100 : v);
}

void evaluate(struct evaluation *e)
{
    int16_t total, s;
    uint8_t i, yes;
    uint32_t pop = fmt_u24(V_population);

    e->traffic = clip(V_TrafficAverage >> 1);
    e->pollution = clip(V_PolluteAverage >> 1);
    e->crime = clip(V_concern_crime >> 2);
    e->fire = clip((int16_t)(V_LVAverage & 0xFF) * 5);
    e->taxes = clip(((int16_t)SMC_tax_rate - 3) * 4);
    e->house_prices = clip(V_concern_house_price);
    e->unemployment = clip((int16_t)V_unemployment);
    total = (int16_t)e->traffic + e->pollution + e->crime + e->fire + e->taxes + e->house_prices
            + e->unemployment + (int16_t)(V_unPwrdZCnt >> 2) + (V_alertmessage ? 4 : 0);
    s = (int16_t)((250 - 3 * total) * 4);
    e->score = (uint16_t)(s < 0 ? 0 : s > 1000 ? 1000 : s);

    e->city_class = 0;
    for (i = 0; i < 5 && pop >= fmt_u24(class_from[i]); ++i)
        e->city_class = (uint8_t)(i + 1);
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

/* "LABEL      nn%" with the label at column `at` and the number ending at `end`. */
static void percent(char *b, uint8_t at, const char *label, uint8_t end, uint8_t v)
{
    fmt_str(b, at, label);
    fmt_num(b, end, v);
    b[end] = '%';
}

static void draw(const struct evaluation *e)
{
    char b[41];
    uint8_t n;

    fmt_blank(b);
    fmt_str(b, 0, "MAYOR APPROVAL");
    percent(b, 17, "YES", 25, e->yes);
    percent(b, 28, "NO", 36, e->no);
    plat_text_puts(0, 0, b);

    fmt_blank(b);
    if (e->has_people) {
        percent(b, 0, "TRAFFIC", 15, e->traffic);
        percent(b, 18, "POLLUTION", 36, e->pollution);
        plat_text_puts(0, 1, b);
        fmt_blank(b);
        percent(b, 0, "CRIME", 15, e->crime);
        percent(b, 18, "FIRE", 36, e->fire);
        plat_text_puts(0, 2, b);
        fmt_blank(b);
        percent(b, 0, "TAXES", 15, e->taxes);
        percent(b, 18, "HOUSE PRICES", 36, e->house_prices);
        plat_text_puts(0, 3, b);
        fmt_blank(b);
        percent(b, 0, "UNEMPLOYMENT", 15, e->unemployment);
        fmt_str(b, 18, "CITY SCORE");
        fmt_num(b, 36, e->score);
        plat_text_puts(0, 4, b);
    } else {
        fmt_str(b, 0, "NOBODY LIVES HERE YET");
        plat_text_puts(0, 1, b);
        fmt_blank(b);
        plat_text_puts(0, 2, b);
        plat_text_puts(0, 3, b);
        plat_text_puts(0, 4, b);
    }

    fmt_blank(b);
    fmt_str(b, 0, "POPULATION");
    fmt_num(b, 17, (int32_t)fmt_u24(V_display_population));
    fmt_str(b, 20, "MIGRATION");
    fmt_num(b, 39, fmt_s24(V_population) - fmt_s24(V_prev_year_population));
    plat_text_puts(0, 5, b);

    fmt_blank(b);
    n = fmt_str(b, 0, "ASSESSED VALUE $");
    {
        char t[12];
        uint8_t k = 12;
        uint32_t v = fmt_u24(V_previous_city_score);
        t[--k] = '0'; t[--k] = '0'; t[--k] = '0';   /* the score is in thousands */
        do {
            t[--k] = (char)('0' + (uint8_t)(v % 10));
            v /= 10;
        } while (v && k);
        if (fmt_u24(V_previous_city_score) == 0)
            k = 11;                                 /* "$0" */
        while (k < 12)
            b[n++] = t[k++];
    }
    plat_text_puts(0, 6, b);

    fmt_blank(b);
    n = fmt_str(b, 0, city_classes[e->city_class]);
    fmt_str(b, (uint8_t)(n + 2), levels[V_difficulty > 2 ? 2 : V_difficulty]);
    fmt_str(b, 31, "ENTER OK");
    plat_text_puts(0, 7, b);
    plat_flush();
}

uint8_t evaluation_screen(void)
{
    struct evaluation e;
    uint8_t k;

    if (plat_text_rows() < 8 || plat_text_cols() < 40)
        return 0;
    evaluate(&e);
    plat_text_clear();
    draw(&e);
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
            draw(&e);
            break;
        case 0:
            plat_idle();
            break;
        }
    }
}
