; messages: lines 9280-9516 of disassembly/sim_game.asm (engine)
        IN_DATA
V_TotalZPop:    defw    0       ; VAR $99AB / 39339 - TotalZPop used for sending alert messages
        IN_CODE


; Main alert setting loop?
; See https://github.com/osgcc/simcity/blob/master/src/sim/s_msg.c for
; conditions...
SendMessages:
.L99ad  xor     a
        ld      (V_alertmessage),a
        ld      hl,(V_ResZPop)     ;residential population
        ld      de,(V_ComZPop)     ;commercial population
        add     hl,de
        ld      de,(V_IndZPop)     ;industrial population
        add     hl,de
        ld      (V_TotalZPop),hl

        ; if ((TotalZPop >>2) >= ResZPop)
        ld      hl,(V_TotalZPop)
        srl     h
        rr      l
        srl     h
        rr      l
        ld      de,(V_ResZPop)
        and     a
        sbc     hl,de
        ld      a,1         ;More residential
        jp      z,set_alert_message
        jp      nc,set_alert_message
        ; if ((TotalZPop >>3) >= ComZPop)
        ld      hl,(V_TotalZPop)
        srl     h
        rr      l
        srl     h
        rr      l
        srl     h
        rr      l
        ld      de,(V_ComZPop)
        and     a
        sbc     hl,de
        ld      a,2         ;More commercial
        jp      z,set_alert_message
        jp      nc,set_alert_message
        ; if ((TotalZPop >>3) >= IndZPop)
        ld      hl,(V_TotalZPop)
        srl     h
        rr      l
        srl     h
        rr      l
        srl     h
        rr      l
        ld      de,(V_IndZPop)
        and     a
        sbc     hl,de
        ld      a,3         ;More industrial
        jp      z,set_alert_message
        jp      nc,set_alert_message

        ld      hl,V_display_population
        ld      a,(hl)
        inc     hl
        or      (hl)
        inc     hl
        or      (hl)
        ret     z

        ; if ((TotalZPop > 10) && ((TotalZPop <<1) > RoadTotal))
        ; This seems buggy? The << 1 isn't performed
        ld      hl,(V_TotalZPop)
        ld      de,10
        and     a
        sbc     hl,de
        jr      c,L9a3a                 ; (15)
        ld      hl,(V_TotalZPop)
        ld      de,(V_RoadTotal)
        and     a
        sbc     hl,de
        ld      a,4
        call    nc,set_alert_message

        ; if ((TotalZPop > 50) && (TotalZPop > RailTotal))
.L9a3a  ld      hl,(V_TotalZPop)
        ld      de,50
        and     a
        sbc     hl,de
        jr      c,L9a54                 ; (15)
        ld      hl,(V_TotalZPop)
        ld      de,(V_RailTotal)
        and     a
        sbc     hl,de
        ld      a,5
        call    nc,set_alert_message

        ; if ((TotalZPop > 10) && (PowerPop == 0))
.L9a54  ld      hl,(V_TotalZPop)
        ld      de,10
        and     a
        sbc     hl,de
        jr      c,L9a6e                 ; (15)
        ld      hl,(V_NuclearPop)
        ld      de,(V_CoalPop)
        add     hl,de
        ld      a,h
        or      l
        ld      a,6                     ;Need power
        jp      z,set_alert_message

        ; ORIG: if ((ResPop > 500) && (StadiumPop == 0)) {
.L9a6e  ld      a,(V_StadiumPop)
        and     a
        jr      nz,L9a82                ; (14)
        ld      hl,(V_ResZPop)
        ld      de,20
        and     a
        sbc     hl,de
        ld      a,7                     ;Need stadium
        jp      nc,set_alert_message

        ; ORIG: if ((IndPop > 70) && (PortPop == 0)) {
.L9a82  ld      a,(V_PortPop)
        and     a
        jr      nz,L9a96                ; (14)
        ld      hl,(V_IndZPop)
        ld      de,30
        and     a
        sbc     hl,de
        ld      a,8             ; Need port
        jp      nc,set_alert_message

        ; ORG: if ((ComPop > 100) && (APortPop == 0)) {
.L9a96  ld      a,(V_AirportPop)
        and     a
        jr      nz,L9aaa                ; (14)
        ld      hl,(V_ComZPop)
        ld      de,30
        and     a
        sbc     hl,de
        ld      a,9                 ;Need airport
        jp      nc,set_alert_message

.L9aaa  ld      a,(V_FirePop)
        and     a
        jr      nz,L9abe                ; (14)
        ld      hl,(V_TotalZPop)
        ld      de,30
        and     a
        sbc     hl,de
        ld      a,10
        jp      nc,set_alert_message

.L9abe  ld      a,(V_PolicePop)
        and     a
        jr      nz,L9ad2                ; (14)
        ld      hl,(V_TotalZPop)
        ld      de,25
        and     a
        sbc     hl,de
        ld      a,11
        jp      nc,set_alert_message

.L9ad2  ld      a,(SMC_tax_rate)
        cp      12
        ld      a,12                    ;Taxes too high
        jp      nc,set_alert_message


        ld      hl,(V_RailTotal)
        ld      de,(V_RoadTotal)
        add     hl,de
        ld      a,h
        or      l
        jr      z,L9af2                 ; (10)
        ld      a,(V_rail_upgrade_mask)
        cp      255
        ld      a,13
        jp      nz,set_alert_message

.L9af2  ld      hl,(V_FirePop)
        ld      a,h
        or      l
        jr      z,L9b03                 ; (10)
        ld      a,(V_FireEffect)
        cp      15
        ld      a,14
        jp      nz,set_alert_message

.L9b03  ld      hl,(V_PolicePop)
        ld      a,h
        or      l
        jr      z,L9b14                 ; (10)
        ld      a,(V_PoliceEffect)
        cp      15
        ld      a,15
        jp      nz,set_alert_message

.L9b14  ld      hl,(V_unPwrdZCnt)
        ld      de,10
        and     a
        sbc     hl,de
        ld      a,16
        jp      nc,set_alert_message
        ld      a,(V_brownout_detected)
        and     a
        ld      a,17            ;BROWNOUT DETECTED
        jp      nz,set_alert_message

        ld      a,(V_PolluteAverage)
        cp      60
        ld      a,19
        call    nc,set_alert_message
        ld      a,(V_concern_crime)
        cp      20

.L9b3a  ld      a,20
        call    nc,set_alert_message
        ld      a,(V_TrafficAverage)
        cp      60
        ld      a,21
        call    nc,set_alert_message
        ret     


set_alert_message:
.L9b4a  ld      (V_alertmessage),a
        ret     

; 39758/9b4e
        IN_RODATA
D_minimap_section_coords:               ; $9B4E / 39758 - (row, col) char-cell pairs for 9 minimap section flash highlight positions
        defb    $4, $3
        defb    $4, $4
        defb    $4, $5
        defb    $5, $3
        defb    $5, $4
        defb    $5, $5
        defb    $6, $3
        defb    $6, $4
        defb    $6, $5
        IN_CODE

