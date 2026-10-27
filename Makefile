# SimCity ports built with z88dk.
#
#   make all                            build all binaries
#   make test                           the headless build the UI tests run
#   make check                          every automated test (test/run_all.sh)
#   make golden | uitest | tiletest | z88test   one group of tests
#   make ZCC='zcc' ...                 build with another compiler (or set ZCC in the environment: the tests use it too)
#   make deadcode                       list engine code nothing reaches
#   make clean
#

VERSION ?= 1.1.0

# 80cc with a frame pointer makes the smallest code, which the Z88's 32 KB ROM and the Spectrum need.
ZCC ?= zcc -compiler=80cc -fframe-pointer

# -DPORTABLE selects the engine's portable build; the include paths are for the assembler
# (engine, repository root for assets/) and the C compiler (ui).
COMMON = -Cp-DAPP_VERSION=$(VERSION) -Ca-DPORTABLE -Ca-Iengine -Ca-I. -Iui -Cc-standard-escape-chars -m

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
# The file name editor of the targets that draw their own text (in assembler: the Multi 8 and the PC-8801)
LINEEDIT = target/common/line_editor.asm
# The table drawing of the screens, in assembler: for the targets that have HAVE_FIELDS (see ui/platform.h).
FIELDS  = ui/fmtfields.asm
# The sound hooks the engine calls: the platform's own, or none.
SOUND   = target/z88/plat_sound.asm              # one bit sound through the Z88's COM register
NOSOUND = platform/common/nosound.asm

CONSOLE = platform/console/plat_console.c platform/console/plat_font.asm
AQPLUS_PLATFORM = target/aqplus/plat_aqplus.c target/aqplus/plat_aqplus.asm
ZX_PLATFORM = target/zx/plat_zx.asm
MULTI8_PLATFORM = target/multi8/plat_multi8.c target/multi8/plat_multi8.asm target/common/plat_charts.c target/common/plat_icons.c
PC88_PLATFORM = target/pc88/plat_pc88.c target/pc88/plat_pc88.asm target/pc88/plat_pc88_files.asm target/common/plat_charts.c target/common/plat_icons.c
SAM_PLATFORM_NOFILES = target/sam/plat_sam.c target/sam/plat_sam.asm target/common/minimap_key.c
Z88_PLATFORM = target/z88/plat_z88.c target/z88/plat_z88.asm target/z88/fgets_cons.asm


