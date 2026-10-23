/* NEC PC-8801 platform: the drawing, the screen set-up and the keyboard are in plat_pc88.asm; this has the tool icons, the
   frame counter and the files. */
#include <stdint.h>
#include <string.h>
#include "platform.h"
#ifdef HAVE_FILES
#include <arch/pc88.h>
#endif

static uint16_t clock_count;

extern const uint8_t mp_icons[];

/* a 1 bit picture in the colours of an attribute */
extern void mp_tile1(uint8_t col, uint8_t row, const uint8_t *art, uint8_t attr, uint8_t inverse);

/* The tool icons: 16x16 pictures, four cells each. */
#define NUM_ICONS 14

void plat_icons(uint8_t selected)
{
    uint8_t i, r, c, cell;

    for (i = 0; i < NUM_ICONS; ++i)
        for (r = 0; r < 2; ++r)
            for (c = 0; c < 2; ++c) {
                cell = (uint8_t)(i * 4 + r * 2 + c);
                mp_tile1((uint8_t)(i * 2 + c), (uint8_t)(1 + r), mp_icons + cell * 8,
                         mp_icons[NUM_ICONS * 32 + cell], i == selected);
            }
}

uint16_t plat_clock(void) { return clock_count; }
void plat_idle(void) { ++clock_count; }
void plat_flush(void) {}

#ifdef HAVE_FILES
/* A city is saved to a slot of the disk: SLOTS slots of SLOT_TRACKS tracks from SLOT_TRACK0 (the program is below).  A slot's first
   sector has the header block, zero padded, with a mark in its last two bytes; the map's sectors follow.  The first 12 bytes
   of the header are the file name, so a name finds its slot, and a save takes the slot with the same name or the first
   unmarked one.  The map goes first and the header last, so a slot is only marked once it is complete. */
#define SLOT_TRACK0 16
#define SLOT_TRACKS 3
#define SLOTS 8
#define KEY 12

static uint8_t sector[256];

/* the name as the game writes it into the header: 12 characters, blank after the first space */
static void make_key(const char *name, uint8_t *key)
{
    uint8_t r;

    for (r = 0; r < KEY; ++r)
        key[r] = name[r] && (r == 0 || key[r - 1] != ' ') ? (uint8_t)name[r] : ' ';
}

static uint8_t slot_track(uint8_t s)
{
    return (uint8_t)(SLOT_TRACK0 + s * SLOT_TRACKS);
}

/* the slot that has this name (255 if none), and the first one without a mark in *spare (255 if none) */
static uint8_t find_slot(const uint8_t *key, uint8_t *spare)
{
    uint8_t s, found = 255;

    *spare = 255;
    for (s = 0; s < SLOTS; ++s) {
        if (pc88_disk_read(0, slot_track(s), 1, 1, sector))
            continue;
        if (sector[254] == 'S' && sector[255] == 'C') {
            if (found == 255 && !memcmp(sector, key, KEY))
                found = s;
        } else if (*spare == 255)
            *spare = s;
    }
    return found;
}

/* the sector after the map's whole sectors: the track and sector it is on */
static void tail_at(uint8_t t0, uint8_t whole, uint8_t *track, uint8_t *sec)
{
    uint8_t k = (uint8_t)(1 + whole);

    *track = (uint8_t)(t0 + k / 16);
    *sec = (uint8_t)(1 + k % 16);
}

uint8_t plat_file_save(const char *name, const uint8_t *a, uint16_t alen, const uint8_t *b, uint16_t blen)
{
    uint8_t key[KEY], spare, s, t0, whole = (uint8_t)(blen >> 8), track, sec;

    if (alen > 252 || whole > SLOT_TRACKS * 16 - 3)
        return 1;
    make_key(name, key);
    s = find_slot(key, &spare);
    if (s == 255)
        s = spare;
    if (s == 255)
        return 1;                                           /* the disk is full of other names */
    t0 = slot_track(s);
    if (whole && pc88_disk_write(0, t0, 2, whole, b))
        return 1;
    if (blen & 255) {
        memset(sector, 0, 256);
        memcpy(sector, b + (blen & ~255u), blen & 255);
        tail_at(t0, whole, &track, &sec);
        if (pc88_disk_write(0, track, sec, 1, sector))
            return 1;
    }
    memset(sector, 0, 256);
    memcpy(sector, a, alen);
    sector[254] = 'S';
    sector[255] = 'C';
    return (uint8_t)pc88_disk_write(0, t0, 1, 1, sector);
}

uint8_t plat_file_load(const char *name, uint8_t *a, uint16_t alen, uint8_t *b, uint16_t blen)
{
    uint8_t key[KEY], spare, s, t0, whole = (uint8_t)(blen >> 8), track, sec;

    make_key(name, key);
    s = find_slot(key, &spare);
    if (s == 255 || alen > 252)
        return 1;
    t0 = slot_track(s);
    if (pc88_disk_read(0, t0, 1, 1, sector))
        return 1;
    memcpy(a, sector, alen);
    if (whole && pc88_disk_read(0, t0, 2, whole, b))
        return 2;
    if (blen & 255) {
        tail_at(t0, whole, &track, &sec);
        if (pc88_disk_read(0, track, sec, 1, sector))
            return 2;
        memcpy(b + (blen & ~255u), sector, blen & 255);
    }
    return 0;
}

static uint8_t wait_key(void)
{
    uint8_t k;

    while (!(k = plat_key()))
        plat_idle();
    return k;
}

/* A tiny editor for file names. */
uint8_t plat_text_input(uint8_t col, uint8_t row, char *buf, uint8_t max, uint8_t spaces)
{
    uint8_t n = 0, k;

    buf[0] = 0;
    for (;;) {
        k = wait_key();
        if (k == KEY_ENTER)
            return n != 0;
        if (k == KEY_ESC)
            return 0;
        if ((k == KEY_LEFT || k == 127) && n) {
            --n;
            plat_put((uint8_t)(col + n), row, ' ');
        } else if (k >= (spaces ? ' ' : '!') && k < 127 && n < max) {
            buf[n] = (char)k;
            plat_put((uint8_t)(col + n), row, k);
            ++n;
        }
        buf[n] = 0;
    }
}
#endif
