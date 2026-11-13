/* SPC-1500 platform, the cassette: a city is saved with z88dk's tape routines
   (arch/spc1500.h, libsrc/target/spc1500/spc1500/spc1500_tape.asm) as one
   file in the machine's own format: the map is its data and the 31 byte city
   header is kept in the file's header block.  The deck is the player's: PLAY
   (or RECORD and PLAY) first; the routines wait for it to run, and Shift and
   Break together give up.  A load passes over the headers of other files. */
#include <stdint.h>
#include "platform.h"
#include "menu.h"

#ifdef HAVE_FILES
extern int spc1500_tape_save(const char *name, const void *addr, uint16_t len,
                             const void *user, uint16_t ulen) __smallc;
extern int spc1500_tape_load_to(const char *name, void *buf, uint16_t len,
                                void *user, uint16_t ulen) __smallc;

static uint8_t wait_key(void)
{
    uint8_t k;

    while (!(k = plat_key()))
        plat_idle();
    return k;
}

/* (in the dialogue's box, where its keys were) */
uint8_t plat_file_save(const char *name, const uint8_t *a, uint16_t alen,
                       const uint8_t *b, uint16_t blen)
{
    plat_puts((uint8_t)(menu_col + 2), (uint8_t)(menu_row + 3),
              "RECORD+PLAY, THEN A KEY ");
    if (wait_key() == KEY_ESC)
        return 1;
    plat_puts((uint8_t)(menu_col + 2), (uint8_t)(menu_row + 3),
              "SHIFT+BREAK STOPS      ");
    return spc1500_tape_save(name, b, blen, a, alen) ? 1 : 0;
}

uint8_t plat_file_load(const char *name, uint8_t *a, uint16_t alen,
                       uint8_t *b, uint16_t blen)
{
    int r;

    plat_puts((uint8_t)(menu_col + 2), (uint8_t)(menu_row + 3),
              "PLAY.  SHIFT+BREAK STOPS");
    r = spc1500_tape_load_to(name, b, blen, a, alen);
    if (r == -1)
        return 1;                           /* nothing read */
    return r == (int)blen ? 0 : 2;          /* the map is whole, or partly over */
}
#endif
