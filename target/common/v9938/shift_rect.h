/* Moves a rectangle of the video RAM's first page by whole cells with one VDP copy (HMMM): what plat_scroll does to the screen and to the cell cache.  The
   rectangle is (x, y, w, h) in pixels; its content moves by (-mx, -my) pixels, and what comes into view at the far edges is left as it was.  The copy runs in the
   direction an overlapping one needs: from the far end when the content moves right or down.  Needs v9938_command and v9938_dir (plat_v9938.asm). */
extern void v9938_dir(uint8_t arg);

static void shift_rect(uint16_t x, uint16_t y, uint16_t w, uint16_t h, int16_t mx, int16_t my)
{
    uint16_t sx = x, dx = x, sy = y, dy = y, nx = w, ny = h;
    uint8_t arg = 0;

    if (mx > 0) {                               /* the content moves left */
        sx += mx;
        nx -= mx;
    } else if (mx < 0) {                        /* right: from the right edge */
        dx -= mx;
        nx += mx;
        sx += nx - 1;
        dx += nx - 1;
        arg |= 4;
    }
    if (my > 0) {
        sy += my;
        ny -= my;
    } else if (my < 0) {
        dy -= my;
        ny += my;
        sy += ny - 1;
        dy += ny - 1;
        arg |= 8;
    }
    if (!nx || !ny)
        return;
    v9938_dir(arg);
    v9938_command(sx, sy, dx, dy, nx, ny, 0, 0xD0);
}
