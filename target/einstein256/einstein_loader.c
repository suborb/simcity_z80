/* Stage the UI overlays in VRAM; restore the requested overlay into CPU RAM.
   Both overlays are linked at einstein_overlay (the window).  SIMCITY.GAM and SIMCITY.MOD are read into it at start-up
   and copied to VRAM, in the unused part of the screen page, game first and the modal one after it.  SIMCITY.SND, the sound, is read to where it is linked and stays. */
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <fcntl.h>
#include <unistd.h>

#define VRAM_STAGE 0x6000u              /* (screen 5 with 192 lines ends at $6000; the atlas starts at $8000) */

extern uint8_t einstein_overlay[];      /* the window's address, and the two sizes (as the addresses of symbols) */
extern uint8_t einstein_game_size, einstein_modal_size;
extern uint8_t einstein_snd[];          /* the sound file's address and size, the same way */
extern uint8_t einstein_snd_size;

extern void v9938_fatal(const char *message);           /* (einstein_io.asm: prints the $-terminated string and exits) */
extern void vram_write(uint16_t address, const uint8_t *source, uint16_t length);
extern void vram_read(uint16_t address, uint8_t *destination, uint16_t length);

static uint16_t game_len, modal_len;    /* (sizes in whole CP/M records) */

static uint16_t records(uint16_t size) { return (size + 127u) & ~127u; }

static void vram_transfer(uint16_t vram, uint16_t length, uint8_t to_vram)
{
    uint8_t *buffer = einstein_overlay;

    while (length != 0) {
        uint16_t chunk = length > 256 ? 256 : length;
        if (to_vram)
            vram_write(vram, buffer, chunk);
        else
            vram_read(vram, buffer, chunk);
        vram += chunk;
        buffer += chunk;
        length -= chunk;
    }
}

/* length bytes of the file to where it is linked (the rest of its last record is zeros) */
static void read_file(const char *name, uint8_t *to, uint16_t length)
{
    int fd = open(name, O_RDONLY, 0);
    uint16_t total = 0;

    if (fd < 0)                                 /* (the files are looked for on the default drive) */
        v9938_fatal("SIMCITY.GAM/MOD/SND not found\r\n$");
    memset(to, 0, length);
    while (total < length) {
        int16_t count = (int16_t)read(fd, to + total, length - total);
        if (count <= 0)
            break;
        total += (uint16_t)count;
    }
    close(fd);
    if (total == 0)
        exit(1);
}

static void stage(const char *name, uint16_t vram, uint16_t length)
{
    read_file(name, einstein_overlay, length);
    vram_transfer(vram, length, 1);
}

void einstein_load_base(void)
{
    game_len = records((uint16_t)&einstein_game_size);
    modal_len = records((uint16_t)&einstein_modal_size);
    stage("SIMCITY.GAM", VRAM_STAGE, game_len);
    stage("SIMCITY.MOD", VRAM_STAGE + game_len, modal_len);
    vram_transfer(VRAM_STAGE, game_len, 0);
    read_file("SIMCITY.SND", einstein_snd, records((uint16_t)&einstein_snd_size));
}

/* (Called from the resident code: the overlay in the window is replaced, so nothing in an overlay may be running.) */
void plat_overlay_load(uint8_t overlay)
{
    if (overlay)
        vram_transfer(VRAM_STAGE + game_len, modal_len, 0);
    else
        vram_transfer(VRAM_STAGE, game_len, 0);
}
