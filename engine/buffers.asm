; buffers: lines 11022-11040 of disassembly/sim_game.asm (engine)
; La950      
; At $a94e
; Coverage/density minimaps, 6912 bytes.  Cell (x,y) of the 96x96 level map lives at
; (y/N)*W + x/N, N = 4 for the 24x24 maps and 2 for the 48x48 ones:
;   +0     fire coverage      24x24  (   576)  0..15
;   +576   police coverage    24x24  (   576)  0..15
;   +1152  pollution          48x48  (  2304)  decays every other tick
;   +3456  traffic density    48x48  (  2304)  +20 per trip, decays every tick
;   +5760  power              1 bit per tile, 12 bytes per row (1152)
; (get_land_value_minimap_value is a misnomer: it addresses the pollution map)
minimaps:                                   ; $A950 / 43344
.La950
        defs        6912
;
; level- 9216 filled with 0x02
; At 50256
.levelmap
        defs        9216,2

