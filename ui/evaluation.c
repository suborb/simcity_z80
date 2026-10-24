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
#ifdef HAVE_EVALUATION
#define EVAL_ROW(n)  (((n) * (MODAL_ROWS - 1) + 3) / 7)
uint16_t eval_unpowered;

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
    if (a[2] != b[2])
        return a[2] > b[2];
    if (a[1] != b[1])
        return a[1] > b[1];
    return a[0] >= b[0];
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
    total = (int16_t)(eval_unpowered >> 2) + (V_alertmessage ? 4 : 0);
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

#ifdef MODAL_NARROW
/* The 32 column arrangement: the same sections, with the problems one to a row. */
static const struct field head[] = {
    { 0, 11, F_TEXT, 0,   "EVALUATION" },
    { 2,  1, F_TEXT, 0,   "IS THE MAYOR DOING A GOOD JOB?" },
    { 3, 14, F_U8,   '%', &ev.yes },
    { 3, 18, F_TEXT, 0,   "YES" },
    { 4, 14, F_U8,   '%', &ev.no },
    { 4, 18, F_TEXT, 0,   "NO" },
};

static const struct field body[] = {
    {  6,  1, F_TEXT, 0,   "WHAT ARE THE WORST PROBLEMS?" },
    {  8,  1, F_TEXT, 0,   "TRAFFIC" },
    {  8, 22, F_U8,   '%', ev.problem },
    {  9,  1, F_TEXT, 0,   "POLLUTION" },
    {  9, 22, F_U8,   '%', ev.problem + 1 },
    { 10,  1, F_TEXT, 0,   "CRIME" },
    { 10, 22, F_U8,   '%', ev.problem + 2 },
    { 11,  1, F_TEXT, 0,   "FIRE" },
    { 11, 22, F_U8,   '%', ev.problem + 3 },
    { 12,  1, F_TEXT, 0,   "TAXES" },
    { 12, 22, F_U8,   '%', ev.problem + 4 },
    { 13,  1, F_TEXT, 0,   "HOUSE PRICES" },
    { 13, 22, F_U8,   '%', ev.problem + 5 },
    { 14,  1, F_TEXT, 0,   "UNEMPLOYMENT" },
    { 14, 22, F_U8,   '%', ev.problem + 6 },
};

static const struct field nobody[] = {
    {  8,  1, F_TEXT, 0,   "NOBODY LIVES HERE YET" },
};

#ifdef HAVE_TEXT_COLOUR
#define NUM_COL    21                       /* the numbers end in one column, a gap after the labels; the values (the class and level) start in one */
#define VALUE_COL  12
#else
#define NUM_COL    20
#define CLASS_COL  11
#define VALUE_COL  12
#endif
static const struct field foot[] = {
    { 16,  1, F_TEXT, 0,   "POPULATION" },
    { 16, NUM_COL, F_U24,  0,   V_display_population },
    { 17,  1, F_TEXT, 0,   "MIGRATION" },
    { 17, NUM_COL, F_S24,  0,   migration },
    { 18,  1, F_TEXT, 0,   "ASSESSED VALUE $" },
#ifdef HAVE_TEXT_COLOUR
    { 18, 17, F_K24,  0,   V_previous_city_score },
#else
    { 18, 18, F_K24,  0,   V_previous_city_score },
#endif
    { 20,  1, F_TEXT, 0,   "CATEGORY" },
#ifdef HAVE_TEXT_COLOUR
    { 20, VALUE_COL, F_STR,  0,   &class_name },
#else
    { 20, CLASS_COL, F_STR,  0,   &class_name },
#endif
    { 21,  1, F_TEXT, 0,   "GAME LEVEL" },
    { 21, VALUE_COL, F_STR,  0,   &level_name },
    { 22,  1, F_TEXT, 0,   "CITY SCORE" },
    { 22, NUM_COL, F_U16,  0,   &ev.score },
    { 23, 24, F_TEXT, 0,   "ENTER OK" },
};
#elif MODAL_ROWS >= 24
/* The full-screen arrangement keeps the Spectrum's sections: the question and approval, then the problems,
   statistics and city category. */
