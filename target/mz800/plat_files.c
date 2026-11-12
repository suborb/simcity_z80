/* City files on the disc (ui/cityfile.c): six slots of 37 sectors (the city header, whose first 12 bytes are the name, and the 36 sectors of the 96x96 map) after the program
   (the Makefile checks it ends before SLOT_BASE; sector numbers are the IPL's: 16 a track, both sides, see mz800_disk_rw).
   Sector SLOT_BASE is the directory: six 12 byte names and a mark, so listing the cities is one read.  A name starting with a non-name byte is an empty slot (a new disc reads $E5).
   A slot is 5 tracks from SLOT_BASE + 16 using every other sector (IDs 1, 3 ... 15): consecutive single-sector commands would miss the next sector and cost a turn (200 ms) each. */
#include <stdint.h>
#include <string.h>
#include "platform.h"

#ifdef HAVE_FILES
extern int mz800_disk_rw(uint8_t write, uint8_t drive, uint16_t sector, uint8_t *buf) __smallc;
extern void mz800_disk_off(void);

#define SLOT_BASE 256                           /* the directory: MZ800_SLOT_BASE in the Makefile */
#define SLOT_SECTORS 37
#define SLOTS 6
#define SLOT_STRIDE 80                          /* 5 tracks of 16 sectors a slot */
#define NAME_LEN 12                             /* the first 12 bytes of the header (cityfile.c) */
#define MAP_SECTORS 36
#define DIR_MARK 244                            /* "SCD1" at this offset of the directory */

static uint8_t sec[256];                        /* a slot's header sector */
static uint8_t dir[256];

/* the logical sector of sector j (0 the header) of a slot: eight to a track, at every other ID */
static uint16_t where(uint8_t slot, uint8_t j)
{
    return (uint16_t)(SLOT_BASE + 16 + (uint16_t)slot * SLOT_STRIDE + (uint16_t)(j >> 3) * 16 + (uint16_t)(j & 7) * 2);
}

/* `count` sectors from sector `first` of the slot (0 the header), between buf and the disc: 0 if it worked */
static uint8_t xfer(uint8_t write, uint8_t slot, uint8_t first, uint8_t count, uint8_t *buf)
{
    uint8_t r = 0;

    while (count && !r) {
        r = (uint8_t)mz800_disk_rw(write, 0, where(slot, first), buf);
        ++first;
        --count;
        buf += 256;
    }
    return r;
}

static uint8_t used(uint8_t slot)
{
    uint8_t c = dir[(uint16_t)slot * NAME_LEN];

    return c > ' ' && c < 0x7f;
}

/* the directory is in `dir` (empty if it could not be read or has no mark); 0 if the disc could be read */
static uint8_t dir_read(void)
{
    uint8_t r = (uint8_t)mz800_disk_rw(0, 0, SLOT_BASE, dir);

    if (r || memcmp(dir + DIR_MARK, "SCD1", 4)) {
        memset(dir, 0, 256);
        memcpy(dir + DIR_MARK, "SCD1", 4);
    }
    return r;
}

static uint8_t find(const char *name)
{
    uint8_t s, i;

    for (s = 0; s < SLOTS; ++s) {
        if (!used(s))
            continue;
        for (i = 0; i < NAME_LEN; ++i) {
            if (!name[i]) {
                for (; i < NAME_LEN; ++i)
                    if (dir[(uint16_t)s * NAME_LEN + i] != ' ')
                        break;
                break;
            }
            if (dir[(uint16_t)s * NAME_LEN + i] != (uint8_t)name[i])
                break;
        }
        if (i == NAME_LEN)
            return s;
    }
    return SLOTS;
}

#ifdef HAVE_FILE_LIST
static uint8_t file_list(char *names)
{
    uint8_t s, n = 0, i;
    char *e;

    if (dir_read())
        return FILE_LIST_NONE;
    for (s = 0; s < SLOTS; ++s) {
        if (!used(s))
            continue;
        e = names + (uint16_t)n * FILE_LIST_ENTRY;
        memcpy(e, dir + (uint16_t)s * NAME_LEN, NAME_LEN);
        i = NAME_LEN;
        while (i && e[i - 1] == ' ')
            --i;
        e[i] = 0;
        ++n;
    }
    return n;
}
#endif

static uint8_t file_save(const char *name, const uint8_t *a, uint16_t alen, const uint8_t *b, uint16_t blen)
{
    uint8_t s, slot;

    if (dir_read() || blen != MAP_SECTORS * 256)
        return 1;
    slot = find(name);
    if (slot == SLOTS)
        for (s = 0; s < SLOTS; ++s)
            if (!used(s)) {
                slot = s;
                break;
            }
    if (slot == SLOTS)
        return 1;
    if (xfer(1, slot, 1, MAP_SECTORS, (uint8_t *)b))    /* (the map first: a slot is not whole until its header and its entry are there) */
        return 1;
    memset(sec, 0, 256);
    memcpy(sec, a, alen);
    if (xfer(1, slot, 0, 1, sec))
        return 1;
    memset(dir + (uint16_t)slot * NAME_LEN, ' ', NAME_LEN);
    for (s = 0; s < NAME_LEN && name[s]; ++s)
        dir[(uint16_t)slot * NAME_LEN + s] = (uint8_t)name[s];
    return (uint8_t)mz800_disk_rw(1, 0, SLOT_BASE, dir);
}

static uint8_t file_load(const char *name, uint8_t *a, uint16_t alen, uint8_t *b, uint16_t blen)
{
    uint8_t slot;

    if (dir_read())
        return 1;
    slot = find(name);
    if (slot == SLOTS || xfer(0, slot, 0, 1, sec))
        return 1;
    memcpy(a, sec, alen);
    return xfer(0, slot, 1, MAP_SECTORS, b) ? 2 : 0;
}

/* the motor is left running between the sectors of one operation (the drive takes about half a second to come up to speed) and stopped at its end */
#ifdef HAVE_FILE_LIST
uint8_t plat_file_list(char *names)
{
    uint8_t n = file_list(names);

    mz800_disk_off();
    return n;
}
#endif

uint8_t plat_file_save(const char *name, const uint8_t *a, uint16_t alen, const uint8_t *b, uint16_t blen)
{
    uint8_t r = file_save(name, a, alen, b, blen);

    mz800_disk_off();
    return r;
}

uint8_t plat_file_load(const char *name, uint8_t *a, uint16_t alen, uint8_t *b, uint16_t blen)
{
    uint8_t r = file_load(name, a, alen, b, blen);

    mz800_disk_off();
    return r;
}
#endif
