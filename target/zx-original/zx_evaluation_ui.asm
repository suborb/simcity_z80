; zx_evaluation_ui: lines 8862-9265 of disassembly/sim_game.asm (zx)
; Evaluation?
show_evaluation:
L95b8:
        ld      a,1
        ld      (V_simulation_disabled),a
        ld      hl,print_stats        
        ld      (V_menu_draw_hook),hl
        ld      ix,text_evaluation    
        call    print_routine_ix
        ld      hl,0
        ld      (V_menu_draw_hook),hl
        xor     a
        ld      (V_simulation_disabled),a
        jp      draw_map
 
;95d7
.text_evaluation
        defb        0,0
        defm        "          EVALUATIO"
        defb        'N'+128
        defb        3,0
        defm        "IS THE MAYOR DOING A GOOD JOB"
        defb        '?'+128
        defb        0,160,0
        defm        "           000% Ye"
        defb        's'+128
        defb        0
        defb        "           000% N"
        defb        'o'+128
        defb        3,0
        defb        "WHAT ARE THE WORST PROBLEMS"
        defb        '?'+128
        defb        0,160,0
        defm        "Traffic 000%    Pollution 000"
        defb        '%'+128
        defb        0
        defb        "  Crime 000%         "
        defm        "Fire 000"
        defb        '%'+128
        defb        0
        defm        "  Taxes 000% House prices 000"
        defb        '%'+128
        defb        0
        defm        "             Unemployment 000"
        defb        '%'+128
        defb        3,0
        defm        "POPULATIO"
        defb        'N'+128
        defb        0
        defm        "MIGRATIO"
        defb        'N'+128
        defb        0
        defm        "ASSESSED VALUE    "
        defb        '$'+128
        defb        3,0
        defm        "CATAGORY   :"
        defb        '-'+128
        defb        0
        defm        "GAME LEVEL :"
        defb        '-'+128
        defb        0
        defm        "CITY SCORE :- 50"
        defb        '0'+128

; Hmmm TODO
        defb        2,3
        defm        "g!     O"
        defb        'K'+128
        defb        4        ;inc b

; 38711
print_stats:                                ; $9737 / 38711
.L9737
        call    determine_city_class    ;VILLAGE, TOWN etc etc
        call    print_evaluation_stats
        ld      hl,V_display_population
        ld      a,(hl)
        inc     hl
        or      (hl)
        inc     hl
.L9744  or      (hl)
        ret     z
        call    print_evaluation_concerns
.L9749  call    print_city_score
        call    print_mayor_rating
        ret     


; 9750, 38746
; Population sizes to transition
D_population_boundaries:                        ; $9750 / 38736
                        ; $9750 / 38736
        defb    $d0, $07, $00       ;2000
        defb    $10, $27, $00       ;10000
        defb    $50, $c3, $00       ;50000
        defb    $a0, $86, $01       ;100000
        defb    $20, $a1, $07       ;500000

V_citysize:     defb    0       ; VAR $975F / 38751 - city size

; Calculate the city type
determine_city_class:
.L9760  xor     a
        ld      (V_citysize),a
        ld      ix,D_population_boundaries
        ld      b,5
.L976a  push    bc
        ld      de,(V_population)
        ld      a,(V_population+2)
        ld      b,a
.L9773  ld      l,(ix+0)
        ld      h,(ix+1)
        ld      c,(ix+2)
.L977c  call    l_sub24
        pop     bc
        and     a
        ret     p
        ld      hl,V_citysize
        inc     (hl)
        inc     ix
        inc     ix
        inc     ix
        djnz    L976a                   ; (-36)
        ret


V_eval_migration:    defb    0,0,0       ; VAR $978F / 38799 - migration