static const struct field head[] = {
    { 0, 13, F_TEXT, 0,   "EVALUATION" },
    { 2,  1, F_TEXT, 0,   "IS THE MAYOR DOING A GOOD JOB?" },
    { 3, 14, F_U8,   '%', &ev.yes },
    { 3, 18, F_TEXT, 0,   "YES" },
    { 4, 14, F_U8,   '%', &ev.no },
    { 4, 18, F_TEXT, 0,   "NO" },
};

static const struct field body[] = {
    {  6,  1, F_TEXT, 0,   "WHAT ARE THE WORST PROBLEMS?" },
    {  8,  1, F_TEXT, 0,   "TRAFFIC" },
    {  8, 15, F_U8,   '%', ev.problem },
    {  8, 20, F_TEXT, 0,   "POLLUTION" },
    {  8, 39, F_U8,   '%', ev.problem + 1 },
    {  9,  1, F_TEXT, 0,   "CRIME" },
    {  9, 15, F_U8,   '%', ev.problem + 2 },
    {  9, 20, F_TEXT, 0,   "FIRE" },
    {  9, 39, F_U8,   '%', ev.problem + 3 },
    { 10,  1, F_TEXT, 0,   "TAXES" },
    { 10, 15, F_U8,   '%', ev.problem + 4 },
    { 10, 20, F_TEXT, 0,   "HOUSE PRICES" },
    { 10, 39, F_U8,   '%', ev.problem + 5 },
    { 11,  1, F_TEXT, 0,   "UNEMPLOYMENT" },
    { 11, 15, F_U8,   '%', ev.problem + 6 },
};

static const struct field nobody[] = {
    {  8,  1, F_TEXT, 0,   "NOBODY LIVES HERE YET" },
};

static const struct field foot[] = {
    { 14,  1, F_TEXT, 0,   "POPULATION" },
    { 14, 17, F_U24,  0,   V_display_population },
    { 15,  1, F_TEXT, 0,   "MIGRATION" },
    { 15, 17, F_S24,  0,   migration },
    { 16,  1, F_TEXT, 0,   "ASSESSED VALUE $" },
    { 16, 18, F_K24,  0,   V_previous_city_score },
    { 19,  1, F_TEXT, 0,   "CATEGORY" },
    { 19, 14, F_STR,  0,   &class_name },
    { 20,  1, F_TEXT, 0,   "GAME LEVEL" },
    { 20, 14, F_STR,  0,   &level_name },
    { 21,  1, F_TEXT, 0,   "CITY SCORE" },
    { 21, 17, F_U16,  0,   &ev.score },
    { 23, 31, F_TEXT, 0,   "ENTER OK" },
};
#elif defined(HAVE_TEXT_TITLE)
/* In seven rows: the approval, the problems (four rows), then the population and migration, and the value of the city with its
   category.  The figures end in the same columns (the percentages 16 and 39, the numbers 16 and 39 as well), the second column of
   labels starts at 20.  (The game level is left out.) */
static const struct field head[] = {
    { 0,  0, F_TEXT, 0,   "MAYOR APPROVAL" },
    { 0, 17, F_TEXT, 0,   "YES" },
    { 0, 25, F_U8,   '%', &ev.yes },
    { 0, 28, F_TEXT, 0,   "NO" },
    { 0, 35, F_U8,   '%', &ev.no },
};

static const struct field body[] = {
    { 1,  0, F_TEXT, 0,   "TRAFFIC" },
    { 1, 15, F_U8,   '%', ev.problem },
    { 1, 20, F_TEXT, 0,   "POLLUTION" },
    { 1, 38, F_U8,   '%', ev.problem + 1 },
    { 2,  0, F_TEXT, 0,   "CRIME" },
    { 2, 15, F_U8,   '%', ev.problem + 2 },
    { 2, 20, F_TEXT, 0,   "FIRE" },
    { 2, 38, F_U8,   '%', ev.problem + 3 },
    { 3,  0, F_TEXT, 0,   "TAXES" },
    { 3, 15, F_U8,   '%', ev.problem + 4 },
    { 3, 20, F_TEXT, 0,   "HOUSE PRICES" },
    { 3, 38, F_U8,   '%', ev.problem + 5 },
    { 4,  0, F_TEXT, 0,   "UNEMPLOYMENT" },
    { 4, 15, F_U8,   '%', ev.problem + 6 },
    { 4, 20, F_TEXT, 0,   "CITY SCORE" },
    { 4, 39, F_U16,  0,   &ev.score },
};

