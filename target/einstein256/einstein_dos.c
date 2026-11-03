/* The Einstein DOS's error prompt, turned into an error return (see the comment below). */
#include <stdint.h>
#include "platform.h"

extern void einstein_dos_fail(void);                    /* (einstein_io.asm) */
extern uint16_t einstein_dos_exit, einstein_dos_ret, einstein_dos_top, einstein_dos_slot;

/* The Einstein DOS asks "Try Again(Y/N)?" (in its own text mode, over our screen) when a disc operation fails, and N is a warm boot.  Its BDOS, which starts at the
   word at address 6, keeps the handlers for the errors in a table of seven words in RAM just after its entry jump.  Point them at einstein_dos_fail, which ends the
   BDOS call with an error, so the game's own "could not" message is shown.  The code at the BDOS entry is checked first and gives the addresses the handler needs (the
   offsets of the pieces differ between DOS80 V1.0 and XtalDOS 2.05, the shape is the same); a BDOS that does not look like that is left alone.  plat_exit puts the
   vectors back. */
#define W(p) (*(uint16_t *)(p))
static uint16_t dos_vectors[7];
static uint8_t dos_patched;

/* (these two run at start-up and at the end, when the game overlay is in its window: they are in it, not in the COM, which has to stay under 32 KB) */
PLAT_CODE_FILE_OVERLAY

void einstein_dos_quiet(void)
{
    uint8_t *b = (uint8_t *)W(6);
    uint8_t *p, *end;
    uint16_t i;

    /* jp entry; ld (save),sp; ld sp,top; ld hl,exit; push hl */
    if (b[0] != 0xC3 || b[0x14] != 0xED || b[0x15] != 0x73 || b[0x18] != 0x31 || b[0x1B] != 0x21 || b[0x1E] != 0xE5)
        return;
    einstein_dos_top = W(b + 0x19);
    einstein_dos_exit = W(b + 0x1C);
    p = (uint8_t *)einstein_dos_exit;
    if (p[0] != 0xED || p[1] != 0x7B || W(p + 2) != W(b + 0x16))        /* exit: ld sp,(save) */
        return;
    end = b + 0x70;                                                     /* ld hl,return; ex (sp),hl */
    for (p = b + 0x1F; p < end && (p[0] != 0x21 || p[3] != 0xE3); ++p)
        ;
    if (p >= end)
        return;
    einstein_dos_ret = W(p + 1);
    p = (uint8_t *)einstein_dos_ret;                                    /* its end: ld hl,(result); ld a,l; ld b,h; ret */
    end = p + 0x50;
    for (; p < end && (p[0] != 0x2A || p[3] != 0x7D || p[4] != 0x44 || p[5] != 0xC9); ++p)
        ;
    if (p >= end)
        return;
    einstein_dos_slot = W(p + 1);
    end = b + 0xE0;                                                     /* the dispatcher: dec a; ld hl,vectors */
    for (p = b + 0x80; p < end && (p[0] != 0x3D || p[1] != 0x21 || W(p + 2) != (uint16_t)(b + 3)); ++p)
        ;
    if (p >= end)
        return;
    for (i = 0; i < 7; ++i) {
        dos_vectors[i] = W(b + 3 + i * 2);
        W(b + 3 + i * 2) = (uint16_t)einstein_dos_fail;
    }
    dos_patched = 1;
}

void einstein_dos_loud(void)
{
    if (dos_patched) {
        uint8_t *b = (uint8_t *)W(6);
        uint16_t i;

        for (i = 0; i < 7; ++i)
            W(b + 3 + i * 2) = dos_vectors[i];
        dos_patched = 0;
    }
}
