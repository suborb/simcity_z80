; funding: lines 8759-8861 of disassembly/sim_game.asm (engine)


apply_funding_percent:                                    ; $94FF / 38143 - Multiply HL by A/100 (16x8 -> 24-bit); returns allocated amount in HL
.L94ff  ld      e,a
        ld      d,0
        call    L_mult_24_16x16
        ld      a,100
        jp      div24_chl_by_a


;950a/38154
        IN_RODATA
D_funding_effect_mask:                  ; $950A / 38154 - funding ratio index -> road effect bitmask (16 levels)
        defb    $0F, $1F, $1F, $3F, $3F, $7F, $7F, $FF
        defb    $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF

D_funding_effect_level:                 ; $951A / 38170 - funding ratio index -> service effectiveness 0-15 (16 levels)
        defb    $00, $03, $06, $07, $08, $0A, $0C, $0F
        defb    $0F, $0F, $0F, $0F, $0F, $0F, $0F, $0F
        IN_CODE
        

;
; Turn the budget's allocated/requested figures into in-game effectiveness.
; ratio = allocated / (requested / 8), so full funding gives 8; the result indexes
; the two 16-entry tables above:
;   transport -> V_road_upgrade_mask / V_rail_upgrade_mask (crumble mask:
;                $FF = never crumbles, $0F = 1 in 16 per tile per tick)
;   police    -> V_PoliceEffect (0..15)    fire -> V_FireEffect (0..15)
; A service with a request below 20 is left at its best setting (mask $FF / level 15).
; SUSPECT: the fire section tests V_Transport_Funding_Requested rather than
; V_Budget_Fire_Funding_Requested for its "< 20" check (copy/paste from the first
; block) - so fire effectiveness is gated on the transport request.
alloc_funding_levels:                                    ; $952A / 38186
.L952a  ld      a,255
        ld      hl,(V_Transport_Funding_Requested)
        ld      de,20
        and     a
        sbc     hl,de
        jr      c,L9555                 ; (30)
        ld      hl,(V_Transport_Funding_Requested)
        srl     h
        rr      l
        srl     h
        rr      l
        srl     h
        rr      l
        ex      de,hl
        ld      hl,(V_Transport_Funding_Allocated)
        call    L_div16x16
        ld      c,l
        ld      b,0
        ld      hl,D_funding_effect_mask
        add     hl,bc
        ld      a,(hl)
.L9555  ld      (V_rail_upgrade_mask),a
        ld      (V_road_upgrade_mask),a
        ld      a,15
        ld      hl,(V_Budget_Police_Funding_Requested)
        ld      de,20
        and     a
        sbc     hl,de
        jr      c,L9586                 ; (30)
        ld      hl,(V_Budget_Police_Funding_Requested)
        srl     h
        rr      l
        srl     h
        rr      l
        srl     h
        rr      l
        ex      de,hl
        ld      hl,(V_Police_Funding_Allocated)
        call    L_div16x16
        ld      c,l
        ld      b,0
        ld      hl,D_funding_effect_level
        add     hl,bc
        ld      a,(hl)

.L9586  ld      (V_PoliceEffect),a
        ld      a,15
        ld      hl,(V_Transport_Funding_Requested)
        ld      de,20
        and     a
        sbc     hl,de
        jr      c,L95b4                 ; (30)
        ld      hl,(V_Budget_Fire_Funding_Requested)
        srl     h
        rr      l
        srl     h
        rr      l
        srl     h
        rr      l
        ex      de,hl
        ld      hl,(V_Fire_Funding_Allocated)
        call    L_div16x16
        ld      c,l
        ld      b,0
        ld      hl,D_funding_effect_level
        add     hl,bc
        ld      a,(hl)

.L95b4  ld      (V_FireEffect),a
        ret     