print_evaluation_stats:
.L9792  ld      hl,text_table
        ld      a,(V_difficulty)
        add     a,14            ;Levels
        call    get_word_from_table
        ld      bc,$140f
        ld      a,8
        call    print_string
        ld      hl,text_table
        ld      a,(V_citysize)
        add     a,17
        call    get_word_from_table
        ld      bc,$130f
        ld      a,10
        call    print_string
        ld      hl,V_display_population
        ld      bc,$0f14
        call    prt24bit
        ld      hl,(V_population)
        ld      a,(V_population+2)
        ld      c,a
        ld      de,(V_prev_year_population)
        ld      a,(V_prev_year_population+2)
        ld      b,a
        call    l_sub24
        ld      (V_eval_migration),hl
        ld      a,c
        ld      (V_eval_migration+2),a
        ld      hl,V_eval_migration        ;Migration?
        ld      bc,$1014
        call    prt24bit
        ld      hl,V_previous_city_score        ;Assessed value (*1000)
        ld      bc,$1114
        call    prt24bit
        ld      hl,(V_print_end_pos)
        ld      (textpos),hl
        call    print_zero_digit           ;Print 3 trailing 0s to multiply by 1000
        call    print_zero_digit

print_zero_digit:                                    ; $97F8 / 38904 - Print ASCII '0' at current textpos and advance; appends trailing zeros for x1000
.L97f8  ld      a,48
        call    prchar
        call    incprpos
        ret     

.V_eval_concern_total        defw        0        ; VAR $9801 / 38913 - accumulator for total concern score during evaluation screen

print_evaluation_concerns:
.L9803  ld      a,(V_TrafficAverage)           ;Traffic concern
        srl     a
        ld      l,a
        ld      h,0
        call    ckpercent
        ld      (V_eval_concern_total),hl
        ld      bc,$0A09
        call    prstat
        ld      a,(V_PolluteAverage)           ;Pollution concern
        srl     a
        ld      l,a
        ld      h,0
        call    ckpercent
        push    hl
        ld      bc,$0a1b
        call    prstat
        pop     hl                  
        ld      de,(V_eval_concern_total)
        add     hl,de
        ld      (V_eval_concern_total),hl
        ld      a,(V_concern_crime)           ;Crime concern
        srl     a
        srl     a
        ld      l,a
        ld      h,0
        call    ckpercent
        push    hl
        ld      bc,$0b09
        call    prstat
        pop     hl
        ld      de,(V_eval_concern_total)
        add     hl,de
        ld      (V_eval_concern_total),hl
        ld      a,(V_LVAverage)           ;Fire concern
        ld      l,a
        ld      h,0
        ld      d,h
        ld      e,l
        add     hl,hl
        add     hl,hl
        add     hl,de
        call    ckpercent
        push    hl
        ld      bc,$0b1b
        call    prstat
        pop     hl
        ld      de,(V_eval_concern_total)
        add     hl,de
        ld      (V_eval_concern_total),hl
        ld      a,(SMC_tax_rate)           ;Tax rate
        ld      l,a
        ld      h,0
        ld      de,$fffd
        add     hl,de
        ld      d,h
        ld      e,l
        add     hl,hl
        add     hl,hl
        call    ckpercent
        push    hl
        ld      bc,$0c09
        call    prstat
        pop     hl
        ld      de,(V_eval_concern_total)
        add     hl,de
        ld      (V_eval_concern_total),hl
        ld      a,(V_concern_house_price)           ;House prices concern
        ld      l,a
        ld      h,0
        call    ckpercent
        push    hl
        ld      bc,$0c1b
        call    prstat
        pop     hl
        ld      de,(V_eval_concern_total)
        add     hl,de
        ld      (V_eval_concern_total),hl
        ld      hl,(V_unemployment)          ;Unemployment concern
        call    ckpercent
        push    hl
        ld      bc,$0d1b
        call    prstat
        pop     hl
        ld      de,(V_eval_concern_total)
        add     hl,de
        ld      (V_eval_concern_total),hl
        ld      de,(V_unPwrdZCnt)
        srl     d
        rr      e
        srl     d
        rr      e
        ld      hl,(V_eval_concern_total)
        add     hl,de
        ld      (V_eval_concern_total),hl
        ld      de,0
        ld      a,(V_alertmessage)
        and     a
        jr      z,L98dc                 ; (3)
        ld      de,4
