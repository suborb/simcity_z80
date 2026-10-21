/* Aquarius+ platform: 320x200 bitmap tiles and the z88dk generic console for text. */
#include <stdint.h>
#include <conio.h>
#include <input.h>
#include <sys/ioctl.h>
#ifdef HAVE_FILES
#include <fcntl.h>
#endif
#include "engine.h"
#include "platform.h"

static uint16_t aq_mode;
static uint16_t clock_count;
static uint8_t key_held;

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

void plat_clear(void) { clrscr(); }
void plat_put(uint8_t col, uint8_t row, uint8_t ch) { plat_aq_printc(col, row, ch); }

void plat_puts(uint8_t col, uint8_t row, const char *s)
{
    for (; *s && col < 40; ++col)       /* not past the right edge: it would wrap */
        plat_aq_printc(col, row, (uint8_t)*s++);
}

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

#ifdef HAVE_MINIMAP_COLOUR
void plat_put_minimap(uint8_t col, uint8_t row, const uint8_t *art,
                      uint8_t view, uint8_t level)
{
    uint8_t attr = 7;                         /* stable white city silhouette */

    /* The original minimap uses an eight-step intensity ramp with equal ink
       and paper: 0x49, 0x52, ..., 0x7f.  Density and coverage levels are 0..16
       and 0..15 respectively, so halve them to get the 0..7 ramp index. */
    if (view != 1) {
        level >>= 1;
        if (level > 7)
            level = 7;
        if (level)
            attr = (uint8_t)((level * 9) | 0x40);
    }
    aq_blit8(col, row, art, aq_attr_byte(attr), 0);
}
#endif

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

/* in_Inkey() reports the matrix state every poll.  The game and especially its pop-up
   menus run much faster than a human key press, so turn that level into one event until
   the key is released. */
uint8_t plat_key(void)
{
    uint8_t k = (uint8_t)in_Inkey();

    if (!k) {
        key_held = 0;
        return 0;
    }
    if (key_held == k)
        return 0;
    key_held = k;
    return k;
}

#ifdef HAVE_FILES
/* A tiny editor for file names.  This deliberately uses the game console rather
   than fgets_cons: the latter brings in a complete generic console editor, while
   this target already has keyboard polling and a character writer. */
uint8_t plat_text_input(uint8_t col, uint8_t row, char *buf, uint8_t max, uint8_t spaces)
{
    uint8_t n = 0, k;

    buf[0] = 0;
    for (;;) {
        k = plat_key();
        if (!k) {
            plat_idle();
            continue;
        }
        if (k == KEY_ENTER)
            return n != 0;
        if (k == KEY_ESC)
            return 0;
        if ((k == KEY_LEFT || k == 127) && n) {
            --n;
            plat_aq_printc((uint8_t)(col + n), row, ' ');
        } else if (k >= (spaces ? ' ' : '!') && k < 127 && n < max) {
            buf[n] = (char)k;
            plat_aq_printc((uint8_t)(col + n), row, k);
            ++n;
            buf[n] = 0;
        }
    }
}

uint8_t plat_file_save(const char *name, const uint8_t *a, uint16_t alen, const uint8_t *b, uint16_t blen)
{
    int fd = open(name, O_WRONLY | O_CREAT | O_TRUNC, 0);
    uint8_t bad;

    if ((uint8_t)fd >= 0xF0)             /* Aquarius+ ESP error codes are $F7..$FF */
        return 1;
    bad = write(fd, (void *)a, alen) != (ssize_t)alen ||
          write(fd, (void *)b, blen) != (ssize_t)blen;
    close(fd);
    return bad;
}

uint8_t plat_file_load(const char *name, uint8_t *a, uint16_t alen, uint8_t *b, uint16_t blen)
{
    int fd = open(name, O_RDONLY, 0);
    uint8_t r = 1;

    if ((uint8_t)fd >= 0xF0)
        return 1;
    if (read(fd, a, alen) == (ssize_t)alen)
        r = read(fd, b, blen) == (ssize_t)blen ? 0 : 2;
    close(fd);
    return r;
}
#endif

uint16_t plat_clock(void) { return clock_count; }
void plat_idle(void) { ++clock_count; }
void plat_flush(void) {}
