; The entropy of the test build (test/zxn/run.py): fixed, so that the same keys make the same city.  (The shipping build's is the refresh register
; while the player chooses the level, platform/common/entropy.asm.)
        SECTION code_clib
        PUBLIC  _plat_entropy
_plat_entropy:
        ld      hl,ZXN_TEST_ENTROPY
        ret
