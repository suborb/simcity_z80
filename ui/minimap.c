/* The mini maps.  See minimap.h.  Map tile (x, y) is the 2x2 pixels (2x, 2y).  Every view gives the level of a
   tile (a small function each) and one routine turns levels into the 8 pixels of a picture row with an ordered
   dither: a pixel is lit if the level is above its threshold in a matrix.  The matrix depends on the view:
     speck     the city, power and transport: levels 0..4, a 2x2 matrix over each tile's own pixels;
     density   pollution, traffic and crime: levels 0..16, a 4x4 matrix over 2x2 tiles (the maps are 48x48);
     coverage  police and fire: levels 0..15, a 4x4 matrix over 4x4 tiles, a tile all lit or all dark (24x24). */
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
    "", "CITY", "POLLUTION", "POLICE COVERAGE", "FIRE COVERAGE", "TRAFFIC", "POWER", "TRANSPORT", "CRIME"
};

#ifdef HAVE_MINIMAP_NATIVE
/* The native pixel mini map: all 96 tile columns of every other tile row.  Every view but crime is built by the assembler
   routine in target/common/minimap_640x200_3bpp.asm (96 tiles a row is too slow in C).  Colours are 0 black, 1 blue, 2 red,
   3 magenta, 4 green, 5 cyan, 6 yellow, 7 white. */
#ifdef HAVE_MINIMAP_ART
extern void minimap_fast(uint8_t v, uint8_t sy);
#else
extern void minimap_fast(uint8_t v, uint8_t sy, uint8_t *out);
#endif

static uint8_t crime(uint8_t tx, uint8_t ty)    /* 0..15 on built-up tiles: grows with the distance from the centre, falls with police cover */
{
    uint8_t t = levelmap[ty * (uint16_t)MAP_W + tx], d, e, p;

    if (!(((t & 0x80) ? 0x99 : D_tile_flags[t]) & 0x10))
        return 0;
    d = (uint8_t)((tx > V_CCxy[0] ? tx - V_CCxy[0] : V_CCxy[0] - tx) + (ty > V_CCxy[1] ? ty - V_CCxy[1] : V_CCxy[1] - ty));
    if (d > 31)
        d = 31;
    e = d ? (uint8_t)(15 - ((32 - d) >> 1)) : 0;
    p = minimaps[MM_POLICE_OFFSET + (ty >> 2) * 24u + (tx >> 2)];
    return e > p ? (uint8_t)(e - p) : 0;
}

#ifdef HAVE_MINIMAP_ART
extern void minimap_tiles(uint8_t sy);

void minimap_row(uint8_t v, uint8_t sy)
{
    uint8_t tx;

    if (v != MM_CRIME) {
        minimap_fast(v, sy);
        return;
    }
    for (tx = 0; tx < MAP_W; ++tx)
        mm_col[tx] = crime(tx, (uint8_t)(sy << 1)) >> 1;
    minimap_tiles(sy);
}
#else
void minimap_row(uint8_t v, uint8_t sy, uint8_t *out)
{
    uint8_t tx;

    if (v != MM_CRIME) {
        minimap_fast(v, sy, out);
        return;
    }
    for (tx = 0; tx < MAP_W; ++tx)
        out[tx] = crime(tx, (uint8_t)(sy << 1)) >> 1;
}
#endif
#else
static const uint8_t bayer2[4] = { 0, 2, 3, 1 };
static const uint8_t bayer4[16] = { 0, 8, 2, 10,  12, 4, 14, 6,  3, 11, 1, 9,  15, 7, 13, 5 };

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

/* The tile's flags, as the engine's tile_to_flags: bit 1 rail, bit 2 road, bit 4 built up (a zone and what grows
   round it); a large zone's pieces (bit 7) count as $99. */
static uint8_t tile_flags(uint8_t t)
{
    return (t & 0x80) ? 0x99 : D_tile_flags[t];
}

static uint8_t at(uint8_t tx, uint8_t ty)
{
    return levelmap[ty * (uint16_t)MAP_W + tx];
}

/* The background of the maps that show only some tiles: a speck for water, trees and buildings. */
static uint8_t outline(uint8_t t)
{
    return tile_level(t) ? 1 : 0;
}

/* ---- the views: the level of tile (tx, ty) ---- */
static uint8_t lv_city(uint8_t tx, uint8_t ty)
{
    return tile_level(at(tx, ty));
}

static uint8_t lv_power(uint8_t tx, uint8_t ty)         /* the power map has a bit a tile, 12 bytes a row */
{
    return (minimaps[MM_POWER_OFFSET + ty * 12u + (tx >> 3)] & (0x80 >> (tx & 7))) ? 4 : outline(at(tx, ty));
}

