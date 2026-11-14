/* SAM Coupe: the end of a scenario's time, the win or lose message (the modal overlay: a file's strings are pooled in the one constant section it ends in, so this has a file of its own). */
#include <stdint.h>
#include <string.h>
#include "engine.h"
#include "platform.h"

PLAT_CODE_MODAL_OVERLAY
PLAT_CONST_MODAL_OVERLAY
/* The game's own messages for the end of the time. */
static const char win_text[] =
    "You're A Winner! Your mayoral skill in city planning expertise has won you a key to the city. Local residents will erect monuments in your glory "
    "and name their first born after you. Why not run for governor?";
static const char lose_text[] =
    "Impeachment Notice! The entire population of this city has finally had enough of your inept planning and incompetent management. "
    "An angry mob - led by your mother - has been spotted in the vacinity of City Hall. You should seriously consider an extended vacation -- NOW. "
    "(or read the manual and try again)";

static void message_draw(uint8_t won)
{
    const char *s = won ? win_text : lose_text;
    char line[31];
    uint8_t n, row = 2;

    plat_text_clear();
    plat_text_puts(0, 0, won ? "SCENARIO WON" : "SCENARIO LOST");
    while (*s) {
        n = 0;
        while (n < 30 && s[n]) ++n;
        if (s[n]) {                                     /* break at the last space */
            uint8_t b = n;
            while (b && s[b] != ' ') --b;
            if (b) n = b;
        }
        memcpy(line, s, n);
        line[n] = 0;
        plat_text_puts(0, row++, line);
        s += n;
        while (*s == ' ') ++s;
    }
    plat_text_puts(0, 23, "ENTER TO GO ON");
    plat_flush();
}

uint8_t plat_scenario_message(uint8_t won)
{
    uint8_t k;

    message_draw(won);
    for (;;) {
        k = plat_key();
        if (k == KEY_ENTER || k == ' ' || k == KEY_ESC) {
            plat_text_clear();
            return 0;
        }
        if (k == CMD_QUIT) return 1;
        if (k == CMD_REDRAW) message_draw(won);
        else if (!k) plat_idle();
    }
}
