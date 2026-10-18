/* The mini maps.  See minimap.h.  Map tile (x, y) is the 2x2 pixels (2x, 2y); each picture row is
   8 pixels, worked out from the engine's data a row at a time. */
#include <stdint.h>
#include "engine.h"
#include "platform.h"
#include "minimap.h"
#ifdef HAVE_MINIMAP
#define MM_POLLUTION_OFFSET 1152            /* into minimaps[] */
#define MM_FIRE_OFFSET      0
#define MM_POLICE_OFFSET    576
#define MM_TRAFFIC_OFFSET   3456
#define MM_POWER_OFFSET     5760

extern const uint8_t D_tile_flags[];

const char *const minimap_names[MM_VIEWS + 1] = {
    "", "CITY", "POLLUTION", "POLICE COVERAGE", "FIRE COVERAGE", "TRAFFIC", "POWER"
};

/* Ordered dither: a pixel is lit if the level is above its threshold in the matrix. */
static const uint8_t bayer2[4] = { 0, 2, 3, 1 };
static const uint8_t bayer4[16] = { 0, 8, 2, 10,  12, 4, 14, 6,  3, 11, 1, 9,  15, 7, 13, 5 };

uint8_t minimap_top(uint8_t cur_y)
{
    return (uint8_t)((cur_y / 32) * 64);
}

/* How much of a tile's 2x2 pixels are lit, 0..4: dirt 0, water 1, trees 2, roads, rails and wires
   3, anything built 4. */
static uint8_t tile_level(uint8_t t)
{
    if (t & 0x80)
        return 4;                           /* a large zone */
    if (t == 2 || t == 6)
        return t == 2 ? 0 : 2;              /* dirt, trees */
    if (t <= 5 || t == 68)
        return 1;                           /* water, its edges, a flood */
    return (t < 56 && (D_tile_flags[t] & 0x0E)) ? 3 : 4;
}

/* Pixels 2k and 2k+1 of a row for a tile of this level: bayer2 row (y & 1). */
#define PAIR(bits, m, l, b)  do { if ((l) > (b)[0]) (bits) |= (m); (m) >>= 1; \
                                  if ((l) > (b)[1]) (bits) |= (m); (m) >>= 1; } while (0)

/* The city: 4 tiles of the level map, 2 pixels each. */
static uint8_t row_city(const uint8_t *p, uint8_t y)
{
    uint8_t bits = 0, m = 0x80, i, l;
    const uint8_t *b = bayer2 + ((y & 1) << 1);

    for (i = 0; i < 4; ++i, ++p) {
        l = tile_level(*p);
        PAIR(bits, m, l, b);
    }
    return bits;
}

/* Power: what has it solid, the rest as the city but no more than a speck.  p is the city row and
   `power` the power map's bits for these 4 tiles, in the top 4 bits. */
static uint8_t row_power(const uint8_t *p, uint8_t power, uint8_t y)
{
    uint8_t bits = 0, m = 0x80, i, l;
    const uint8_t *b = bayer2 + ((y & 1) << 1);

    for (i = 0; i < 4; ++i, ++p, power <<= 1) {
        l = (power & 0x80) ? 4 : tile_level(*p);
        if (!(power & 0x80) && l > 1)
            l = 1;
        PAIR(bits, m, l, b);
    }
    return bits;
}

/* A density 0..255 as 0..16: 4x4 pixels of a 48x48 map's cell. */
static uint8_t level16(uint8_t v)
{
    v >>= 2;
    return v > 16 ? 16 : v;
}

/* 8 pixels from 2 cells of a 48 wide map, 4 pixels each. */
static uint8_t row_density(const uint8_t *p, uint8_t y)
{
    uint8_t bits = 0, m = 0x80, i, l, c;
    const uint8_t *b = bayer4 + ((y & 3) << 2);

    for (c = 0; c < 2; ++c, ++p) {
        l = level16(*p);
        for (i = 0; i < 4; ++i, m >>= 1)
            if (l > b[i])
                bits |= m;
    }
    return bits;
}

/* 8 pixels from 1 cell of a 24 wide map (0..15), 8 pixels each: each matrix entry is 2x2 pixels. */
static uint8_t row_coverage(uint8_t v, uint8_t y)
{
    uint8_t bits = 0, m = 0x80, i;
    const uint8_t *b = bayer4 + (((y & 7) >> 1) << 2);

    for (i = 0; i < 4; ++i, ++b) {
        if (v > *b)
            bits |= m | (m >> 1);
        m >>= 2;
    }
    return bits;
}

void minimap_cell(uint8_t v, uint8_t cx, uint8_t cy, uint8_t top, uint8_t cur_x, uint8_t cur_y,
                  uint8_t mark, uint8_t *art)
{
    uint8_t r, y, ty, shift;
    const uint8_t *city;

    for (r = 0; r < 8; ++r) {
        y = (uint8_t)(top + cy * 8 + r);                    /* pixel row, 0..191 */
        ty = y >> 1;                                        /* map row */
        city = levelmap + ty * (uint16_t)MAP_W + cx * 4u;
        switch (v) {
        case MM_POLLUTION:
            art[r] = row_density(minimaps + MM_POLLUTION_OFFSET + (y >> 2) * 48u + cx * 2u, y);
            break;
        case MM_TRAFFIC:
            art[r] = row_density(minimaps + MM_TRAFFIC_OFFSET + (y >> 2) * 48u + cx * 2u, y);
            break;
        case MM_POLICE:
            art[r] = row_coverage(minimaps[MM_POLICE_OFFSET + (y >> 3) * 24u + cx], y);
            break;
        case MM_FIRE:
            art[r] = row_coverage(minimaps[MM_FIRE_OFFSET + (y >> 3) * 24u + cx], y);
            break;
        case MM_POWER:
            shift = (uint8_t)((cx & 1) ? 0 : 4);            /* 8 tiles a byte, 4 for this cell */
            art[r] = row_power(city, (uint8_t)((minimaps[MM_POWER_OFFSET + ty * 12u + (cx >> 1)] >> shift) << 4), y);
            break;
        default:                                            /* MM_CITY */
            art[r] = row_city(city, y);
            break;
        }
    }
    if (mark && (cur_x >> 2) == cx && cur_y * 2u >= top && ((cur_y * 2u - top) >> 3) == cy) {
        r = (uint8_t)((cur_y * 2u - top) & 7);                  /* the tile's 2x2 pixels, inverted */
        art[r] ^= (uint8_t)(0xC0 >> ((cur_x & 3) * 2));
        art[r + 1] ^= (uint8_t)(0xC0 >> ((cur_x & 3) * 2));
    }
}

#endif
