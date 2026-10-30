/* MZ-2500 save and load: raw slots in the last ten cylinders of the boot disk (cylinders 30-39, which the build leaves unused), through z88dk's mz2500_disk_rw (the floppy
   controller driven directly).  Sector 0 of the area is the directory: 8 entries of 16 bytes (a 12 character name, its NUL, the stored length) and the magic "SC" in its last two
   bytes (a disk that has never been saved to has none); each slot after it is 37 sectors (a city is a 31 byte header and the 9,216 byte map). */
#include <stdint.h>
#include <string.h>
#include <arch/mz2500.h>

#define AREA_TRACK 60                   /* the first logical track of the area: cylinder 30, side 0 (a track is 16 sectors, the sides alternate as appmake writes them) */
#define SLOT_SECS  37
#define SLOTS      8
#define ENTRY      16
#define NAME_LEN   12

static uint8_t secbuf[256];

static uint8_t sector_io(uint8_t write, uint16_t n)
{
    uint8_t lt = (uint8_t)(AREA_TRACK + (n >> 4));

    return mz2500_disk_rw(write, 0, (uint8_t)(lt >> 1), (uint8_t)(lt & 1), (uint8_t)((n & 15) + 1), secbuf) != 0;
}

/* the directory into secbuf: 0 if it is there and valid, else it is made empty (and 1 is returned) */
static uint8_t read_dir(void)
{
    if (sector_io(0, 0) || secbuf[254] != 'S' || secbuf[255] != 'C') {
        memset(secbuf, 0, 256);
        secbuf[254] = 'S';
        secbuf[255] = 'C';
        return 1;
    }
    return 0;
}

static uint8_t find(const char *name)           /* the slot called name, 255 if none */
{
    uint8_t i;

    for (i = 0; i < SLOTS; ++i)
        if (secbuf[i * ENTRY] && strncmp((const char *)secbuf + i * ENTRY, name, NAME_LEN) == 0)
            return i;
    return 255;
}

uint8_t plat_file_save(const char *name, const uint8_t *a, uint16_t alen, const uint8_t *b, uint16_t blen)
{
    uint16_t total = alen + blen, pos, c, k, first;
    uint8_t slot, bad = 0, nm[NAME_LEN + 1];

    if (total > SLOT_SECS * 256)
        return 1;
    memset(nm, 0, sizeof(nm));
    strncpy((char *)nm, name, NAME_LEN);
    read_dir();
    slot = find((const char *)nm);
    if (slot == 255)
        for (slot = 0; slot < SLOTS && secbuf[slot * ENTRY]; ++slot)
            ;
    if (slot >= SLOTS || !nm[0])
        return 1;
    first = 1 + slot * SLOT_SECS;
    {   uint8_t ent[ENTRY];                     /* (kept to write the directory after the data) */
        memset(ent, 0, ENTRY);
        memcpy(ent, nm, NAME_LEN);
        ent[13] = (uint8_t)total;
        ent[14] = (uint8_t)(total >> 8);
        for (pos = 0; pos < total && !bad; pos += 256) {
            memset(secbuf, 0, 256);
            k = 0;
            if (pos < alen) {
                c = alen - pos;
                if (c > 256)
                    c = 256;
                memcpy(secbuf, a + pos, c);
                k = c;
            }
            if (k < 256 && pos + k < total) {
                c = total - (pos + k);
                if (c > 256 - k)
                    c = 256 - k;
                memcpy(secbuf + k, b + (pos + k - alen), c);
            }
            bad = sector_io(1, first + (pos >> 8));
        }
        if (!bad) {
            read_dir();
            memcpy(secbuf + slot * ENTRY, ent, ENTRY);
            bad = sector_io(1, 0);
        }
    }
    mz2500_disk_off();
    return bad;
}

uint8_t plat_file_load(const char *name, uint8_t *a, uint16_t alen, uint8_t *b, uint16_t blen)
{
    uint16_t total, want = alen + blen, pos, c, k, first;
    uint8_t slot, r = 0;

    if (read_dir() || (slot = find(name)) == 255) {
        mz2500_disk_off();
        return 1;
    }
    total = secbuf[slot * ENTRY + 13] | (secbuf[slot * ENTRY + 14] << 8);
    first = 1 + slot * SLOT_SECS;
    if (total < alen)
        r = 1;
    else {
        if (total < want)
            r = 2;
        else
            total = want;
        for (pos = 0; pos < total; pos += 256) {
            if (sector_io(0, first + (pos >> 8))) {
                r = pos < alen ? 1 : 2;
                break;
            }
            k = 0;
            if (pos < alen) {
                c = alen - pos;
                if (c > 256)
                    c = 256;
                memcpy(a + pos, secbuf, c);
                k = c;
            }
            if (k < 256 && pos + k < total) {
                c = total - (pos + k);
                if (c > 256 - k)
                    c = 256 - k;
                memcpy(b + (pos + k - alen), secbuf + k, c);
            }
        }
    }
    mz2500_disk_off();
    return r;
}
