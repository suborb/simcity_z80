/* What the BDOS under z88dk-ticks (src/ticks/hook_cpm.c) does for the calls a program of the CP/M 2.2 and CP/M Plus world makes: sequential files, a directory search, a line,
   the time, the random record and truncation.  Prints "ok" or "FAIL <what>" for each; test/cpm/bdos.py runs it. */
#include <stdio.h>
#include <string.h>
#include <cpm.h>

static uint8_t fcb[36];
static uint8_t dma[128 * 4];

static int check(const char *what, int ok)
{
    printf("%s %s\n", ok ? "ok" : "FAIL", what);
    return ok;
}

static void name(const char *n)                         /* "T       DAT" in the FCB */
{
    memset(fcb, 0, sizeof fcb);
    memcpy(fcb + 1, n, 11);
}

int main(void)
{
    int i, found = 0;
    uint8_t r;
    uint8_t buf[4];
    uint8_t line[20];

    bdos(26, dma);                                      /* set DMA */
    name("BDOSTESTDAT");
    bdos(19, fcb);                                      /* delete (what is left of a last run) */
    r = bdos(22, fcb);                                  /* make */
    check("make file", r == 0);
    for (i = 0; i < 3; ++i) {
        memset(dma, 'A' + i, 128);
        r = bdos(21, fcb);                              /* write sequential */
        if (r) break;
    }
    check("three records written", i == 3);
    check("close", bdos(16, fcb) == 0);
    name("BDOSTESTDAT");
    check("open", bdos(15, fcb) == 0);
    for (i = 0; i < 4; ++i) {
        memset(dma, 0, 128);
        r = bdos(20, fcb);                              /* read sequential */
        if (i < 3 && (r != 0 || dma[0] != 'A' + i || dma[127] != 'A' + i)) break;
        if (i == 3) {
            check("a fourth record is the end of the file (1)", r == 1);
            break;
        }
    }
    check("three records read, in order", i >= 3);
    check("the current record is 3", fcb[32] == 3);
    bdos(36, fcb);                                      /* the random record from the sequential one */
    check("random record = 3", fcb[33] == 3 && fcb[34] == 0 && fcb[35] == 0);
    fcb[33] = 1;
    check("random read of record 1", bdos(33, fcb) == 0 && dma[0] == 'B');
    fcb[33] = 1;
    check("truncate at record 1", bdos(99, fcb) == 0);
    fcb[33] = 2;
    check("record 2 is gone", bdos(33, fcb) != 0);
    bdos(16, fcb);
    memset(fcb, 0, sizeof fcb);
    memset(fcb + 1, '?', 11);                           /* search for any file */
    memset(dma, 0, sizeof dma);
    r = bdos(17, fcb);
    while (r < 4 && found < 64) {
        if (dma[r * 32 + 1] == 'B' && dma[r * 32 + 2] == 'D') found += 1000;
        ++found;
        r = bdos(18, fcb);
    }
    check("search finds the file (and ends with 255)", found >= 1000 && r == 255);
    bdos(26, dma);
    name("BDOSTESTDAT");
    bdos(19, fcb);
    check("delete", bdos(15, fcb) != 0);
    line[0] = 10;
    bdos(10, line);                                     /* read a line */
    check("a line read: 5 characters 'hello'", line[1] == 5 && memcmp(line + 2, "hello", 5) == 0);
    memset(buf, 0, sizeof buf);
    r = bdos(105, buf);                                 /* the time */
    check("time of day: the days since 1978 are 365 or more, the BCD hours under 24", (((unsigned)buf[1] << 8) | buf[0]) > 365u && (buf[2] >> 4) < 3 && (r >> 4) < 6);
    return 0;
}
