# SimCity ports built with z88dk.
#
#   make all                            build all binaries
#   make test                           the headless build the UI tests run
#   make check                          every automated test (test/run_all.sh)
#   make golden | uitest | tiletest | z88test   one group of tests
#   make ZCC='zcc' ...                 build with another compiler (or set ZCC in the environment: the tests use it too)
#   make engine                         regenerate engine/ and target/zx-original from disassembly/sim_game.asm
#   make deadcode                       list engine code nothing reaches
#   make clean
#

VERSION ?= 1.0.2

# 80cc with a frame pointer makes the smallest code, which the Z88's 32 KB ROM and the Spectrum need.
ZCC ?= zcc -compiler=80cc -fframe-pointer

# -DPORTABLE selects the engine's portable build; the include paths are for the assembler
# (engine, repository root for assets/) and the C compiler (ui).
COMMON = -Ca-DPORTABLE -Ca-Iengine -Ca-I. -Iui -Cc-standard-escape-chars -m

# The game core.  The optional features (the budget and evaluation screens, saving and loading, the mini maps,
# the sprites) are always compiled; each is switched on or off by the platform's plat_config.h, which defines
# HAVE_BUDGET and so on (see ui/platform.h), and compiles to nothing where it is off.
GAME    = ui/main.c ui/game.c ui/text.c ui/textfmt.c ui/numfmt.asm ui/budget.c ui/evaluation.c ui/cityfile.c \
          ui/minimap.c ui/sprites.c ui/prompt.c engine/engine_c.asm platform/common/hooks.asm
ENTROPY = platform/common/entropy.asm
MENU    = ui/menu.c
# The native pixel mini map's row builder, in assembler (HAVE_MINIMAP_NATIVE): for 640x200 screens of 3 bits a pixel (three planes,
# 8 colours): the Multi 8, the PC-8801, and the headless tests of it
MMNATIVE = target/common/minimap_640x200_3bpp.asm
# The table drawing of the screens, in assembler: for the targets that have HAVE_FIELDS (see ui/platform.h).
FIELDS  = ui/fmtfields.asm
# The sound hooks the engine calls: the platform's own, or none.
SOUND   = target/z88/plat_sound.asm              # one bit sound through the Z88's COM register
NOSOUND = platform/common/nosound.asm

CONSOLE = platform/console/plat_console.c platform/console/plat_font.asm
AQPLUS_PLATFORM = target/aqplus/plat_aqplus.c target/aqplus/plat_aqplus.asm
ZX_PLATFORM = target/zx/plat_zx.asm
MULTI8_PLATFORM = target/multi8/plat_multi8.c target/multi8/plat_multi8.asm
PC88_PLATFORM = target/pc88/plat_pc88.c target/pc88/plat_pc88.asm
Z88_PLATFORM = target/z88/plat_z88.c target/z88/plat_z88.asm