# Everything a build depends on.
DEPS = Makefile $(wildcard ui/*.c ui/*.h ui/*.asm engine/*.asm engine/*.inc engine/*.h platform/common/*.asm \
         platform/console/*.[chai]* target/*/*.[chai]* target/*/*.inc) assets/map_art.bin assets/map_art_aq.bin assets/udgs.bin assets/icons.bin assets/icons_spec.bin assets/cpc_icons.bin assets/st_sounds.bin

AQPLUS = build/aqplus/simcity.aqx
NC200  = build/nc200/simcity.img
Z88ROM = build/z88rom/simcity.epr
ZX     = build/zx/simcity.tap
MULTI8 = build/multi8/simcity.cas
PC88   = build/pc88/simcity.d88
SAM    = build/sam/simcity.mgt
ZXN   = build/zxn/simcity.nex
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

.PHONY: all dist aqplus z88rom zx multi8 pc88 sam zxn test testpanel testmodal testnarrow testsprites testoverlay testhires testnative testart testscroll check golden uitest tiletest z88test deadcode clean

all: aqplus z88rom zx multi8 pc88 sam zxn

# The zip files for distribution, one for each machine (build/dist/; tools/make_dist.py)
dist: aqplus z88rom multi8 pc88 sam zxn
	python3 tools/make_dist.py

aqplus: $(AQPLUS)
z88rom: $(Z88ROM)
zx:     $(ZX)
multi8: $(MULTI8)
pc88:   $(PC88)
sam:    $(SAM)
zxn:   $(ZXN)
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

# The Aquarius+ build uses all its RAM (z88dk's -subtype=allram: a bootstrap maps RAM pages 56-59 into the four banks and loads the image at
# $0200, see zpragma.inc).  The video is paged over bank 3 while a cell is drawn, so the placer, and what it reads, must be
# below $C000, and so must the stacks (they are at $0200-$0FFF, under the code, which starts at $1000: zpragma.inc).
$(AQPLUS): $(DEPS)
	@mkdir -p $(@D)
	$(ZCC) +aquarius -clib=aqplus -subtype=allram -create-app $(COMMON) -pragma-include:target/aqplus/zpragma.inc \
	    -Itarget/aqplus -DTARGET_AQPLUS -Ca-DTARGET_AQPLUS -Ca-DSIM_STACK_TOP=0x0c00 -Ca-DHAVE_MINIMAP_SQUARE -Ca-DHAVE_SOUND -Ca-DAY_SKIP=43 -Ca-DAY_SCALE $(GAME) $(ENTROPY) $(MENU) target/aqplus/plat_sound.asm target/common/ay_hooks.asm target/common/ay_sfx.asm $(FIELDS) $(MMNATIVE) $(AQPLUS_PLATFORM) -o $(@D)/simcity.bin
	@for s in _aq_blit8 aq_cell _plat_put _plat_clear _plat_init aq_scratch aq_box _font_8x8_bbc_system _view_tile_art _aq_icons; do \
	    v=`sed -n "s/^$$s *= \$$\([0-9A-Fa-f]*\).*/\1/p" $(@D)/simcity.map | head -1`; \
	    [ -z "$$v" ] || [ $$(( 0x$$v )) -lt 49152 ] || { echo "$$s is not below $$C000 (at $$v)"; rm -f $@; exit 1; }; done


Z88ROM_FLAGS = -subtype=app --generic-console -create-app -pragma-include:target/z88/zpragma_rom.inc \
               -Itarget/z88 -DTARGET_Z88 -Ca-DZ88_DI_SIM -Ca-DRODATA_IN_RAM \
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

# The map's pictures baked for 640x200 screens of 3 bits a pixel (the Multi 8 and the PC-8801), and at a quarter of the size for
# the mini maps (4 columns by 3 lines, 5 bytes each: HAVE_MINIMAP_ART).  They are made from the art of one of three games:
#   make TILESET=cpc    the Amstrad CPC game's (assets/cpc_tiles.bin, tools/extract_cpc_tiles.py); the default
#   make TILESET=st     the Atari ST game's (assets/st_tiles.bin, tools/st_tiles_3bpp.py), in the colours ST_COLOURS says
#   make TILESET=amiga  SimCity 512K's (assets/amiga_tiles.bin, tools/st_tiles_3bpp.py), with its 4-bit RGB palette
# Changing TILESET (or ST_COLOURS) makes the pictures again, and so rebuilds the programs that have them.
TILESET ?= cpc
ST_COLOURS ?= meadow
TILES_TOOL = $(if $(filter cpc,$(TILESET)),tools/extract_cpc_tiles.py,tools/st_tiles_3bpp.py)
TILES_ARGS = $(if $(filter st,$(TILESET)),--colours $(ST_COLOURS)) $(if $(filter amiga,$(TILESET)),--palette-bits 4)
TILES_STAMP = build/common/.tiles-$(TILESET)$(if $(filter st,$(TILESET)),-$(ST_COLOURS),)

$(TILES_STAMP):
	@mkdir -p $(@D)
	@rm -f build/common/.tiles-* build/common/*_640x200_3bpp.bin
	@touch $@

build/common/tiles_640x200_3bpp.bin: $(TILES_STAMP) assets/$(TILESET)_tiles.bin $(TILES_TOOL)
	python3 $(TILES_TOOL) assets/$(TILESET)_tiles.bin $(TILES_ARGS) --planes $@

build/common/minitiles_640x200_3bpp.bin: $(TILES_STAMP) assets/$(TILESET)_tiles.bin $(TILES_TOOL)
	python3 $(TILES_TOOL) assets/$(TILESET)_tiles.bin $(TILES_ARGS) --mini $@

# The Mitsubishi Multi 8 in its all-RAM mode: the code in the low 32 KB, the uninitialised data under the video planes.
# The image (code, data and the baked pictures) is loaded as one block from $0000.  The uninitialised data runs on from it
# (CRT_TRIM_BSS: it is not on the tape: its 16 KB of map and mini maps, and the cache of what each cell shows) and must end
# below the doubling table at $F800, which has the stack above it.
MULTI8_TABLE = 0xF800

$(MULTI8): $(DEPS) build/common/tiles_640x200_3bpp.bin
	@mkdir -p $(@D)
	$(ZCC) +multi8 -subtype=64k -create-app $(COMMON) -pragma-include:target/multi8/zpragma.inc \
	    -Itarget/multi8 -DTARGET_MULTI8 -Ca-DTARGET_MULTI8 -Ca-DHAVE_SOUND -Ca-DAY_ADDR_PORT=24 -Ca-DAY_DATA_PORT=25 -Ca-DAY_SCALE $(GAME) $(ENTROPY) $(MENU) target/multi8/plat_sound.asm target/common/ay_hooks.asm target/common/ay_sfx.asm $(FIELDS) $(MMNATIVE) $(LINEEDIT) $(MULTI8_PLATFORM) -o $(@D)/simcity
	@size=`wc -c < $(@D)/simcity.bin`; end=`sed -n 's/^__BSS_END_tail *= \$$\([0-9A-Fa-f]*\).*/\1/p' $(@D)/simcity.map`; \
	    echo "multi8 image: $$size bytes (the uninitialised data ends at $$(printf '%X' $$(( 0x$$end ))), the table is at $$(printf '%X' $$(( $(MULTI8_TABLE) ))))"; \
	    [ $$(( 0x$$end )) -le $$(( $(MULTI8_TABLE) )) ] || { echo "the uninitialised data runs into the doubling table"; rm -f $@; exit 1; }
	@# the placer's variables must be in the low RAM: the planes are paged over $8000-$BFFF while it draws
	@v=`sed -n 's/^mp_flags *= \$$\([0-9A-Fa-f]*\).*/\1/p' $(@D)/simcity.map`; \
	    [ -n "$$v" ] && [ $$(( 0x$$v )) -lt 32768 ] || { echo "the placer's variables are not below $$8000 (mp_flags at $$v)"; rm -f $@; exit 1; }

# The NEC PC-8801 in its all-RAM mode (a bootable disk): code and data from $0000, the stack under the uninitialised data,
# which starts at PC88_BSS and runs over $C000, where the screen is paged in.  It shares the Multi 8's pictures.
PC88_BSS = 0xB600
PC88_CLIB ?=                    # -clib=v1: no ALU, for the original PC-8801 (plane by plane)
PC88_IMAGE_LIMIT = 0xB100       # (the doubling table is at $B100-$B2FF, and the stack gets the rest, down from the uninitialised data)

$(PC88): $(DEPS) build/common/tiles_640x200_3bpp.bin
	@mkdir -p $(@D)
	$(ZCC) +pc88 -subtype=disk $(PC88_CLIB) -create-app $(COMMON) -pragma-include:target/pc88/zpragma.inc \
	    -Itarget/pc88 -DTARGET_PC88 -Ca-DTARGET_PC88 -Ca-D__crt_org_bss=$(PC88_BSS) $(GAME) $(ENTROPY) $(MENU) $(NOSOUND) $(FIELDS) $(MMNATIVE) $(LINEEDIT) $(PC88_PLATFORM) -o $(@D)/simcity.bin
	@size=`wc -c < $(@D)/simcity.bin`; echo "pc88 image: $$size bytes (limit $$(( $(PC88_IMAGE_LIMIT) )))"; \
	    [ $$size -le $$(( $(PC88_IMAGE_LIMIT) )) ] || { echo "the image runs into the stack"; rm -f $@; exit 1; }
	@# the placer's variables must be in the low RAM: the screen is paged over $$C000-$$FFFF while it draws
	@v=`sed -n 's/^mm_src *= \$$\([0-9A-Fa-f]*\).*/\1/p' $(@D)/simcity.map`; \
	    [ -n "$$v" ] && [ $$(( 0x$$v )) -lt 49152 ] || { echo "the placer's variables are not below $$C000 (mm_src at $$v)"; rm -f $@; exit 1; }

# The MGT SAM Coupe in its all RAM mode, screen mode 4 (256x192, 16 colours): the program, its data and its stack in the low 32 KB, the
# uninitialised data in the next 32 KB (which the startup code pages in over $8000-$FFFF), and the baked pictures in the 32 KB after that,
# where the placer pages them in a picture at a time (the screen is paged over the data window to draw).  The disk image is that
# one file, padded to a block boundary, so the loader's pages follow each other.
SAM_TEST =              # (-DSOUND_TEST -Ca-DSOUND_TEST: the build of test/sam/sound_check.py, which calls the sound hooks itself)
SAM_BSS = 0xA200        # the code and the placer's variables are in the low 32 KB; the rest of the image may run on into the high window, and the
                        # uninitialised data starts after it, where the map (in the data) begins in the upper 16 KB page: see the check below

$(SAM): $(DEPS) build/sam/tiles.bin build/sam/anim.inc
	@mkdir -p $(@D)
	$(ZCC) +sam -subtype=allram $(COMMON) -pragma-include:target/sam/zpragma.inc \
	    -Itarget/sam -DTARGET_SAM -Ca-DTARGET_SAM -Ca-D__crt_org_bss=$(SAM_BSS) -Ca-DFMT_WIDTH=32 -Ca-DHAVE_MINIMAP_SQUARE -Ca-DHAVE_SOUND -Ca-DAY_SAA -Ca-DAY_ISR $(SAM_TEST) target/sam/plat_sam_files.asm $(GAME) $(ENTROPY) $(MENU) target/sam/plat_sound.asm target/common/ay_hooks.asm target/common/ay_sfx.asm $(FIELDS) $(MMNATIVE) $(LINEEDIT) $(SAM_PLATFORM_NOFILES) -o $(@D)/simcity.bin
	@size=`wc -c < $(@D)/simcity.bin`; echo "sam image: $$size bytes (the uninitialised data starts at $$(( $(SAM_BSS) )))"; \
	    [ $$size -le $$(( $(SAM_BSS) )) ] || { echo "the image runs into the uninitialised data"; rm -f $@; exit 1; }
	@# the placer's variables must be in the low 32 KB: the screen is paged over the high window while it draws
	@v=`sed -n 's/^mp_pix *= \$$\([0-9A-Fa-f]*\).*/\1/p' $(@D)/simcity.map`; \
	    [ -n "$$v" ] && [ $$(( 0x$$v )) -lt 32768 ] || { echo "the placer's variables are not below $$8000 (mp_pix at $$v)"; rm -f $@; exit 1; }
	python3 -c "import sys; d = open('$(@D)/simcity.bin', 'rb').read(); d += bytes(65536 - len(d)) + open('build/sam/tiles.bin', 'rb').read(); open('$(@D)/simcity.all', 'wb').write(d)"
	z88dk-appmake +mgt -b $(@D)/simcity.all --org 0 --exec --default-dosfile $$ZCCCFG/../target/sam/classic/samdos2.bin -o $@

# The ZX Spectrum Next: Layer 2 (256x192, a byte a pixel), the Atari ST's art in its 16 colours, as the SAM Coupe.  The program is linked at
# $0000 (z88dk's zxn crt with CRT_ORG_CODE 0: target/zxn/zpragma.inc) and the stack and the uninitialised data are at
# ZXN_BSS ($B000); appmake makes the NEX file, with the program in a bank of its own and a loader that maps it (z88dk's zx-util.c).
ZXN_BSS = 0xB000
ZXN_FLAGS =                    # (-DZXN_NO_SCROLL: no scrolling by the DMA; -DZXN_PACE=2: 25 frames a second)
ZXN_ENTROPY = $(ENTROPY)       # (target/zxn/entropy_test.asm: the build test/zxn/run.py runs, which makes the same city each time)
ZXN_ASM = target/zxn/plat_zxn.asm target/zxn/plat_sound.asm target/zxn/zxn_boot.asm target/zxn/zxn_data.asm
ZXN_PLATFORM = target/zxn/plat_zxn.c target/common/minimap_key.c

$(ZXN): $(DEPS) build/zxn/head.bin
	@mkdir -p $(@D)
	$(ZCC) +zxn -clib=classic -lesxdos -subtype=nex -pragma-include:target/zxn/zpragma.inc -pragma-define:CRT_ORG_BSS=$(ZXN_BSS) \
	    -Itarget/zxn -DTARGET_ZXN $(ZXN_FLAGS) -Ca-DTARGET_ZXN -Ca-DFMT_WIDTH=32 -Ca-DHAVE_MINIMAP_SQUARE -Ca-DHAVE_SOUND -Ca-DAY_ISR -Ca-DAY_PORT16 -Ca-DAY_SCALE -Ca-DAY_DOWN -Ca-DAY_ADDR_PORT=65533 -Ca-DAY_DATA_PORT=49149 $(COMMON) \
	    $(GAME) $(ZXN_ENTROPY) $(MENU) target/common/ay_hooks.asm target/common/ay_sfx.asm $(FIELDS) $(MMNATIVE) $(LINEEDIT) $(ZXN_ASM) $(ZXN_PLATFORM) -create-app -o $(@D)/simcity.bin
	@# the program is below the stack and the data
	@size=`wc -c < $(@D)/simcity.bin`; echo "zxn image: $$size bytes (the stack and the data start at $$(( $(ZXN_BSS) )))"; \
	    [ $$size -le $$(( $(ZXN_BSS) )) ] || { echo "the image runs into the stack and the data"; rm -f $@; exit 1; }

# The map's art: the Amiga SimCity 1 Meg's (assets/amiga_1meg_tiles.bin, tools/extract_amiga_1meg_tiles.py: 64 colours); ZXN_TILES=assets/amiga_tiles.bin makes it
# the 512K version's, assets/st_tiles.bin the Atari ST's.  The interface (text, charts, mini maps) is in the ST's colours either way.
# The tool icons: the 1 Meg Amiga's (assets/amiga_1meg_icons.bin, tools/extract_amiga_1meg_icons.py); ZXN_ICONS=assets/amiga_icons.bin makes them the 512K's.
ZXN_TILES ?= assets/amiga_1meg_tiles.bin
ZXN_ICONS ?= assets/amiga_1meg_icons.bin
build/zxn/head.bin: $(ZXN_TILES) $(ZXN_ICONS) tools/st_tiles_3bpp.py
	@mkdir -p $(@D)
	python3 tools/st_tiles_3bpp.py $(ZXN_TILES) --amiga-icons $(ZXN_ICONS) --zxn $(@D)

build/sam/tiles.bin build/sam/anim.inc: assets/st_tiles.bin assets/st_icons.bin tools/st_tiles_3bpp.py
	@mkdir -p $(@D)
	python3 tools/st_tiles_3bpp.py assets/st_tiles.bin --icons assets/st_icons.bin --sam build/sam/tiles.bin --sam-anim build/sam/anim.inc

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

deadcode: $(TEST)
	python3 tools/find_dead.py

clean:
	rm -rf build
