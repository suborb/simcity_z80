# SimCity ports built with z88dk.
#
#   make aqplus | nc200 | z88 | zx      build one platform   (output in build/<name>/)
#   make z88rom                         the Z88 as a ROM application: build/z88rom/simcity.epr
#   make zx-print                       the Spectrum again, tiles drawn by printing characters
#                                       (the same path as the other machines) to compare speed
#   make all                            build all four
#   make test                           the headless build the UI tests run
#   make check                          every automated test (test/run_all.sh)
#   make golden | uitest | tiletest | z88test   one group of tests
#   make ZCC='zcc' ...                 build with another compiler (or set ZCC in the environment: the tests use it too)
#   make engine                         regenerate engine/ and platform/zx from disassembly/sim_game.asm
#   make deadcode                       list engine code nothing reaches
#   make clean
#
# z88dk's tools (zcc, z88dk-z80asm, z88dk-ticks) must be on the PATH, with ZCCCFG set if z88dk needs it.

# 80cc with a frame pointer makes the smallest code, which the Z88's 32 KB ROM and the Spectrum need.
ZCC ?= zcc -compiler=80cc -fframe-pointer

# -DPORTABLE selects the engine's portable build; the include paths are for the assembler
# (engine, repository root for assets/) and the C compiler (ui).
COMMON = -Ca-DPORTABLE -Ca-Iengine -Ca-I. -Iui -Cc-standard-escape-chars -m

GAME    = ui/main.c ui/game.c ui/text.c ui/numfmt.c ui/numfmt.asm engine/engine_c.asm platform/common/hooks.asm
# The mini maps (ui/minimap.c), the budget and evaluation screens (HAVE_REPORTS) and the moving
# sprites (ui/sprites.c): not on the Spectrum, whose memory
# has no room for them (the Spectrum has its own budget screen).
EXTRAS  = ui/minimap.c ui/budget.c ui/evaluation.c ui/textfmt.c ui/sprites.c ui/cityfile.c platform/console/plat_sprites.asm \
          -DHAVE_MINIMAP -DHAVE_REPORTS -DHAVE_SPRITES
CONSOLE = platform/console/plat_console.c platform/console/plat_font.asm

