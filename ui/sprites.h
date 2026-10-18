/* The moving sprites: the train, the plane, the tornado.  The engine moves them (sim_periodic) and
   keeps where they are; here they are drawn over the map, 2x2 cells each, as the Spectrum does
   (it ORs the 16x16 picture onto the screen). */
#ifndef SPRITES_H
#define SPRITES_H

#include <stdint.h>

#define MAX_SPRITES 3           /* the train, the plane, the tornado */

struct sprite {
    uint8_t x, y;               /* map cell of the top left */
    uint8_t id;                 /* picture 0..4 of assets/transport.spr */
    uint8_t on;
};

/* Fill s[MAX_SPRITES] from the engine's state.  frame animates the tornado. */
extern void sprites_collect(struct sprite *s, uint8_t frame);

/* The picture of map cell (mx, my) with the sprites over it: 8 bytes in art, from base (the cell's
   own 8 bytes).  Returns 0 if no sprite covers the cell, else a number 1..63 that tells the covering
   pictures apart (for deciding whether the cell needs drawing again). */
extern uint8_t sprites_cell(const struct sprite *s, uint8_t mx, uint8_t my, const uint8_t *base, uint8_t *art);

/* One quarter of a picture ORed onto 8 bytes: quarter (qx, qy), each 0 or 1.  Used by sprites_cell. */
extern void sprite_or(uint8_t id, uint8_t qx, uint8_t qy, const uint8_t *base, uint8_t *art);

#endif
