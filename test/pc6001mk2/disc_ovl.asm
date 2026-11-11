; The overlays of disc_test.py: OVERLAY_0 (5000 bytes: two tracks), OVERLAY_1 (300), OVERLAY_2 (100), each recognisable.
        SECTION OVERLAY_0
        PUBLIC  _ovl0
_ovl0:
        REPT    625
        defb    $a0,$a1,$a2,$a3,$a4,$a5,$a6,$a7
        ENDR
        SECTION OVERLAY_1
        REPT    300
        defb    $b1
        ENDR
        SECTION OVERLAY_2
        REPT    100
        defb    $c2
        ENDR
        SECTION code_user
        PUBLIC  _done
_done:  ld      a,3
        out     ($f8),a                 ; (the model's: write the logs, the screen and the disc)
        PUBLIC  _stop
_stop:  jr      _stop