static const struct field nobody[] = {
    { 1,  0, F_TEXT, 0,   "NOBODY LIVES HERE YET" },
};

static const struct field foot[] = {
    { 5,  0, F_TEXT, 0,   "POPULATION" },
    { 5, 16, F_U24,  0,   V_display_population },
    { 5, 20, F_TEXT, 0,   "MIGRATION" },
    { 5, 39, F_S24,  0,   migration },
    { 6,  0, F_TEXT, 0,   "ASSESSED VALUE $" },
    { 6, 16, F_K24,  0,   V_previous_city_score },
    { 6, 28, F_STR,  0,   &class_name },
};
#else
static const struct field head[] = {
    { EVAL_ROW(0),  0, F_TEXT, 0,   "MAYOR APPROVAL" },
    { EVAL_ROW(0), 17, F_TEXT, 0,   "YES" },
    { EVAL_ROW(0), 25, F_U8,   '%', &ev.yes },
    { EVAL_ROW(0), 28, F_TEXT, 0,   "NO" },
    { EVAL_ROW(0), 36, F_U8,   '%', &ev.no },
};

static const struct field body[] = {
    { EVAL_ROW(1),  0, F_TEXT, 0,   "TRAFFIC" },
    { EVAL_ROW(1), 15, F_U8,   '%', ev.problem },
    { EVAL_ROW(1), 18, F_TEXT, 0,   "POLLUTION" },
    { EVAL_ROW(1), 36, F_U8,   '%', ev.problem + 1 },
    { EVAL_ROW(2),  0, F_TEXT, 0,   "CRIME" },
    { EVAL_ROW(2), 15, F_U8,   '%', ev.problem + 2 },
    { EVAL_ROW(2), 18, F_TEXT, 0,   "FIRE" },
    { EVAL_ROW(2), 36, F_U8,   '%', ev.problem + 3 },
    { EVAL_ROW(3),  0, F_TEXT, 0,   "TAXES" },
    { EVAL_ROW(3), 15, F_U8,   '%', ev.problem + 4 },
    { EVAL_ROW(3), 18, F_TEXT, 0,   "HOUSE PRICES" },
    { EVAL_ROW(3), 36, F_U8,   '%', ev.problem + 5 },
    { EVAL_ROW(4),  0, F_TEXT, 0,   "UNEMPLOYMENT" },
    { EVAL_ROW(4), 15, F_U8,   '%', ev.problem + 6 },
    { EVAL_ROW(4), 18, F_TEXT, 0,   "CITY SCORE" },
    { EVAL_ROW(4), 36, F_U16,  0,   &ev.score },
};

static const struct field nobody[] = {
    { EVAL_ROW(1),  0, F_TEXT, 0,   "NOBODY LIVES HERE YET" },
};

static const struct field foot[] = {
    { EVAL_ROW(5),  0, F_TEXT, 0,   "POPULATION" },
    { EVAL_ROW(5), 17, F_U24,  0,   V_display_population },
    { EVAL_ROW(5), 20, F_TEXT, 0,   "MIGRATION" },
    { EVAL_ROW(5), 39, F_S24,  0,   migration },
    { EVAL_ROW(6),  0, F_TEXT, 0,   "ASSESSED VALUE $" },
    { EVAL_ROW(6), 16, F_K24,  0,   V_previous_city_score },
    { EVAL_ROW(7),  0, F_STR,  0,   &class_name },
    { EVAL_ROW(7), 14, F_STR,  0,   &level_name },
    { EVAL_ROW(7), 31, F_TEXT, 0,   "ENTER OK" },
};
#endif

#define COUNT(a) (sizeof(a) / sizeof(struct field))