static uint8_t lv_transport(uint8_t tx, uint8_t ty)
{
    uint8_t t = at(tx, ty);
    return (tile_flags(t) & 6) ? 4 : outline(t);
}

static uint8_t lv_density(uint16_t offset, uint8_t tx, uint8_t ty)      /* a 48x48 map of 0..255 */
{
    uint8_t v = minimaps[offset + (ty >> 1) * 48u + (tx >> 1)] >> 2;
    return v > 16 ? 16 : v;
}

static uint8_t lv_pollution(uint8_t tx, uint8_t ty)
{
    return lv_density(MM_POLLUTION_OFFSET, tx, ty);
}

static uint8_t lv_traffic(uint8_t tx, uint8_t ty)
{
    return lv_density(MM_TRAFFIC_OFFSET, tx, ty);
}

static uint8_t lv_police(uint8_t tx, uint8_t ty)        /* a 24x24 map of 0..15 */
{
    return minimaps[MM_POLICE_OFFSET + (ty >> 2) * 24u + (tx >> 2)];
}

static uint8_t lv_fire(uint8_t tx, uint8_t ty)
{
    return minimaps[MM_FIRE_OFFSET + (ty >> 2) * 24u + (tx >> 2)];
}

/* Crime on the built-up tiles, 0..15, as the Spectrum works it out: it grows with the distance from the city's
   centre (V_CCxy) and falls with the police cover there. */
static uint8_t lv_crime(uint8_t tx, uint8_t ty)
{
    uint8_t d, e, p;

    if (!(tile_flags(at(tx, ty)) & 0x10))
        return 0;
    d = (uint8_t)((tx > V_CCxy[0] ? tx - V_CCxy[0] : V_CCxy[0] - tx) + (ty > V_CCxy[1] ? ty - V_CCxy[1] : V_CCxy[1] - ty));
    if (d > 31)
        d = 31;
    e = d ? (uint8_t)(15 - ((32 - d) >> 1)) : 0;
    p = lv_police(tx, ty);
    return e > p ? (uint8_t)(e - p) : 0;
}

#define SPECK    0
#define DENSITY  1
#define COVERAGE 2
struct view {
    uint8_t (*level)(uint8_t tx, uint8_t ty);
    uint8_t kind;
};

static const struct view views[MM_VIEWS + 1] = {
    { 0, 0 },
    { lv_city, SPECK },
    { lv_pollution, DENSITY },
    { lv_police, COVERAGE },
    { lv_fire, COVERAGE },
    { lv_traffic, DENSITY },
    { lv_power, SPECK },
    { lv_transport, SPECK },
    { lv_crime, DENSITY },
};

/* 8 pixels of pixel row y: 4 tiles from column tx0 of tile row ty = y >> 1, two pixels each. */
static uint8_t row(const struct view *v, uint8_t tx0, uint8_t y)
{
    uint8_t bits = 0, m = 0x80, i, l, tx, ty = y >> 1;
    const uint8_t *b;

    for (i = 0; i < 4; ++i) {
        tx = (uint8_t)(tx0 + i);
        l = v->level(tx, ty);
        if (v->kind == SPECK)
            b = bayer2 + ((y & 1) << 1);
        else if (v->kind == DENSITY)
            b = bayer4 + ((y & 3) << 2) + ((tx & 1) << 1);
        else
            b = bayer4 + ((ty & 3) << 2) + (tx & 3);
        if (l > b[0])
            bits |= m;
        m >>= 1;
        if (l > b[v->kind == COVERAGE ? 0 : 1])
            bits |= m;
        m >>= 1;
    }
    return bits;
}

void minimap_cell(uint8_t v, uint8_t cx, uint8_t cy, uint8_t top, uint8_t cur_x, uint8_t cur_y,
                  uint8_t mark, uint8_t *art)
{
    uint8_t r, py = (uint8_t)(cur_y * 2 - top);     /* the cursor's pixel row in the picture (128 or more if above it) */

    for (r = 0; r < 8; ++r)
        art[r] = row(views + v, (uint8_t)(cx * 4), (uint8_t)(top + cy * 8 + r));
    if (mark && (cur_x >> 2) == cx && py < MM_PIXELS_H && (py >> 3) == cy) {
        r = (uint8_t)(py & 7);                      /* the tile's 2x2 pixels, inverted */
        art[r] ^= (uint8_t)(0xC0 >> ((cur_x & 3) * 2));
        art[r + 1] ^= (uint8_t)(0xC0 >> ((cur_x & 3) * 2));
    }
}

#ifdef HAVE_MINIMAP_COLOUR
uint8_t minimap_level(uint8_t v, uint8_t tx, uint8_t ty)
{
    return views[v].level(tx, ty);
}
#endif

#endif /* HAVE_MINIMAP_NATIVE */

#endif
