; The BDOS stub of test/pcw/pcw.lua: what the game uses (6: keys, 105: time, 9: print), the version for z88dk's open(), the rest fail
        org     $F606
        ld      a,c
        cp      6
        jr      z,fn6
        cp      105
        jr      z,fn105
        cp      9
        jr      z,none
        cp      12
        jr      z,vers
        ld      a,$FF
        jr      done
vers:   ld      a,$31
        jr      done
fn6:    ld      a,e
        cp      $FF
        jr      nz,none
        in      a,($E2)                 ; the script is done: end (ticks -end F5F0)
        or      a
        jp      nz,$F5F0
        in      a,($E0)
        jr      done
fn105:  in      a,($E1)
        jr      done
none:   xor     a
done:   ld      l,a
        ld      h,0
        ret
