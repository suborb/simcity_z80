; The moving sprites: the plane, the tornado's two frames and the train, 16x16 pixels each, 32 bytes
; (a row is 2 bytes, left then right).  Used by ui/sprites.c.
        SECTION rodata_user
        PUBLIC  _transport_sprites

_transport_sprites:
        BINARY  "assets/transport.spr"
