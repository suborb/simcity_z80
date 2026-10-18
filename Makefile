# SimCity ports built with z88dk.
#
#   make aqplus | nc200 | z88 | zx      build one platform   (output in build/<name>/)
#   make z88rom                         the Z88 as a ROM application: build/z88rom/simcity.epr
#   make zx-print                       the Spectrum again, tiles drawn by printing characters
#                                       (the same path as the other machines) to compare speed
#   make all                            build all four
#   make test                           the headless build the UI tests run
#   make check                          every automated test (test/run_all.sh)
#   make golden | uitest | tiletest | stacktest | z88test   one group of tests
#   make ZCC='zcc -compiler=NAME' ...  build with another compiler (give it on the command line)
#   make engine                         regenerate engine/ and platform/zx from disassembly/sim_game.asm
#   make deadcode                       list engine code nothing reaches
#   make clean
#
# z88dk is taken from $(Z88DK) (default ~/z88dk) and its bin directory goes first on PATH.

Z88DK  ?= $(HOME)/z88dk
export ZCCCFG ?= $(Z88DK)/lib/config
export PATH := $(Z88DK)/bin:$(PATH)

ZCC = zcc

# -DPORTABLE selects the engine's portable build; the include paths are for the assembler
# (engine, repository root for assets/) and the C compiler (ui).
COMMON = -Ca-DPORTABLE -Ca-Iengine -Ca-I. -Iui -Cc-standard-escape-chars -m

GAME    = ui/main.c ui/game.c engine/engine_c.asm platform/common/hooks.asm
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

.PHONY: all aqplus nc200 z88 z88rom zx zx-print test check golden uitest tiletest stacktest z88test engine deadcode clean

all: aqplus nc200 z88 zx

aqplus: $(AQPLUS)
nc200:  $(NC200)
z88:    $(Z88)
z88rom: $(Z88ROM)
zx:     $(ZX)
zx-print: $(ZXP)
test:   $(TEST)

# Aquarius+: the .aqx loads from the Aquarius+ file browser.  --generic-console pulls in the
# generic console driver, which can draw in the Aquarius+'s 320x200 bitmap mode (plat_init
# switches to it, IOCTL_GENCON_SET_MODE 4).  There characters are drawn from font and UDG
# pointers when printed, so the map gets the real tiles (HAVE_TILES) like the NC200.
$(AQPLUS): $(DEPS)
	@mkdir -p $(@D)
	$(ZCC) +aquarius -clib=aqplus -subtype=aqx --generic-console -create-app $(COMMON) \
	    -DHAVE_TILES -DTARGET_AQPLUS $(GAME) $(CONSOLE) -o $(@D)/simcity

# NC200: RAM subtype (the default ROM-card subtype cannot host self-modifying code).  Tiles
# go through the console's font and UDG pointers (HAVE_TILES; see platform/console/plat_console.c).
$(NC200): $(DEPS)
	@mkdir -p $(@D)
	$(ZCC) +nc -clib=nc200 -subtype=ram -create-app $(COMMON) -DHAVE_TILES \
	    $(GAME) $(CONSOLE) -o $(@D)/simcity

# Z88: OZ text console, so characters only for now.
$(Z88): $(DEPS)
	@mkdir -p $(@D)
	$(ZCC) +z88 -create-app -DTARGET_Z88 $(COMMON) $(GAME) $(CONSOLE) -o $(@D)/simcity

# Z88 as a ROM application for a 32 KB card (two 16 KB banks) with RAM for the data.  The engine
# keeps code and tables apart from its variables (see engine/sections.asm), so the code and
# tables go in ROM and the rest in the RAM OZ allocates.  platform/console/zpragma_z88rom.inc
# sets the origins.  The view is sized 32x16 (the Z88 map is 32 cells wide), which keeps the UI's
# shadow screen at 1 KB instead of 4 KB.  Output: simcity.epr (the ROM image) plus its banks;
# z88dk prints how many pages of RAM the application will ask OZ for.  Not yet run on a Z88.
Z88ROM_FLAGS = -subtype=app -create-app -pragma-include:platform/console/zpragma_z88rom.inc \
               -DTARGET_Z88 -DMAX_VIEW_W=32 -DMAX_VIEW_H=16

$(Z88ROM): $(DEPS)
	@mkdir -p $(@D)
	$(ZCC) +z88 $(Z88ROM_FLAGS) $(COMMON) $(GAME) $(CONSOLE) platform/console/z88_dor.c -o $(@D)/simcity.bin

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

stacktest:
	python3 test/stack/run.py

z88test:
	python3 test/z88/run.py

engine:
	python3 tools/split_engine.py

deadcode: $(TEST)
	python3 tools/find_dead.py

clean:
	rm -rf build
