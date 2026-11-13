/* SPC-1500 platform, the cassette: a city is saved as the machine's own pair of blocks (plat_files.asm): a header block, 128 bytes (type 1, the file name, the size of the map, and the
   31 byte city header kept in its user area), and the map as the data block.  The deck is the player's: PLAY (or RECORD and PLAY) first; the ROM waits for it to run, and Shift and
   Break together give up.  A load passes over the headers of other files (the ROM waits for the next header leader). */
#include <stdint.h>
#include <string.h>
#include "platform.h"
#include "menu.h"

#ifdef HAVE_FILES
extern uint8_t spc1500_tape(uint8_t cmd, void *buf, uint16_t len) __smallc;

#define FCB_NAME   1                    /* the name, up to 14 characters, NUL padded */
#define FCB_NAMEMAX 14
#define FCB_SIZE   0x12                 /* the size of the data block */
#define FCB_USER   0x20                 /* the caller's header: up to 96 bytes */

static uint8_t fcb[128];                /* (above $8000: the ROM that reads and writes it hides the memory below) */

static uint8_t wait_key(void)
{
    uint8_t k;

    while (!(k = plat_key()))
        plat_idle();
    return k;
}

uint8_t plat_file_save(const char *name, const uint8_t *a, uint16_t alen, const uint8_t *b, uint16_t blen)
{
    uint8_t i;

    plat_puts((uint8_t)(menu_col + 2), (uint8_t)(menu_row + 3), "RECORD+PLAY, THEN A KEY ");   /* in the dialogue's box, where its keys were */
    if (wait_key() == KEY_ESC)
        return 1;
    plat_puts((uint8_t)(menu_col + 2), (uint8_t)(menu_row + 3), "SHIFT+BREAK STOPS      ");
    memset(fcb, 0, sizeof(fcb));
    fcb[0] = 1;
    for (i = 0; i < FCB_NAMEMAX && name[i]; ++i)
        fcb[FCB_NAME + i] = (uint8_t)name[i];
    fcb[FCB_SIZE] = (uint8_t)blen;
    fcb[FCB_SIZE + 1] = (uint8_t)(blen >> 8);
    memcpy(&fcb[FCB_USER], a, alen);
    if (spc1500_tape(2, fcb, 128))
        return 1;
    return spc1500_tape(3, (void *)b, blen) ? 1 : 0;
}

uint8_t plat_file_load(const char *name, uint8_t *a, uint16_t alen, uint8_t *b, uint16_t blen)
{
    uint8_t i;

    plat_puts((uint8_t)(menu_col + 2), (uint8_t)(menu_row + 3), "PLAY.  SHIFT+BREAK STOPS");
    for (;;) {
        if (spc1500_tape(0, fcb, 128))
            return 1;                           /* nothing read */
        for (i = 0; i < FCB_NAMEMAX; ++i) {
            if (name[i] != (char)fcb[FCB_NAME + i])
                break;
            if (!name[i])
                break;
        }
        if (i == FCB_NAMEMAX || (!name[i] && !fcb[FCB_NAME + i]))
            break;                              /* this one */
    }
    memcpy(a, &fcb[FCB_USER], alen);
    return spc1500_tape(1, b, blen) ? 2 : 0;    /* the map is whole, or partly overwritten */
}
#endif