# Everything a build depends on.
DEPS = Makefile $(wildcard ui/*.c ui/*.h ui/*.asm engine/*.asm engine/*.h platform/common/*.asm \
         platform/console/*.[chai]* target/*/*.[chai]* target/*/*.inc) assets/map_art.bin assets/map_art_aq.bin assets/udgs.bin assets/icons.bin assets/icons_spec.bin

AQPLUS = build/aqplus/simcity.aqx
NC200  = build/nc200/simcity.img
Z88ROM = build/z88rom/simcity.epr
ZX     = build/zx/simcity.tap
MULTI8 = build/multi8/simcity.cas
PC88   = build/pc88/simcity.d88
TEST   = build/test/simcity.bin
TESTP  = build/testpanel/simcity.bin
TESTM  = build/testmodal/simcity.bin
TESTN  = build/testnarrow/simcity.bin
TESTS  = build/testsprites/simcity.bin
TESTO  = build/testoverlay/simcity.bin
TESTH  = build/testhires/simcity.bin
TESTK  = build/testnative/simcity.bin
TESTA  = build/testart/simcity.bin
TESTSC = build/testscroll/simcity.bin

.PHONY: all aqplus z88rom zx multi8 pc88 test testpanel testmodal testnarrow testsprites testoverlay testhires testnative testart testscroll check golden uitest tiletest z88test engine deadcode clean

all: aqplus z88rom zx multi8 pc88

aqplus: $(AQPLUS)
z88rom: $(Z88ROM)
zx:     $(ZX)
multi8: $(MULTI8)
pc88:   $(PC88)
test:   $(TEST)
testpanel: $(TESTP)
testmodal: $(TESTM)
testnarrow: $(TESTN)
testsprites: $(TESTS)
testoverlay: $(TESTO)
testhires: $(TESTH)
testnative: $(TESTK)
testart: $(TESTA)
testscroll: $(TESTSC)

$(AQPLUS): $(DEPS)
	@mkdir -p $(@D)
	$(ZCC) +aquarius -clib=aqplus -subtype=aqx -create-app $(COMMON) -pragma-include:target/aqplus/zpragma.inc \
	    -Itarget/aqplus -DTARGET_AQPLUS -Ca-DTARGET_AQPLUS -Ca-DSIM_STACK_TOP=0x3a00 $(GAME) $(ENTROPY) $(MENU) $(NOSOUND) $(FIELDS) $(AQPLUS_PLATFORM) -o $(@D)/simcity



Z88ROM_FLAGS = -subtype=app --generic-console -create-app -pragma-include:target/z88/zpragma_rom.inc \
               -Itarget/z88 -DTARGET_Z88 -Ca-DZ88_DI_SIM \
               -Cp-DAPP_VERSION=$(VERSION)

$(Z88ROM): $(DEPS)
	@mkdir -p $(@D)
	$(ZCC) +z88 $(Z88ROM_FLAGS) $(COMMON) $(GAME) $(ENTROPY) $(Z88_PLATFORM) -Cz--installer  \
	    target/z88/z88_dor.c $(SOUND) $(FIELDS) -o $(@D)/simcity.bin


ZX_PRAGMAS = target/zx/zpragma.inc
ZX_FLAGS = -pragma-include:target/zx/zpragma.inc --reserve-regs-iy -create-app $(COMMON) \
           -Itarget/zx -DTARGET_ZX -Ca-DTARGET_ZX -Ca-DFMT_WIDTH=32 -Ca-DSIM_STACK_SIZE=96

$(ZX): $(DEPS)
	@mkdir -p $(@D)
	$(ZCC) +zx $(ZX_FLAGS) $(GAME) $(ENTROPY) $(NOSOUND) $(FIELDS) $(ZX_PLATFORM) -o $(@D)/simcity

# The map's pictures baked for 640x200 screens of 3 bits a pixel (the Multi 8 and the PC-8801), from the CPC game's art
# (tools/extract_cpc_tiles.py).

build/common/tiles_640x200_3bpp.bin: assets/cpc_tiles.bin tools/extract_cpc_tiles.py
	@mkdir -p $(@D)
	python3 tools/extract_cpc_tiles.py assets/cpc_tiles.bin --planes $@

# The map's pictures at a quarter of the size for the mini maps (4 columns by 3 lines, 5 bytes each: HAVE_MINIMAP_ART)
build/common/minitiles_640x200_3bpp.bin: assets/cpc_tiles.bin tools/extract_cpc_tiles.py
	@mkdir -p $(@D)
	python3 tools/extract_cpc_tiles.py assets/cpc_tiles.bin --mini $@

# The Mitsubishi Multi 8 in its all-RAM mode: the code in the low 32 KB, the uninitialised data under the video planes.
# The image (code, data and the baked pictures) is loaded as one block from $0000 and must end below the uninitialised data,
# which starts at MULTI8_BSS (and is not on the tape: its 16 KB of map and mini maps, and the cache of what each cell shows).
MULTI8_BSS = 0xA900     # (its end, about $F750, is below the doubling table at $F800 and the stack above it)

$(MULTI8): $(DEPS) build/common/tiles_640x200_3bpp.bin build/common/minitiles_640x200_3bpp.bin
	@mkdir -p $(@D)
	$(ZCC) +multi8 -subtype=64k -create-app $(COMMON) -pragma-include:target/multi8/zpragma.inc \
	    -Itarget/multi8 -DTARGET_MULTI8 -Ca-DTARGET_MULTI8 -Ca-D__crt_org_bss=$(MULTI8_BSS) -Ca-DHAVE_MINIMAP_ART $(GAME) $(ENTROPY) $(MENU) $(NOSOUND) $(FIELDS) $(MMNATIVE) $(MULTI8_PLATFORM) -o $(@D)/simcity
	@size=`wc -c < $(@D)/simcity`; echo "multi8 image: $$size bytes (limit $$(( $(MULTI8_BSS) )))"; \
	    [ $$size -le $$(( $(MULTI8_BSS) )) ] || { echo "the image runs into the uninitialised data"; rm -f $@; exit 1; }
	@# the placer's variables must be in the low RAM: the planes are paged over $8000-$BFFF while it draws
	@v=`sed -n 's/^mp_flags *= \$$\([0-9A-Fa-f]*\).*/\1/p' $(@D)/simcity.map`; \
	    [ -n "$$v" ] && [ $$(( 0x$$v )) -lt 32768 ] || { echo "the placer's variables are not below $$8000 (mp_flags at $$v)"; rm -f $@; exit 1; }

# The NEC PC-8801 in its all-RAM mode (a bootable disk): code and data from $0000, the stack under the uninitialised data,
# which starts at PC88_BSS and runs over $C000, where the screen is paged in.  It shares the Multi 8's pictures.
PC88_BSS = 0xB600
PC88_CLIB ?=                    # -clib=v1: no ALU, for the original PC-8801 (plane by plane)
PC88_IMAGE_LIMIT = 0xB100       # (the doubling table is at $B100-$B2FF, and the stack gets the rest, down from the uninitialised data)

$(PC88): $(DEPS) build/common/tiles_640x200_3bpp.bin build/common/minitiles_640x200_3bpp.bin
	@mkdir -p $(@D)
	$(ZCC) +pc88 -subtype=disk $(PC88_CLIB) -create-app $(COMMON) -pragma-include:target/pc88/zpragma.inc \
	    -Itarget/pc88 -DTARGET_PC88 -Ca-DTARGET_PC88 -Ca-D__crt_org_bss=$(PC88_BSS) -Ca-DHAVE_MINIMAP_ART $(GAME) $(ENTROPY) $(MENU) $(NOSOUND) $(FIELDS) $(MMNATIVE) $(PC88_PLATFORM) -o $(@D)/simcity.bin
	@size=`wc -c < $(@D)/simcity.bin`; echo "pc88 image: $$size bytes (limit $$(( $(PC88_IMAGE_LIMIT) )))"; \
	    [ $$size -le $$(( $(PC88_IMAGE_LIMIT) )) ] || { echo "the image runs into the stack"; rm -f $@; exit 1; }
	@# the placer's variables must be in the low RAM: the screen is paged over $$C000-$$FFFF while it draws
	@v=`sed -n 's/^mm_src *= \$$\([0-9A-Fa-f]*\).*/\1/p' $(@D)/simcity.map`; \
	    [ -n "$$v" ] && [ $$(( 0x$$v )) -lt 49152 ] || { echo "the placer's variables are not below $$C000 (mm_src at $$v)"; rm -f $@; exit 1; }

# Headless: a scripted keyboard and a screen in RAM instead of the console, run under z88dk-ticks.
$(TEST): $(DEPS)
	@mkdir -p $(@D)
	$(ZCC) +test $(COMMON) -Itarget/test_ui  $(GAME) $(MENU) $(NOSOUND) target/test_ui/plat_test.c -o $@

# The same with a separate text window and a 32x8 map, the shape of the Z88's screen.
$(TESTP): $(DEPS)
	@mkdir -p $(@D)
	$(ZCC) +test $(COMMON) -Itarget/test_ui  -DTEST_PANEL $(GAME) $(NOSOUND) $(FIELDS) target/test_ui/plat_test.c -o $@

# The same headless screen at 64x24, with the optional screens on: verifies their full-height layout.
$(TESTM): $(DEPS)
	@mkdir -p $(@D)
	$(ZCC) +test $(COMMON) -Itarget/test_ui  -DTEST_MODAL $(GAME) $(NOSOUND) $(FIELDS) target/test_ui/plat_test.c -o $@

# A 32x24 screen, like the Spectrum's, with the optional screens on: verifies their 32 column layouts.
$(TESTN): $(DEPS)
	@mkdir -p $(@D)
	$(ZCC) +test $(COMMON) -Ca-DFMT_WIDTH=32 -Itarget/test_ui -DTEST_NARROW $(GAME) $(NOSOUND) $(FIELDS) target/test_ui/plat_test.c -o $@

# The same, drawing the map from pictures (and the sprites over it), which the test reads back.
$(TESTS): $(DEPS)
	@mkdir -p $(@D)
	$(ZCC) +test $(COMMON) -Itarget/test_ui  -DTEST_PANEL -DTEST_SPRITES $(GAME) $(NOSOUND) $(FIELDS) target/test_ui/plat_test.c -o $@

# The same with the sprites drawn over their tiles (HAVE_SPRITE_OVERLAY), as a platform with colour does.
$(TESTO): $(DEPS)
	@mkdir -p $(@D)
	$(ZCC) +test $(COMMON) -Itarget/test_ui  -DTEST_PANEL -DTEST_SPRITES -DTEST_OVERLAY $(GAME) $(NOSOUND) $(FIELDS) target/test_ui/plat_test.c -o $@

# A 40x25 Aquarius+-shaped screen: its 19-row map window holds the high-resolution mini map.
$(TESTH): $(DEPS)
	@mkdir -p $(@D)
	$(ZCC) +test $(COMMON) -Itarget/test_ui  -DTEST_HIRES_MINIMAP $(GAME) $(MENU) $(NOSOUND) $(FIELDS) target/test_ui/plat_test.c -o $@

# The same with the map scrolled by moving its pixels (HAVE_SCROLL): the test compares it with the one that draws it all.
$(TESTSC): $(DEPS)
	@mkdir -p $(@D)
	$(ZCC) +test $(COMMON) -Itarget/test_ui  -DTEST_SCROLL $(GAME) $(MENU) $(NOSOUND) $(FIELDS) target/test_ui/plat_test.c -o $@

# The same with the Multi 8's mini map, a colour a tile (HAVE_MINIMAP_NATIVE).
$(TESTK): $(DEPS)
	@mkdir -p $(@D)
	$(ZCC) +test $(COMMON) -Itarget/test_ui  -DTEST_NATIVE_MINIMAP $(GAME) $(MENU) $(NOSOUND) $(FIELDS) $(MMNATIVE) target/test_ui/plat_test.c -o $@

# ... and with the tiles' own pictures at a quarter of the size (HAVE_MINIMAP_ART; the assembler gets the same flag).
$(TESTA): $(DEPS) build/common/minitiles_640x200_3bpp.bin
	@mkdir -p $(@D)
	$(ZCC) +test $(COMMON) -Itarget/test_ui  -DTEST_NATIVE_ART -Ca-DHAVE_MINIMAP_ART $(GAME) $(MENU) $(NOSOUND) $(FIELDS) $(MMNATIVE) target/test_ui/plat_test.c -o $@

check:
	sh test/run_all.sh

golden:
	python3 test/golden/run.py --ticks 60 --views
	python3 test/golden/run.py --ticks 60 --views --coop

uitest:
	python3 test/ui/run.py

tiletest:
	python3 test/tiles/run.py
	python3 test/tiles/run.py --print

z88test:
	python3 test/z88/run.py

engine:
	python3 tools/split_engine.py

deadcode: $(TEST)
	python3 tools/find_dead.py

clean:
	rm -rf build
