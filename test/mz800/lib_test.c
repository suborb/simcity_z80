/* z88dk's MZ-800 library: the console (printf, cursor, colours), the graphics (plot, unplot, xorplot, point, getmaxx/y) and the keyboard (getk, fgetc_cons, in_Inkey),
   built with zcc +mz800 and run on the ticks model (lib_test.py). */
#include <stdio.h>
#include <graphics.h>
#include <conio.h>
#include <input.h>
#include <stdint.h>
#include <arch/mz800.h>
#include <games.h>
#include <psg/PSGlib.h>

uint8_t point_results[8];
uint8_t vpeek_results[8];
uint16_t scancode_a;
uint8_t key_log[8];
uint8_t key_count;
char line[16];
uint8_t joy_results[4];
unsigned char song[] = { 0x85, 0x4A, 0x90, 0x38, 0x38, 0x9F, 0x38, 0x00 };   /* tone, volume 0, two frames, volume off, a frame, end */
uint8_t pressed_results[3];
volatile uint8_t finished, last_key;

int main(void)
{
    int x, y, k;

    /* (no clg() here: the console's start-up code must set the palette and clear the screen by itself) */
    printf("MZ-800 console\n");
    textcolor(1);
    printf("pen 1 ");
    textcolor(2);
    printf("pen 2 ");
    textcolor(15);
    printf("pen 3\n");
    gotoxy(2, 10);
    printf("at 2,10");
    mz800_gfx_ink(3, 0);
    for (x = 0; x < 100; ++x)
        plot(x, 100 + x / 4);
    mz800_gfx_ink(1, 0);
    for (y = 0; y < 50; ++y)
        plot(200, 100 + y);
    mz800_gfx_ink(2, 0);
    plot(5, 5);
    plot(6, 5);
    unplot(5, 5);
    mz800_gfx_ink(3, 0);
    plot(300, 190);
    xorplot(300, 190);                          /* ink, then toggled to paper */
    plot(301, 190);
    xorplot(302, 190);                          /* paper, toggled to ink */
    point_results[0] = point(200, 120);         /* (point() is 1 for any pen but 0) */
    point_results[1] = point(50, 112);
    point_results[2] = point(5, 5);             /* unplotted: 0 */
    point_results[3] = point(6, 5);
    point_results[4] = point(300, 190);         /* plotted and xor plotted: 0 */
    point_results[5] = point(302, 190);
    textcolor(4);                               /* plot uses the console's colours: conio RED is the red pen, GREEN the green, WHITE the white */
    plot(100, 60);
    textcolor(2);
    plot(102, 60);
    textcolor(15);
    plot(104, 60);
    textbackground(2);
    unplot(104, 60);                            /* unplot draws the paper: green */
    textbackground(0);
    mz800_gfx_ink(2, 0);
    drawb(10, 150, 41, 20);                     /* a box: (10,150) to (50,169) */
    circle(250, 150, 15, 1);                    /* a circle, radius 15 */
    draw(0, 175, 310, 175);                     /* lines past x = 255 and y = 191: the library's screen is 320x200 */
    draw(0, 195, 100, 195);
    point_results[7] = (uint8_t)(point(300, 175) && point(310, 175) && point(50, 195) && point(10, 150) && point(50, 150) && point(10, 169) && point(250, 135) && point(265, 150) && !point(250, 150));
    point_results[6] = (uint8_t)(getmaxx() == 319 && getmaxy() == 199);
    scancode_a = in_LookupKey('a');
    gotoxy(0, 3);
    printf("HHHH");                              /* plain, bold, inverse and underlined on rows 3 to 6 */
    gotoxy(0, 4);
    printf("\0332HHHH\0333");          /* VT52 codes of the generic console: ESC 2 bold on, ESC 3 off */
    gotoxy(0, 5);
    printf("\033pHHHH\033q");         /* ESC p inverse on, ESC q off */
    gotoxy(0, 6);
    printf("\0330HHHH\0331");         /* ESC 0 underline on, ESC 1 off */
    gotoxy(0, 13);
    printf("\n\nkeys: ");
    for (;;) {
        k = fgetc_cons();
        if (k == 'a')
            while (!in_KeyPressed(scancode_a))      /* (the key is let go of before fgetc_cons returns: this only checks the API is callable) */
                break;
        last_key = (uint8_t)k;
        if (key_count < 8)
            key_log[key_count++] = (uint8_t)k;
        if (k >= 32)                            /* (12 clears the screen and 27 starts an escape sequence) */
            printf("%c", k);
        if (k == 'q')
            break;
    }
    fgets_cons(line, 12);                       /* typed: a b BREAK c return: the delete code is the crt's CRT_KEY_DEL (12) */
    scancode_a = in_LookupKey('a');
    /* the console: cvpeek reads the characters back, and printing past the last line scrolls */
    textcolor(15);
    vpeek_results[0] = (uint8_t)cvpeek(0, 0);   /* 'M' of "MZ-800 console" */
    vpeek_results[1] = (uint8_t)cvpeek(1, 0);   /* 'Z' */
    vpeek_results[2] = (uint8_t)cvpeek(2, 10);  /* 'a' of "at 2,10" */
    gotoxy(0, 24);
    for (k = 0; k < 3; ++k)
        printf("\nline %d", k);                /* scrolls three lines: "MZ-800 console" is gone, "at 2,10" is on row 7 */
    vpeek_results[3] = (uint8_t)cvpeek(2, 7);   /* 'a' again, now three rows up */
    vpeek_results[4] = (uint8_t)cvpeek(0, 24);  /* 'l' of "line 2" */
    PSGPlayNoRepeat(song);
    for (k = 0; k < 6; ++k) {
        PSGFrame();
        for (x = 0; x < 20000; ++x) ;
    }
    finished = 1;
    for (;;) {
        joy_results[0] |= (uint8_t)joystick(1);
        joy_results[1] |= (uint8_t)joystick(2);
        joy_results[2] |= (uint8_t)joystick(6);        /* the cursor keys and space */
        joy_results[3] |= (uint8_t)joystick(3);        /* QAOP */
    }
}
