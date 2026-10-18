#!/bin/sh
# Build the game for one platform with z88dk.
#
#   tools/build.sh aqplus | nc200 | z88 | zx | test      (output in build/<name>/)
#
# Needs z88dk on the PATH (or in ~/z88dk) with ZCCCFG set (default ~/z88dk/lib/config).
set -e
cd "$(dirname "$0")/.."
Z88DK=${Z88DK:-$HOME/z88dk}
export ZCCCFG=${ZCCCFG:-$Z88DK/lib/config}
export PATH="$Z88DK/bin:$PATH"

target=${1:?usage: tools/build.sh aqplus|nc200|z88|zx|test}
out=build/$target
mkdir -p "$out"

common="-Ca-DPORTABLE -Ca-Iengine -Ca-I. -Iui -Cc-standard-escape-chars -m"
sources="ui/main.c ui/game.c engine/engine_c.asm platform/common/hooks.asm"

console="platform/console/plat_console.c platform/console/plat_font.asm"

# HAVE_TILES: draw the map with the real pictures (see platform/console/plat_console.c).
# The Spectrum blits them to screen memory; the NC200 gets them through its console's
# font and UDG pointers, which needs a bitmap console that renders characters when
# they are printed, so the Aquarius+ (hardware character set: swapping the font would change the text already
# on screen) and the Z88 (OZ text console) still use characters for now.
case $target in
  aqplus) zcc +aquarius -clib=aqplus -subtype=aqx -create-app $common $sources $console -o $out/simcity ;;
  nc200)  zcc +nc -clib=nc200 -subtype=ram -create-app $common -DHAVE_TILES $sources $console -o $out/simcity ;;
  # UDGs are only available in the Spectrum console's 32 column mode; the screen is
  # 32x24 so the map is the original's 32x16 and the panel its 8 rows.
  # -zorg: below about 24000 appmake embeds the program in a BASIC REM line at 23760 instead of
  # using a separate loader, so the code would not be where it was linked.  The stack goes at
  # the top of RAM, below the UDG area, not in the small gap under the code that CLEAR leaves.
  zx)     zcc +zx -zorg=24000 -pragma-define:REGISTER_SP=0xFF57 -pragma-define:CLIB_ZX_CONIO32=1 -create-app $common \
              -DTARGET_ZX -Ca-DTARGET_ZX -DHAVE_TILES -DMAX_VIEW_W=32 -DMAX_VIEW_H=16 \
              $sources $console platform/console/plat_zx_blit.asm -o $out/simcity ;;
  z88)    zcc +z88 -create-app $common $sources $console -o $out/simcity ;;
  test)   zcc +test $common $sources platform/test_ui/plat_test.c -o $out/simcity.bin ;;
  *) echo "unknown target $target" >&2; exit 1 ;;
esac
ls -la "$out"
