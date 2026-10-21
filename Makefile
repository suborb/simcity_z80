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
# The table drawing of the screens, in assembler: for the targets that have HAVE_FIELDS (see ui/platform.h).
FIELDS  = ui/fmtfields.asm
# The sound hooks the engine calls: the platform's own, or none.
SOUND   = target/z88/plat_sound.asm              # one bit sound through the Z88's COM register
NOSOUND = platform/common/nosound.asm

CONSOLE = platform/console/plat_console.c platform/console/plat_font.asm
AQPLUS_PLATFORM = target/aqplus/plat_aqplus.c target/aqplus/plat_aqplus.asm
ZX_PLATFORM = target/zx/plat_zx.c target/zx/plat_zx.asm
Z88_PLATFORM = target/z88/plat_z88.c target/z88/plat_z88.asm


# Everything a build depends on.
DEPS = Makefile $(wildcard ui/*.c ui/*.h engine/*.asm engine/*.h platform/common/*.asm \
         platform/console/* target/*/*) assets/map_art.bin assets/udgs.bin assets/icons.bin

AQPLUS = build/aqplus/simcity.aqx
NC200  = build/nc200/simcity.img
Z88ROM = build/z88rom/simcity.epr
ZX     = build/zx/simcity.tap
ZXP    = build/zx-print/simcity.tap
TEST   = build/test/simcity.bin
TESTP  = build/testpanel/simcity.bin
TESTM  = build/testmodal/simcity.bin
TESTS  = build/testsprites/simcity.bin
TESTH  = build/testhires/simcity.bin

.PHONY: all aqplus z88rom zx zx-print test testpanel testmodal testsprites testhires check golden uitest tiletest z88test engine deadcode clean

all: aqplus z88rom zx

aqplus: $(AQPLUS)
z88rom: $(Z88ROM)
zx:     $(ZX)
zx-print: $(ZXP)
test:   $(TEST)
testpanel: $(TESTP)
testmodal: $(TESTM)
testsprites: $(TESTS)
testhires: $(TESTH)

$(AQPLUS): $(DEPS)
	@mkdir -p $(@D)
	$(ZCC) +aquarius -clib=aqplus -subtype=aqx -create-app --generic-console $(COMMON) -pragma-include:target/aqplus/zpragma.inc \
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
           -Itarget/zx -DTARGET_ZX -Ca-DTARGET_ZX

$(ZX): $(DEPS)
	@mkdir -p $(@D)
	$(ZCC) +zx $(ZX_FLAGS) $(GAME) $(ENTROPY) $(NOSOUND) $(ZX_PLATFORM) -o $(@D)/simcity

# The same, but each tile is drawn by printing a character whose picture comes from the console's
# font and UDG pointers, as on the NC200 and Aquarius+, instead of being copied to screen memory.
# Slower (about 7000 T-states a tile against a few hundred); there to compare the two by eye.
$(ZXP): $(DEPS)
	@mkdir -p $(@D)
	$(ZCC) +zx $(ZX_FLAGS) -DZX_PRINT $(GAME) $(ENTROPY) $(NOSOUND) $(ZX_PLATFORM) -o $(@D)/simcity


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

# The same, drawing the map from pictures (and the sprites over it), which the test reads back.
$(TESTS): $(DEPS)
	@mkdir -p $(@D)
	$(ZCC) +test $(COMMON) -Itarget/test_ui  -DTEST_PANEL -DTEST_SPRITES $(GAME) $(NOSOUND) $(FIELDS) target/test_ui/plat_test.c -o $@

# A 40x25 Aquarius+-shaped screen: its 19-row map window holds the high-resolution mini map.
$(TESTH): $(DEPS)
	@mkdir -p $(@D)
	$(ZCC) +test $(COMMON) -Itarget/test_ui  -DTEST_HIRES_MINIMAP $(GAME) $(MENU) $(NOSOUND) $(FIELDS) target/test_ui/plat_test.c -o $@

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