# Everything a build depends on.
DEPS = Makefile $(wildcard ui/*.c ui/*.h engine/*.asm engine/*.h platform/common/*.asm \
         platform/console/* platform/test_ui/*) assets/map_art.bin assets/udgs.bin

AQPLUS = build/aqplus/simcity.aqx
NC200  = build/nc200/SIMCITY.COM
Z88    = build/z88/SIMCITY.BAS
Z88ROM = build/z88rom/simcity.epr
ZX     = build/zx/simcity.tap
ZXP    = build/zx-print/simcity.tap
TEST   = build/test/simcity.bin
TESTP  = build/testpanel/simcity.bin
TESTS  = build/testsprites/simcity.bin

.PHONY: all aqplus nc200 z88 z88rom zx zx-print test testpanel testsprites check golden uitest tiletest z88test engine deadcode clean

all: aqplus nc200 z88 zx

aqplus: $(AQPLUS)
nc200:  $(NC200)
z88:    $(Z88)
z88rom: $(Z88ROM)
zx:     $(ZX)
zx-print: $(ZXP)
test:   $(TEST)
testpanel: $(TESTP)
testsprites: $(TESTS)

# Aquarius+: the .aqx loads from the Aquarius+ file browser.  --generic-console pulls in the
# generic console driver, which can draw in the Aquarius+'s 320x200 bitmap mode (plat_init
# switches to it, IOCTL_GENCON_SET_MODE 4).  There characters are drawn from font and UDG
# pointers when printed, so the map gets the real tiles (HAVE_TILES) like the NC200.
$(AQPLUS): $(DEPS)
	@mkdir -p $(@D)
	$(ZCC) +aquarius -clib=aqplus -subtype=aqx --generic-console -create-app $(COMMON) \
	    -DHAVE_TILES -DTARGET_AQPLUS $(GAME) $(EXTRAS) $(CONSOLE) -o $(@D)/simcity

# NC200: RAM subtype (the default ROM-card subtype cannot host self-modifying code).  Tiles
# go through the console's font and UDG pointers (HAVE_TILES; see platform/console/plat_console.c).
$(NC200): $(DEPS)
	@mkdir -p $(@D)
	$(ZCC) +nc -clib=nc200 -subtype=ram -create-app $(COMMON) -DHAVE_TILES \
	    $(GAME) $(EXTRAS) $(CONSOLE) -o $(@D)/simcity

# Z88 as a BASIC program: the same screen, without the ROM image.
$(Z88): $(DEPS)
	@mkdir -p $(@D)
	$(ZCC) +z88 --generic-console -create-app -DTARGET_Z88 -Ca-DZ88_DI_SIM -DHAVE_TILES -DMAX_VIEW_W=32 -DMAX_VIEW_H=8 \
	    $(COMMON) $(GAME) $(EXTRAS) $(CONSOLE) platform/console/plat_z88.asm -o $(@D)/simcity

# Z88 as a ROM application for a 32 KB card (code and tables in ROM, the data in the RAM OZ allocates;
# see engine/sections.asm and platform/console/zpragma_z88rom.inc).  Output: simcity.epr and its banks.
# --generic-console: the map is drawn in the console's graphics window with our tile font (HAVE_TILES),
# the status text goes to OZ's text window.  Z88_DI_SIM runs each simulation slice with OZ's interrupts off.
Z88ROM_FLAGS = -subtype=app --generic-console -create-app -pragma-include:platform/console/zpragma_z88rom.inc \
               -DTARGET_Z88 -Ca-DZ88_DI_SIM -DHAVE_TILES -DMAX_VIEW_W=32 -DMAX_VIEW_H=8

$(Z88ROM): $(DEPS)
	@mkdir -p $(@D)
	$(ZCC) +z88 $(Z88ROM_FLAGS) $(COMMON) $(GAME) $(EXTRAS) $(CONSOLE) platform/console/plat_z88.asm \
	    platform/console/z88_dor.c -o $(@D)/simcity.bin

# ZX Spectrum.  The memory-layout pragmas (stack at the top of RAM, 32 column console, no
# 64 column font) are in platform/console/zpragma_zx.inc, which the tests use too.
#   -zorg=24000      below about that appmake embeds the program in a BASIC REM line at 23760
#                    instead of using a separate loader, so the code would not be where it was linked.
#   --reserve-regs-iy  the Spectrum ROM's interrupt routine needs IY to hold the system variables,
#                    so compiled code must not use it.  sccz80 never does; other compilers may.
#   HAVE_TILES       draw the map with the real pictures, blitted to screen memory.
ZX_PRAGMAS = platform/console/zpragma_zx.inc
ZX_FLAGS = -zorg=24000 -pragma-include:$(ZX_PRAGMAS) --reserve-regs-iy -create-app $(COMMON) \
           -DTARGET_ZX -Ca-DTARGET_ZX -DHAVE_TILES -DMAX_VIEW_W=32 -DMAX_VIEW_H=16

$(ZX): $(DEPS)
	@mkdir -p $(@D)
	$(ZCC) +zx $(ZX_FLAGS) $(GAME) $(CONSOLE) platform/console/plat_zx_blit.asm -o $(@D)/simcity

# The same, but each tile is drawn by printing a character whose picture comes from the console's
# font and UDG pointers, as on the NC200 and Aquarius+, instead of being copied to screen memory.
# Slower (about 7000 T-states a tile against a few hundred); there to compare the two by eye.
$(ZXP): $(DEPS)
	@mkdir -p $(@D)
	$(ZCC) +zx $(ZX_FLAGS) -DZX_PRINT $(GAME) $(CONSOLE) -o $(@D)/simcity

# Headless: a scripted keyboard and a screen in RAM instead of the console, run under z88dk-ticks.
$(TEST): $(DEPS)
	@mkdir -p $(@D)
	$(ZCC) +test $(COMMON) $(GAME) platform/test_ui/plat_test.c -o $@

# The same with a separate text window and a 32x8 map, the shape of the Z88's screen.
$(TESTP): $(DEPS)
	@mkdir -p $(@D)
	$(ZCC) +test $(COMMON) -DTEST_PANEL $(GAME) $(EXTRAS) platform/test_ui/plat_test.c -o $@

# The same, drawing the map from pictures (and the sprites over it), which the test reads back.
$(TESTS): $(DEPS)
	@mkdir -p $(@D)
	$(ZCC) +test $(COMMON) -DTEST_PANEL -DTEST_SPRITES -DHAVE_TILES $(GAME) $(EXTRAS) platform/test_ui/plat_test.c -o $@

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