.L98dc  ld      hl,(V_eval_concern_total)
        add     hl,de
        ld      (V_eval_concern_total),hl
        ret     

; Check that a number is within a % range if not, set it to be so
; Entry: hl = number
; Exit:  hl = fixed number

.ckpercent  
        ld      a,h
        and     a
        jr      z,L98ee                 ; (6)
        jp      m,sethl0
        jp      p,sethl100
.L98ee  ld      a,l
        cp      101
        ret     c
.sethl100  
        ld      hl,100
        ret     
.sethl0 ld      hl,0000
        ret     

.V_city_score_display        defw        0        ; VAR $98FA / 39162 - final clamped city score 0-1000 for display; computed by print_city_score

print_city_score:
.L98fc  ld      hl,(V_eval_concern_total)
        ld      d,h
        ld      e,l
        add     hl,hl
        add     hl,de
        ex      de,hl
        ld      hl,250
        and     a
        sbc     hl,de
        add     hl,hl
        add     hl,hl
        call    clamp_hl_to_1000
        ld      (V_city_score_display),hl
        ld      bc,$150F
        call    prt16bit
        ret     


clamp_hl_to_1000:                                    ; $9919 / 39193 - If H<0 return HL=0; else return min(HL, 1000)
.L9919  ld      a,h
        and     a
        jp      p,L9922
        ld      hl,0
        ret     

; Subtract hl from 1000?
; Entry: hl = number
; Exit:  de=hl = factor
.L9922  ex      de,hl
        ld      hl,1000
        and     a
        sbc     hl,de
        jr      nc,L992d                ; (2)
        ld      d,h
        ld      e,l
.L992d  ex      de,hl
        ret     

V_mayor_rating: defb    0,0         ; VAR $992F / 39215 - mayor rating, db yes, db no


; Think this is mayor rating
print_mayor_rating:
.L9931  ld      hl,0
        ld      (V_mayor_rating),hl
        ld      b,100
.L9939  call    get_random_number
        ld      hl,(V_random_seed)
        ld      a,h
        and     3
        ld      h,a
        ld      de,(V_city_score_display)
        and     a
        sbc     hl,de
        jr      nc,L9951                ; (5)
        ld      hl,V_mayor_rating
        jr      increment_mayor_rating_bucket                   ; (3)

.L9951  ld      hl,V_mayor_rating+1
increment_mayor_rating_bucket:                                    ; $9954 / 39252 - Increment the appropriate mayor rating bucket (good/bad) based on concern score comparison
.L9954  inc     (hl)
        djnz    L9939                   ; (-30)
        ld      a,(V_mayor_rating)       ;Yes good job
        ld      l,a
        ld      h,0
        ld      bc,$050c
        call    print_hundred_at_bc
        ld      a,(V_mayor_rating+1)       ;No bad job
        ld      l,a
        ld      h,0
        ld      bc,$060c
        call    print_hundred_at_bc
        ret     

; Print a statistic
; If it's above 20% then change the colour
; Entry:  hl = statistic
;          bc = xy posn

.prstat  
        push    hl
        ld      a,l
        cp      20
        jr      c,L997b                 ; (5)
        ld      a,66
        ld      (textcol),a
.L997b  call    xypos
        ld      (textpos),hl
        pop     hl
        call    prhund
        ld      a,71
        ld      (textcol),a
        ret     


print_hundred_at_bc:                                    ; $998B / 39307 - Set textpos from BC coords, print HL as 3-digit percentage
.L998b  push    hl
        call    xypos
        ld      (textpos),hl
        pop     hl
        jp      prhund

