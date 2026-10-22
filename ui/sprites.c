#include <stdint.h>
#include "engine.h"
#include "platform.h"
#include "sprites.h"

#ifdef HAVE_SPRITES

const uint8_t transport_sprites[160] = {      /* assets/transport.spr: 5 pictures of 16x16, a row two bytes */
    0x00, 0x00, 0x00, 0x40, 0x00, 0xC0, 0x01, 0xC0, 0x03, 0x82, 0x05, 0x06, 0x7F, 0xFC, 0x9F, 0xC4,
    0x2A, 0xA8, 0x05, 0x06, 0x03, 0x82, 0x01, 0xC0, 0x00, 0xC0, 0x00, 0x40, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x05, 0x20, 0x02, 0x58, 0x04, 0x90, 0x04, 0xA0, 0x0A, 0x48, 0x01, 0x50,
    0x04, 0xA0, 0x09, 0x40, 0x05, 0x20, 0x0A, 0x80, 0x04, 0x40, 0x02, 0x80, 0x04, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x04, 0x00, 0x04, 0x20, 0x02, 0x50, 0x0A, 0xE0, 0x09, 0x30, 0x0A, 0x80, 0x05, 0x50,
    0x0C, 0xA0, 0x05, 0x40, 0x0A, 0x20, 0x02, 0x80, 0x05, 0x40, 0x01, 0x00, 0x00, 0x80, 0x00, 0x00,
    0x00, 0x00, 0x7F, 0xFE, 0xD5, 0x55, 0xA2, 0x23, 0xA2, 0x23, 0xD5, 0x55, 0x7F, 0xFE, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x3C, 0x00, 0x5A, 0x00, 0x66, 0x00, 0x42, 0x00, 0x66, 0x00, 0x5A, 0x00, 0x66, 0x00, 0x42, 0x00,
    0x66, 0x00, 0x5A, 0x00, 0x66, 0x00, 0x42, 0x00, 0x66, 0x00, 0x5A, 0x00, 0x66, 0x00, 0x3C, 0x00
};

/* The engine's sprite state (engine/transport.asm, engine/disasters.asm); positions are x then y. */
extern uint8_t V_transport_pos[2], V_transport_sprite;
extern uint8_t V_aircrash_active, V_CrashXY[2];
extern uint8_t V_tornado_active, V_tornado_pos[2];

void sprites_collect(struct sprite *s, uint8_t frame)
{
    uint8_t t;

    s[0].on = 0;
    if (V_transport_active && V_transport_pos[0] < MAP_W && V_transport_pos[1] < MAP_H) {
        t = levelmap[V_transport_pos[1] * (uint16_t)MAP_W + V_transport_pos[0]];
        if (t != 31 && t != 32) {                   /* not out of sight under a bridge */
            s[0].on = 1;
            s[0].x = V_transport_pos[0];
            s[0].y = V_transport_pos[1];
            s[0].id = V_transport_sprite;
        }
    }
    s[1].on = V_aircrash_active != 0;
    s[1].x = V_CrashXY[0];
    s[1].y = V_CrashXY[1];
    s[1].id = 0;
    s[2].on = V_tornado_active != 0;
    s[2].x = V_tornado_pos[0];
    s[2].y = V_tornado_pos[1];
    s[2].id = (uint8_t)(1 + ((frame >> 3) & 1));    /* the two frames, swapping */
}

#ifdef HAVE_SPRITE_OVERLAY
const uint8_t sprite_blank[8] = { 0, 0, 0, 0, 0, 0, 0, 0 };
#endif

void sprite_or(uint8_t id, uint8_t qx, uint8_t qy, const uint8_t *base, uint8_t *art)
{
    const uint8_t *p = transport_sprites + id * 32u + qy * 16u + qx;
    uint8_t r;

    for (r = 0; r < 8; ++r, p += 2)
        art[r] = base[r] | *p;
}

uint8_t sprites_cell(const struct sprite *s, uint8_t mx, uint8_t my, const uint8_t *base, uint8_t *art)
{
    uint8_t i, key = 0, qx, qy;
    const uint8_t *from = base;

    for (i = 0; i < MAX_SPRITES; ++i) {
        qx = (uint8_t)(mx - s[i].x);
        qy = (uint8_t)(my - s[i].y);
        if (s[i].on && qx < 2 && qy < 2) {
            sprite_or(s[i].id, qx, qy, from, art);
            from = art;                             /* a second sprite goes over the first */
            key = (uint8_t)((key * 21 + s[i].id * 4 + qy * 2 + qx) % 63 + 1);     /* 1..63 */
        }
    }
    return key;
}

#endif
