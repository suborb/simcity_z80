/* City files on the disc, for the file dialogues (ui/cityfile.c): six slots of 37 sectors (the header sector: the city's header, its first 12 bytes being the name, and the 36 of the
   96x96 map) from the first track after the program and the overlays (pc6001mk2_data_track()) on, the sectors running on over the tracks (16 a track).  A slot whose first byte is 0 is empty.  This is in the FILE overlay with the dialogues (file_ui.c), which game.c loads before it calls city_save or city_load. */
#include <stdint.h>
#include <string.h>
#include "platform.h"
_Pragma("codeseg OVERLAY_2")
_Pragma("constseg OVERLAY_2")

#ifdef HAVE_FILES
extern uint8_t pc6001mk2_disk_read(uint8_t track, uint8_t sector, uint8_t count, uint8_t *dest);
extern uint8_t pc6001mk2_disk_write(uint8_t track, uint8_t sector, uint8_t count, const uint8_t *src);
extern int pc6001mk2_data_track(void);          /* the first track after the program and the overlays (z88dk) */

#define SLOT_SECTORS 37
#define SLOTS 6
#define NAME_LEN 12                             /* the first 12 bytes of the header (cityfile.c) */
#define MAP_SECTORS 36

static uint8_t sec[256];

/* `count` sectors from sector `first` of the slot (0 the header), between buf and the disc: 0 if it worked */
static uint8_t xfer(uint8_t write, uint8_t slot, uint8_t first, uint8_t count, uint8_t *buf)
{
    uint16_t n = (uint16_t)slot * SLOT_SECTORS + first;
    uint8_t c, base = (uint8_t)pc6001mk2_data_track();

    while (count) {
        c = (uint8_t)(16 - (n & 15));
        if (c > count)
            c = count;
        if (write ? pc6001mk2_disk_write((uint8_t)(base + (n >> 4)), (uint8_t)(1 + (n & 15)), c, buf)
                  : pc6001mk2_disk_read((uint8_t)(base + (n >> 4)), (uint8_t)(1 + (n & 15)), c, buf))
            return 1;
        n += c;
        count -= c;
        buf += (uint16_t)c << 8;
    }
    return 0;
}

/* the slot's header sector is in `sec` (0 if it could not be read or is empty) */
static uint8_t head(uint8_t slot)
{
    return !xfer(0, slot, 0, 1, sec) && sec[0];
}

static uint8_t same(const char *name)
{
    uint8_t i;

    for (i = 0; i < NAME_LEN; ++i) {
        if (!name[i]) {
            for (; i < NAME_LEN; ++i)
                if (sec[i] != ' ')
                    return 0;
            return 1;
        }
        if (sec[i] != (uint8_t)name[i])
            return 0;
    }
    return 1;
}

#ifdef HAVE_FILE_LIST
uint8_t plat_file_list(char *names)
{
    uint8_t s, n = 0, i;
    char *e;

    for (s = 0; s < SLOTS; ++s) {
        if (!head(s))
            continue;
        e = names + (uint16_t)n * FILE_LIST_ENTRY;
        memcpy(e, sec, NAME_LEN);
        i = NAME_LEN;
        while (i && e[i - 1] == ' ')
            --i;
        e[i] = 0;
        ++n;
    }
    return n;
}
#endif

uint8_t plat_file_save(const char *name, const uint8_t *a, uint16_t alen, const uint8_t *b, uint16_t blen)
{
    uint8_t s, slot = SLOTS;

    for (s = 0; s < SLOTS; ++s)
        if (head(s) && same(name)) {
            slot = s;
            break;
        }
    if (slot == SLOTS)
        for (s = 0; s < SLOTS; ++s)
            if (!head(s)) {
                slot = s;
                break;
            }
    if (slot == SLOTS || blen != MAP_SECTORS * 256)
        return 1;
    if (xfer(1, slot, 1, MAP_SECTORS, (uint8_t *)b))    /* (the map first: a slot is not whole until its header is there) */
        return 1;
    memset(sec, 0, 256);
    memcpy(sec, a, alen);
    return xfer(1, slot, 0, 1, sec);
}

uint8_t plat_file_load(const char *name, uint8_t *a, uint16_t alen, uint8_t *b, uint16_t blen)
{
    uint8_t s;

    for (s = 0; s < SLOTS; ++s)
        if (head(s) && same(name)) {
            memcpy(a, sec, alen);
            return xfer(0, s, 1, MAP_SECTORS, b) ? 2 : 0;
        }
    return 1;
}
#endif