#if defined(HAVE_TEXT_COLOUR) && defined(MODAL_NARROW)
/* The 32 column evaluation in colour: a title band, the question and the headings in cyan, yellow labels, bars for the approval
   (green, red) and for each problem (green when it is small, yellow, red when it is large), and the key in cyan. */
#ifdef MODAL_X
#define MX(c) ((uint8_t)((c) + MODAL_X))
#else
#define MX(c) (c)
#endif
static void colour_row(uint8_t row)
{
    uint8_t v, c;

    switch (row) {
    case 0:
        plat_text_attr(MX(0), 0, 32, PLAT_ATTR(COL_WHITE, COL_BLUE));
        return;
    case 2:
        plat_text_attr(MX(1), 2, 30, PLAT_ATTR(COL_CYAN, COL_BLACK));
        return;
    case 3:
        if (ev.has_people) {
            plat_text_attr(MX(18), 3, 3, PLAT_ATTR(COL_GREEN, COL_BLACK));
            plat_bar(MX(22), 3, 10, (uint8_t)((uint16_t)ev.yes * 4 / 5), PLAT_ATTR(COL_GREEN, COL_BLACK));
        }
        return;
    case 4:
        if (ev.has_people) {
            plat_text_attr(MX(18), 4, 2, PLAT_ATTR(COL_RED, COL_BLACK));
            plat_bar(MX(22), 4, 10, (uint8_t)((uint16_t)ev.no * 4 / 5), PLAT_ATTR(COL_RED, COL_BLACK));
        }
        return;
    case 6:
        if (ev.has_people)
            plat_text_attr(MX(1), 6, 27, PLAT_ATTR(COL_CYAN, COL_BLACK));
        return;
    case 16:                                                    /* the labels only: the figures are white */
        plat_text_attr(MX(1), 16, 10, PLAT_ATTR(COL_YELLOW, COL_BLACK));
        return;
    case 17:
        plat_text_attr(MX(1), 17, 9, PLAT_ATTR(COL_YELLOW, COL_BLACK));
        return;
    case 18:
        plat_text_attr(MX(1), 18, 15, PLAT_ATTR(COL_YELLOW, COL_BLACK));
        return;
    case 20:
        plat_text_attr(MX(1), 20, 8, PLAT_ATTR(COL_YELLOW, COL_BLACK));
        return;
    case 21:
    case 22:
        plat_text_attr(MX(1), row, 10, PLAT_ATTR(COL_YELLOW, COL_BLACK));
        return;
    case 23:
        plat_text_attr(MX(24), 23, 8, PLAT_ATTR(COL_CYAN, COL_BLACK));
        return;
    }
    if (row >= 8 && row <= 14 && ev.has_people) {               /* a problem: its label and its bar (green when small, red when large) */
        v = ev.problem[row - 8];
        c = v < 25 ? COL_GREEN : v < 50 ? COL_YELLOW : COL_RED;
        plat_text_attr(MX(1), row, 12, PLAT_ATTR(COL_YELLOW, COL_BLACK));
        plat_bar(MX(24), row, 8, (uint8_t)((uint16_t)v * 16 / 25), PLAT_ATTR(c, COL_BLACK));
    }
}
#endif

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
#ifdef MODAL_X
    fmt_col0 = MODAL_X;                             /* (the screen is centred) */
#endif
#if defined(HAVE_TEXT_COLOUR) && defined(MODAL_NARROW)
    fmt_fields_each(head, COUNT(head), colour_row);
    if (ev.has_people)
        fmt_fields_each(body, COUNT(body), colour_row);
    else
        fmt_fields_each(nobody, COUNT(nobody), colour_row);
    fmt_fields_each(foot, COUNT(foot), colour_row);
#else
    fmt_fields(head, COUNT(head));
    if (ev.has_people)
        fmt_fields(body, COUNT(body));
    else
        fmt_fields(nobody, COUNT(nobody));
    fmt_fields(foot, COUNT(foot));
#endif
#ifdef MODAL_X
    fmt_col0 = 0;
#endif
    plat_flush();
}


uint8_t evaluation_screen(void)
{
    uint8_t k;

    if (plat_text_rows() < MODAL_ROWS || plat_text_cols() < MODAL_COLS)
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

#endif
