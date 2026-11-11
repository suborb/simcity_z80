/* A cartridge for the PC-6001mkII to try the z88dk 320x200 mode:
     zcc +pc6001 -subtype=rom -clib=mk2 -create-app cart_demo.c -o cart_demo      (then pad cart_demo.bin to 16 KB: see the Makefile's `make mk2demo`)
   Text in each of the four pens (green, yellow, blue, red in the default colour set 4), a bar of each, and lines, a box and a circle. */
#include <stdio.h>
#include <conio.h>
#include <graphics.h>

static const int pen_colour[4] = { 2, 6, 1, 4 };            /* the console colours that map to the pens: green, brown (yellow), blue, red */
static const char *pen_name[4] = { "GREEN", "YELLOW", "BLUE", "RED" };

int main(void)
{
    int i, x, y;

    clg();
    textcolor(6);
    gotoxy(1, 1);
    printf("PC-6001mkII 320x200");
    gotoxy(1, 2);
    printf("z88dk -clib=mk2 cartridge");
    for (i = 0; i < 4; ++i) {
        if (i == 2) {                                       /* blue is the paper: show it on yellow, and its bar in a yellow frame */
            textbackground(6);
            textcolor(1);
        } else {
            textcolor(pen_colour[i]);
        }
        gotoxy(1, 4 + i);
        printf("pen %d: %s", i, pen_name[i]);
        textbackground(1);
        if (i == 2) {
            textcolor(6);
            drawb(159, 32 + i * 12 - 1, 98, 10);
            textcolor(1);
        }
        for (y = 0; y < 8; ++y)                             /* a bar, plotted a pixel at a time */
            for (x = 0; x < 96; ++x)
                plot(160 + x, 32 + i * 12 + y);
    }
    textcolor(6);
    drawb(8, 100, 140, 80);                                  /* a box */
    draw(8, 100, 148, 180);                                  /* its diagonals */
    draw(148, 100, 8, 180);
    textcolor(4);
    circle(240, 140, 50, 1);
    textcolor(2);
    circle(240, 140, 30, 1);
    textcolor(6);
    gotoxy(1, 24);
    printf("319 x 199, 40 x 25 cells");
    for (;;)
        ;
    return 0;
}
