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

VERSION ?= 1.3.0

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
AQPLUS_PLATFORM = target/aqplus/plat_aqplus.c target/aqplus/plat_aqplus.asm target/aqplus/aq_mouse.c target/aqplus/aq_mouse.asm target/aqplus/aq_files.asm target/common/pointer.c
ZX_PLATFORM = target/zx/plat_zx.asm
MULTI8_PLATFORM = target/multi8/plat_multi8.c target/multi8/plat_multi8.asm target/common/plat_charts.c target/common/minimap_key_3bpp.c target/common/plat_icons.c
PC88_PLATFORM = target/pc88/plat_pc88.c target/pc88/plat_pc88.asm target/pc88/plat_pc88_files.asm target/common/plat_charts.c target/common/minimap_key_3bpp.c target/common/plat_icons.c
SAM_PLATFORM_NOFILES = target/sam/plat_sam.c target/sam/plat_sam.asm target/sam/sam_mouse.asm target/common/pointer.c target/common/minimap_key.c
Z88_PLATFORM = target/z88/plat_z88.c target/z88/plat_z88.asm target/z88/fgets_cons.asm


# Everything a build depends on.
DEPS = Makefile $(wildcard ui/*.c ui/*.h ui/*.asm engine/*.asm engine/*.inc engine/*.h platform/common/*.asm \
         platform/console/*.[chai]* target/*/*.[chai]* target/*/*.inc) assets/map_art.bin assets/map_art_aq.bin assets/map_art_mk2.bin assets/icons_mk2.bin assets/udgs.bin assets/icons.bin assets/icons_spec.bin assets/cpc_icons.bin assets/st_sounds.bin

AQPLUS = build/aqplus/simcity.aqx
NC200  = build/nc200/simcity.img
Z88ROM = build/z88rom/simcity.epr
ZX     = build/zx/simcity.tap
MULTI8 = build/multi8/simcity.cas
PC88   = build/pc88/simcity.d88
X1     = build/x1/simcity.d88
SPC1000 = build/spc1000/simcity.spc
SPC1500 = build/spc1500/simcity.tap
MSX2   = build/msx2/simcity.img
EINSTEIN256 = build/einstein256/simcity.com
CPM = build/cpm/simcity.com
PCW = build/pcw/simcity.com
FP1100 = build/fp1100/simcity.d88
MZ2500 = build/mz2500/simcity.dsk
SMC777 = build/smc777/simcity.d88
MZ800 = build/mz800/simcity.d88
PASOPIA7 = build/pasopia7/simcity.dsk
PC6001MK2 = build/pc6001mk2/simcity.d88
LYNXDISC = build/lynx/simcity.ldf
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

.PHONY: mk2demo all dist aqplus z88rom zx multi8 pc88 x1 spc1000 spc1500 msx2 einstein256 cpm pcw fp1100 mz2500 mz800 smc777 lynx pasopia7 pc6001mk2 sam zxn zxn-debug amiga-scenarios test testpanel testmodal testnarrow testsprites testoverlay testhires testnative testart testscroll check golden uitest tiletest z88test deadcode clean

all: aqplus z88rom zx multi8 pc88 pc6001mk2 x1 spc1000 spc1500 msx2 einstein256 pcw fp1100 mz2500 mz800 smc777 lynx pasopia7 sam zxn

# The zip files for distribution, one for each machine (build/dist/; tools/make_dist.py)
dist: aqplus z88rom multi8 pc88 pc6001mk2 x1 spc1000 spc1500 msx2 einstein256 pcw fp1100 mz2500 mz800 smc777 lynx pasopia7 sam zxn
	python3 tools/make_dist.py

aqplus: $(AQPLUS)
z88rom: $(Z88ROM)
zx:     $(ZX)
multi8: $(MULTI8)
pc88:   $(PC88)
x1:     $(X1)
spc1000: $(SPC1000)
spc1500: $(SPC1500)
msx2:   $(MSX2)
einstein256: $(EINSTEIN256)
cpm: $(CPM)
pcw: $(PCW)
fp1100: $(FP1100)
mz2500: $(MZ2500)
smc777: $(SMC777)
mz800: $(MZ800)
pasopia7: $(PASOPIA7)
pc6001mk2: $(PC6001MK2)
lynx:   $(LYNXDISC)
sam:    $(SAM)
zxn:   $(ZXN)
zxn-debug:
	tools/zxn_debug.sh
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
	    -Itarget/aqplus -DTARGET_AQPLUS -Ca-DTARGET_AQPLUS -Ca-DSIM_STACK_TOP=0x0c00 -Ca-DHAVE_MINIMAP_SQUARE -Ca-DHAVE_SOUND -Ca-DAY_SCALE $(GAME) $(ENTROPY) $(MENU) target/aqplus/plat_sound.asm target/common/ay_hooks.asm target/common/ay_sfx.asm $(FIELDS) $(MMNATIVE) $(AQPLUS_PLATFORM) -o $(@D)/simcity.bin
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
	    -Itarget/multi8 -DTARGET_MULTI8 -Ca-DTARGET_MULTI8 -Ca-DHAVE_MINIMAP_SQUARE -Ca-DHAVE_SOUND -Ca-DAY_ADDR_PORT=24 -Ca-DAY_DATA_PORT=25 -Ca-DAY_SCALE $(GAME) $(ENTROPY) $(MENU) target/multi8/plat_sound.asm target/common/ay_hooks.asm target/common/ay_sfx.asm $(FIELDS) $(MMNATIVE) $(LINEEDIT) $(MULTI8_PLATFORM) -o $(@D)/simcity
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
	    -Itarget/pc88 -DTARGET_PC88 -Ca-DTARGET_PC88 -Ca-DHAVE_MINIMAP_SQUARE -Ca-D__crt_org_bss=$(PC88_BSS) $(GAME) $(ENTROPY) $(MENU) $(NOSOUND) $(FIELDS) $(MMNATIVE) $(LINEEDIT) $(PC88_PLATFORM) -o $(@D)/simcity.bin
	@size=`wc -c < $(@D)/simcity.bin`; echo "pc88 image: $$size bytes (limit $$(( $(PC88_IMAGE_LIMIT) )))"; \
	    [ $$size -le $$(( $(PC88_IMAGE_LIMIT) )) ] || { echo "the image runs into the stack"; rm -f $@; exit 1; }
	@# the placer's variables must be in the low RAM: the screen is paged over $$C000-$$FFFF while it draws
	@v=`sed -n 's/^mm_src *= \$$\([0-9A-Fa-f]*\).*/\1/p' $(@D)/simcity.map`; \
	    [ -n "$$v" ] && [ $$(( 0x$$v )) -lt 49152 ] || { echo "the placer's variables are not below $$C000 (mm_src at $$v)"; rm -f $@; exit 1; }

# The Sharp X1 (z88dk +x1, startup 1: all RAM, the program at $0000 on a bootable 2D disk).  Its 40 column mode is a 320x200 screen of three
# planes behind I/O ports: a cell is a byte wide, so the PC-8801's baked pictures serve undoubled.  The uninitialised data follows the
# image and the stack is at the top of memory.
X1_PLATFORM = target/x1/plat_x1.asm target/x1/plat_x1_files.asm target/common/plat_charts.c target/common/minimap_key_3bpp.c target/common/plat_icons.c

$(X1): $(DEPS) build/common/tiles_640x200_3bpp.bin
	@mkdir -p $(@D)
	$(ZCC) +x1 -create-app $(COMMON) -pragma-include:target/x1/zpragma.inc \
	    -Itarget/x1 -DTARGET_X1 -Ca-DTARGET_X1 -Ca-DHAVE_MINIMAP_SQUARE -Ca-DHAVE_SOUND -Ca-DAY_PORT16 -Ca-DAY_ADDR_PORT=0x1C00 -Ca-DAY_DATA_PORT=0x1B00 $(GAME) $(ENTROPY) $(MENU) target/x1/plat_sound.asm target/common/ay_hooks.asm target/common/ay_sfx.asm $(FIELDS) $(MMNATIVE) $(LINEEDIT) $(X1_PLATFORM) -o $(@D)/simcity.bin
	@size=`sed -n 's/^__BSS_END_tail *= \$$\([0-9A-Fa-f]*\).*/\1/p' $(@D)/simcity.map`; echo "x1: image and uninitialised data end at $$size (the stack is the top of memory)"

# The Samsung SPC-1500 (z88dk +spc1500: a cassette for the IPL's "C: cassette system", a 128 byte bootstrap that unpacks the ZX0 packed program at $0000).  Its video is the X1's (a
# 40 column mode of three planes behind I/O ports, 320x200), so the X1's pictures and drawing code serve.  The uninitialised data follows the image and the stack is the top of memory.
SPC1500_PLATFORM = target/spc1500/plat_spc1500.asm target/spc1500/plat_files.asm target/spc1500/plat_files.c target/common/plat_charts.c target/common/minimap_key_3bpp.c target/common/plat_icons.c

$(SPC1500): $(DEPS) build/common/tiles_640x200_3bpp.bin target/spc1500/keytab.inc
	@mkdir -p $(@D)
	$(ZCC) +spc1500 -create-app $(COMMON) -pragma-include:target/spc1500/zpragma.inc \
	    -Itarget/spc1500 -DTARGET_SPC1500 -Ca-DTARGET_SPC1500 -Ca-I. -Ca-DHAVE_MINIMAP_SQUARE -Ca-DHAVE_SOUND -Ca-DAY_PORT16 -Ca-DAY_ADDR_PORT=0x1C00 -Ca-DAY_DATA_PORT=0x1B00 $(GAME) $(ENTROPY) $(MENU) target/spc1500/plat_sound.asm target/common/ay_hooks.asm target/common/ay_sfx.asm $(FIELDS) $(MMNATIVE) $(LINEEDIT) $(SPC1500_PLATFORM) -o $(@D)/simcity.bin
	@size=`sed -n 's/^__BSS_END_tail *= \$$\([0-9A-Fa-f]*\).*/\1/p' $(@D)/simcity.map`; echo "spc1500: image and uninitialised data end at $$size (the stack is the top of memory)"

# The Sony SMC-777 (z88dk +smc777: a boot disc, the IPL loads the program at $0100).  A 320x200 screen of a nibble a pixel behind I/O ports (8 digital colours used), the
# Amstrad CPC game's pictures as nibbles (tools/smc777_tiles.py), the screen 40 columns of 8x8 cells like the X1's.  The uninitialised data follows the image and the stack is
# at the top of memory.  The font and the tool icons live in the character generator's RAM (read with IN) and their room in the image is the cache of the map's cells.
SMC777_FILES ?= 1               # 0: without save and load (about 2 KB less)
SMC777_STACK_ROOM = 0x0240      # (the deepest the stack has gone in a game with the save dialogues is 320 bytes)
SMC777_PLATFORM = target/smc777/plat_smc777.asm $(if $(filter 1,$(SMC777_FILES)),target/smc777/plat_smc777_files.asm) target/common/plat_charts.c target/common/minimap_key_3bpp.c target/common/plat_icons.c

build/smc777/tiles4.bin: build/common/tiles_640x200_3bpp.bin tools/smc777_tiles.py
	@mkdir -p $(@D)
	python3 tools/smc777_tiles.py $< $@

$(SMC777): $(DEPS) build/smc777/tiles4.bin assets/font_8x8_bbc_system.bin assets/cpc_icons.bin
	@mkdir -p $(@D)
	$(ZCC) +smc777 -create-app $(COMMON) -pragma-include:target/smc777/zpragma.inc \
	    -Itarget/smc777 -DTARGET_SMC777 -Ca-DTARGET_SMC777 $(if $(filter 1,$(SMC777_FILES)),,-DNO_FILES -Ca-DNO_FILES) -Ca-DSIM_YIELD_EXTRA -Ca-DHAVE_MINIMAP_SQUARE $(GAME) $(ENTROPY) $(MENU) $(NOSOUND) $(FIELDS) $(MMNATIVE) $(LINEEDIT) $(SMC777_PLATFORM) -o $(@D)/simcity.bin
	@size=`sed -n 's/^__BSS_END_tail *= \$$\([0-9A-Fa-f]*\).*/\1/p' $(@D)/simcity.map`; echo "smc777: image and uninitialised data end at $$size (the stack is the top of memory)"; \
	    [ $$(( 0x$$size + $(SMC777_STACK_ROOM) )) -le 65536 ] || { echo "the program and its data leave no room for the stack"; rm -f $@; exit 1; }

# The Camputers Lynx 128K (z88dk +lynx -subtype=allram: a boot disc, the program at $0100 in the user RAM and the art after it on the disc).  Three planes of 512x252 behind a
# window the user RAM's writes are switched off for (target/lynx/plat_lynx.asm), the CPC art with every pixel doubled across, 32 columns of 8x8 cells.  The doubling tables
# are at $F800 and the stack is the top of memory: the uninitialised data must end below the tables.
LYNX_PLATFORM = target/lynx/plat_sound.asm target/common/ay_sfx.asm target/lynx/plat_lynx.asm target/lynx/plat_lynx_files.asm target/lynx/lynx_lsec.asm target/common/plat_charts.c target/common/minimap_key_3bpp.c target/common/plat_icons.c
LYNX_TABLES = 0xF800

build/lynx/art.bin: build/common/tiles_640x200_3bpp.bin assets/font_8x8_bbc_system.bin assets/cpc_icons.bin tools/lynx_art.py
	@mkdir -p $(@D)
	python3 tools/lynx_art.py build/common/tiles_640x200_3bpp.bin assets/font_8x8_bbc_system.bin assets/cpc_icons.bin $@

$(LYNXDISC): $(DEPS) build/lynx/art.bin
	@mkdir -p $(@D)
	$(ZCC) +lynx -subtype=allram -create-app $(COMMON) -pragma-include:target/lynx/zpragma.inc -Itarget/lynx -DTARGET_LYNX -Ca-DTARGET_LYNX -Ca-DFMT_WIDTH=32 -Ca-DHAVE_MINIMAP_SQUARE -Ca-DHAVE_SOUND -Ca-DAY_SHADOW \
	    $(GAME) $(ENTROPY) $(MENU) $(FIELDS) $(MMNATIVE) $(LINEEDIT) $(LYNX_PLATFORM) -o $(@D)/simcity.bin -Cz"--data build/lynx/art.bin"
	@tail=`sed -n 's/^__BSS_END_tail *= \$$\([0-9A-Fa-f]*\).*/\1/p' $(@D)/simcity.map`; echo "lynx: the program and its uninitialised data end at $$tail (the tables are at $(LYNX_TABLES))"; \
	    [ $$(( 0x$$tail )) -le $$(( $(LYNX_TABLES) )) ] || { echo "the uninitialised data runs into the doubling tables"; rm -f $@; exit 1; }

# The Toshiba Pasopia 7 (z88dk +pasopia7: a boot disc, the program at $0000 in all RAM).  The screen is 320x200 in 8 colours as 40x25 cells of three planes of 8 bytes, reached
# through a window over $8000-$BFFF; the art is kept in the video RAM beyond what the screen shows (tools/pasopia7_art.py).  The uninitialised data is above the window ($A000
# for now: the image holds the art until the disc loads it) and the stack is the top of memory.
PASOPIA7_FILES ?= 1             # 0: without save and load
PASOPIA7_BSS = 0x9000
PASOPIA7_SLOT0 = 23             # the first track of the save slots (plat_pasopia7_files.asm: SLOT_TRACK0): the program and its art must end below it
PASOPIA7_TOP = 0xFA00           # the uninitialised data must end below this: the stack is under $FF00
PASOPIA7_PLATFORM = target/pasopia7/plat_time.asm target/pasopia7/plat_sound.asm target/common/ay_hooks.asm target/common/ay_sfx.asm target/pasopia7/plat_pasopia7.asm $(if $(filter 1,$(PASOPIA7_FILES)),target/pasopia7/plat_pasopia7_files.asm) target/common/plat_charts.c target/common/minimap_key_3bpp.c target/common/plat_icons.c

build/pasopia7/art.bin: build/common/tiles_640x200_3bpp.bin assets/font_8x8_bbc_system.bin assets/cpc_icons.bin tools/pasopia7_art.py
	@mkdir -p $(@D)
	python3 tools/pasopia7_art.py build/common/tiles_640x200_3bpp.bin assets/font_8x8_bbc_system.bin assets/cpc_icons.bin $@

$(PASOPIA7): $(DEPS) build/pasopia7/art.bin
	@mkdir -p $(@D)
	$(ZCC) +pasopia7 -create-app $(COMMON) -pragma-include:target/pasopia7/zpragma.inc -pragma-define:CRT_ORG_BSS=$(PASOPIA7_BSS) -Itarget/pasopia7 -DTARGET_PASOPIA7 -Ca-DTARGET_PASOPIA7 \
	    $(if $(filter 1,$(PASOPIA7_FILES)),,-DNO_FILES -Ca-DNO_FILES) -Ca-DSIM_YIELD_EXTRA -Ca-DHAVE_MINIMAP_SQUARE -Ca-DHAVE_SOUND -Ca-DAY_SHADOW -Ca-DAY_SHADOW_TICK \
	    $(GAME) $(ENTROPY) $(MENU) $(FIELDS) $(MMNATIVE) $(LINEEDIT) $(PASOPIA7_PLATFORM) -o $(@D)/simcity -Cz"--data build/pasopia7/art.bin"
	@tail=`sed -n 's/^__BSS_END_tail *= \$$\([0-9A-Fa-f]*\).*/\1/p' $(@D)/simcity.map`; echo "pasopia7: the program and its uninitialised data end at $$tail (the stack is under $$FF00)"; \
	    [ $$(( 0x$$tail )) -le $$(( $(PASOPIA7_TOP) )) ] || { echo "the uninitialised data runs into the stack"; rm -f $@; exit 1; }
	@dtail=`sed -n 's/^__DATA_END_tail *= \$$\([0-9A-Fa-f]*\).*/\1/p' $(@D)/simcity.map`; \
	    [ $$(( 0x$$dtail )) -le $$(( $(PASOPIA7_BSS) )) ] || { echo "the program ends at $$dtail, past where the uninitialised data starts ($(PASOPIA7_BSS)): raise PASOPIA7_BSS"; rm -f $@; exit 1; }; \
	    [ $$(( 2 + (0x$$dtail + 2047) / 2048 + 3 )) -le $(PASOPIA7_SLOT0) ] || { echo "the program and the art run into the save slots (track $(PASOPIA7_SLOT0): target/pasopia7/plat_pasopia7_files.asm)"; rm -f $@; exit 1; }

# The NEC PC-6001mkII on a boot disc (PC-6031 drive, D88 image), by z88dk's +pc6001 -subtype=mk2disc: the program is a flat RAM image at $0000 with the ROM mapped out, loaded by the
# boot sector the crt carries; the overlays (the sections OVERLAY_0 to OVERLAY_4, one window: target/pc6001mk2/mmap.inc) follow it on the disc and pc6001mk2_overlay_load reads them.
# The program, its data and the uninitialised data are below $C000, where the 16K VRAM goes.
PC6001MK2_WINDOW = 0xB0F0       # the overlay window (target/pc6001mk2/mmap.inc): above the uninitialised data ...
PC6001MK2_TOP = 0xBE00          # ... and ending below this: the stack grows down from $C000
PC6001MK2_PLATFORM = target/pc6001mk2/plat_pc6001mk2.c target/pc6001mk2/plat_pc6001mk2.asm target/pc6001mk2/plat_irq.asm target/pc6001mk2/plat_sound.asm target/pc6001mk2/plat_minimap.asm target/pc6001mk2/plat_sprite.asm target/pc6001mk2/plat_minimap.c target/pc6001mk2/plat_files.c target/pc6001mk2/plat_text.c target/pc6001mk2/eval_ui.c target/pc6001mk2/file_ui.c
$(PC6001MK2): $(DEPS) target/pc6001mk2/mmap.inc
	@mkdir -p $(@D)
	$(ZCC) +pc6001 -subtype=mk2disc -create-app $(COMMON) -pragma-include:target/pc6001mk2/zpragma.inc -pragma-define:MMAP=-1 -pragma-define:CRT_PC6001MK2_OVERLAYS=5 -Itarget/pc6001mk2 -Ca-Itarget/pc6001mk2 \
	    -DTARGET_PC6001MK2 -Ca-DTARGET_PC6001MK2 -Ca-DHAVE_MINIMAP_SQUARE -Ca-DFMT_WIDTH=40 $(filter-out ui/prompt.c ui/cityfile.c ui/evaluation.c,$(GAME)) $(ENTROPY) $(MENU) $(FIELDS) $(MMNATIVE) $(PC6001MK2_PLATFORM) -o $(@D)/simcity
	@dtail=`sed -n 's/^__DATA_END_tail *= \$$\([0-9A-Fa-f]*\).*/\1/p' $(@D)/simcity.map`; tail=`sed -n 's/^__BSS_END_tail *= \$$\([0-9A-Fa-f]*\).*/\1/p' $(@D)/simcity.map`; \
	    g=`wc -c < $(@D)/simcity_OVERLAY_0.bin`; mo=`wc -c < $(@D)/simcity_OVERLAY_1.bin`; fo=`wc -c < $(@D)/simcity_OVERLAY_2.bin`; so=`wc -c < $(@D)/simcity_OVERLAY_3.bin`; eo=`wc -c < $(@D)/simcity_OVERLAY_4.bin`; big=$$(( g > mo ? g : mo )); big=$$(( big > fo ? big : fo )); big=$$(( big > so ? big : so )); big=$$(( big > eo ? big : eo )); \
	    echo "pc6001mk2: the program and its data end at $$dtail, the uninitialised data at $$tail, the overlays are $$g (game), $$mo (modal), $$fo (file), $$so (start-up) and $$eo (evaluation) bytes in the window at $(PC6001MK2_WINDOW) (the stack is under \$$C000)"; \
	    [ $$(( 0x$$tail )) -le $$(( $(PC6001MK2_WINDOW) )) ] || { echo "the uninitialised data runs into the overlay window: raise PC6001MK2_WINDOW here and in target/pc6001mk2/mmap.inc"; rm -f $@; exit 1; }; \
	    [ $$(( $(PC6001MK2_WINDOW) + big )) -le $$(( $(PC6001MK2_TOP) )) ] || { echo "the overlay window runs into the stack"; rm -f $@; exit 1; }

# The Sharp MZ-800 (z88dk +mz800: a boot disc, the IPL reads the program to $1200 and moves it to $2000).  The 320x200 screen of two bit planes (the art of the PC-6001mkII), the video RAM
# paged in at $8000-$9FFF only while something is drawn: the drawing code (section code_driver: the platform's asm) must end below $8000 (checked); the sound is the SN76489 (target/mz800/plat_sound.asm).
MZ800_SLOT_BASE = 256           # the first logical sector of the save slots (target/mz800/plat_files.c: SLOT_BASE): the program (and the header sector) must end before it
MZ800_TOP = 0xFC00              # the uninitialised data must end below this: the stack (1 KB; the other 8 bit targets' deepest was 320-570 bytes) is the top of memory
MZ800_PLATFORM = target/mz800/plat_sound.asm target/common/ay_hooks.asm target/common/ay_sfx.asm target/mz800/plat_mz800.c target/mz800/plat_mz800.asm target/mz800/plat_input.asm target/mz800/plat_minimap.asm target/mz800/plat_sprite.asm target/mz800/plat_minimap.c target/mz800/plat_text.c target/mz800/plat_files.c
$(MZ800): $(DEPS)
	@mkdir -p $(@D)
	$(ZCC) +mz800 -create-app $(COMMON) -pragma-include:target/mz800/zpragma.inc -Itarget/mz800 -Ca-Itarget/mz800 \
	    -DTARGET_MZ800 -Ca-DTARGET_MZ800 -Ca-DHAVE_MINIMAP_SQUARE -Ca-DFMT_WIDTH=40 -Ca-DHAVE_SOUND -Ca-DAY_SHADOW -Ca-DAY_SHADOW_TICK $(GAME) $(ENTROPY) $(MENU) $(FIELDS) $(MMNATIVE) $(MZ800_PLATFORM) -o $(@D)/simcity
	@dtail=`sed -n 's/^__DATA_END_tail *= \$$\([0-9A-Fa-f]*\).*/\1/p' $(@D)/simcity.map`; tail=`sed -n 's/^__BSS_END_tail *= \$$\([0-9A-Fa-f]*\).*/\1/p' $(@D)/simcity.map`; \
	    echo "mz800: the program and its data end at $$dtail, the uninitialised data at $$tail (the stack is the top of memory)"; \
	    ctail=`sed -n 's/^__code_driver_tail *= \$$\([0-9A-Fa-f]*\).*/\1/p' $(@D)/simcity.map`; \
	    [ $$(( 0x$$ctail )) -le 32768 ] || { echo "the drawing code (section code_driver) ends at $$ctail, past the video RAM window at $$8000"; rm -f $@; exit 1; }; \
	    [ $$(( 0x$$tail )) -le $$(( $(MZ800_TOP) )) ] || { echo "the uninitialised data runs into the stack"; rm -f $@; exit 1; }; \
	    [ $$(( 1 + ( 0x$$dtail - 0x2000 + 255 ) / 256 )) -le $(MZ800_SLOT_BASE) ] || { echo "the program runs into the save slots (logical sector $(MZ800_SLOT_BASE): target/mz800/plat_files.c)"; rm -f $@; exit 1; }

# A cartridge to try z88dk's PC-6001mkII 320x200 console and graphics (test/pc6001mk2/cart_demo.c): the ROM subtype with -clib=mk2, padded to 16 KB.  In MAME: mame pc6001mk2 -cart1 build/pc6001mk2/mk2demo.rom
MK2DEMO = build/pc6001mk2/mk2demo.rom
mk2demo: $(MK2DEMO)
$(MK2DEMO): test/pc6001mk2/cart_demo.c
	@mkdir -p build/pc6001mk2/demo
	cd build/pc6001mk2/demo && $(ZCC) +pc6001 -subtype=rom -clib=mk2 -create-app ../../../test/pc6001mk2/cart_demo.c -o cart_demo
	python3 -c "d = open('build/pc6001mk2/demo/cart_demo.bin', 'rb').read(); open('$@', 'wb').write(d.ljust(16384, b'\\xff'))"
	@ls -l $@

# The Samsung SPC-1000 (z88dk +spc1000 -subtype=allram: BASIC loads a ZX0 packed program with a bootstrap that unpacks it at $0000 and takes the machine).
# The screen is the MC6847's 256x192 mode of one bit a pixel behind I/O ports, so the pictures are the engine's own 1 bit art and the icons the
# Spectrum's (the first 448 bytes of assets/udgs.bin), with no colour.  The uninitialised data follows the image and the stack is at the top of memory.
SPC1000_STACK_ROOM = 0x0800     # (the stack gets what is above the uninitialised data: at least this much)
SPC1000_PLATFORM = target/spc1000/plat_spc1000.asm target/spc1000/plat_spc1000.c target/spc1000/plat_sound.asm

build/spc1000/icons.bin: assets/udgs.bin
	@mkdir -p $(@D)
	head -c 448 $< > $@

$(SPC1000): $(DEPS) build/spc1000/icons.bin
	@mkdir -p $(@D)
	$(ZCC) +spc1000 -subtype=allram -create-app $(COMMON) -pragma-include:target/spc1000/zpragma.inc \
	    -Itarget/spc1000 -DTARGET_SPC1000 -Ca-DTARGET_SPC1000 -Ca-DFMT_WIDTH=32 -Ca-DHAVE_MINIMAP_SQUARE -Ca-DHAVE_SOUND -Ca-DAY_ISR -Ca-DAY_PORT16 -Ca-DAY_ADDR_PORT=0x4000 -Ca-DAY_DATA_PORT=0x4001 \
	    $(GAME) $(ENTROPY) $(MENU) target/common/ay_hooks.asm target/common/ay_sfx.asm $(FIELDS) $(MMNATIVE) $(LINEEDIT) $(SPC1000_PLATFORM) -o $(@D)/simcity.bin
	@tail=`sed -n 's/^__BSS_END_tail *= \$$\([0-9A-Fa-f]*\).*/\1/p' $(@D)/simcity.map`; echo "spc1000: the program and its uninitialised data end at $$(printf '%04X' $$(( 0x$$tail )))"; \
	    [ $$(( 0x$$tail + $(SPC1000_STACK_ROOM) )) -le 65536 ] || { echo "the uninitialised data leaves no room for the stack"; rm -f $@; exit 1; }

# The MSX2 under MSX-DOS 2 (z88dk +msx -subtype=msxdos2: a .COM at $0100, with the picture atlas beside it).  Screen 5 (256x192, 16 colours), the Atari ST's art as the SAM
# Coupe's: the atlas (TILES.DAT) is loaded into the video RAM and the VDP copies the map's tiles out of it (target/common/v9938/plat_v9938.asm).
# The code is in two 16 KB mapper segments, loaded from SIMCITY.UI and SIMCITY.SIM and mapped into page 2 ($8000-$BFFF) by turns (target/msx2/engine_bank.inc, msx_bank.asm): the
# UI's C code (zcc --codeseg BANK_UI) and the simulation's.  What is resident is below $8000 (the glue, the sound, the tables, all the data): the stack is in page 3.
# A picture for every growth level of a zone (the engine's FINE_ZONE_LEVELS: the CPC game's 471 pictures)
MSX2_FINE_FLAGS = -DFINE_ZONE_LEVELS -Ca-DFINE_ZONE_LEVELS
# (MSX2_SOUND=0 leaves the PSG out)
MSX2_SOUND ?= 1
ifeq ($(MSX2_SOUND),1)
MSX2_SOUND_FILES = target/msx2/plat_sound.asm target/common/ay_hooks.asm target/common/ay_sfx.asm
MSX2_SOUND_FLAGS = -Ca-DHAVE_SOUND -Ca-DAY_ISR -Ca-DAY_CODE_HI -Ca-DAY_MSX -Ca-DAY_SCALE -Ca-DAY_DOWN -Ca-DAY_ADDR_PORT=0xA0 -Ca-DAY_DATA_PORT=0xA1
else
MSX2_SOUND_FILES = $(NOSOUND)
MSX2_SOUND_FLAGS = -DMSX2_NO_SOUND
endif
MSX2_GAME = $(filter-out ui/main.c,$(GAME))         # (main() is in msx_bank.asm)
MSX2_PLATFORM = target/msx2/msx_banks.asm target/msx2/msx_bank.asm target/common/minimap_key.c target/msx2/pointer_res.c target/msx2/msx_pointer.c target/msx2/plat_msx2.c target/msx2/msx_io.asm target/common/v9938/plat_v9938.c target/common/v9938/plat_v9938.asm target/common/v9938/v9938_data.asm $(MSX2_SOUND_FILES)

# The picture atlas and tables the V9938 targets (the MSX2 and the Einstein 256) share: the Atari ST's art in the CPC game's numbering (tools/st_tiles_3bpp.py --v9938)
V9938_ASSETS = build/v9938/TILES.DAT build/v9938/v9938.inc build/v9938/v9938.h
$(V9938_ASSETS): assets/st_tiles.bin assets/st_icons.bin tools/st_tiles_3bpp.py
	@mkdir -p $(@D)
	python3 tools/st_tiles_3bpp.py assets/st_tiles.bin --icons assets/st_icons.bin --numbering cpc --v9938 $(@D)

$(MSX2): $(DEPS) $(V9938_ASSETS)
	@mkdir -p $(@D)
	$(ZCC) +msx -subtype=msxdos2 -lmsx2 -lmsxbios $(COMMON) -pragma-include:target/msx2/zpragma.inc --codeseg BANK_UI \
	    -Itarget/msx2 -Ibuild/v9938 -Ca-Itarget/msx2 -Ca-Ibuild/v9938 -DTARGET_MSX2 -Ca-DTARGET_MSX2 -Ca-DENGINE_BANK $(MSX2_FINE_FLAGS) -Ca-DFMT_WIDTH=32 -Ca-DHAVE_MINIMAP_SQUARE \
	    $(MSX2_SOUND_FLAGS) \
	    $(MSX2_PLATFORM) $(MSX2_GAME) $(ENTROPY) $(MENU) $(FIELDS) $(MMNATIVE) $(LINEEDIT) -create-app -Cz"-a build/v9938/TILES.DAT:TILES.DAT" -Cz"-a build/msx2/simcity_BANK_UI.bin:SIMCITY.UI" -Cz"-a build/msx2/simcity_BANK_SIM.bin:SIMCITY.SIM" -Cz"-a build/msx2/simcity_CODE_HI.bin:SIMCITY.HI" -o $(@D)/simcity
	@# a directory with the files, for an emulator that mounts one as a drive (openMSX's diskX with a directory)
	@mkdir -p $(@D)/disk && cp $(@D)/simcity $(@D)/disk/SIMCITY.COM && cp build/v9938/TILES.DAT $(@D)/disk/TILES.DAT && cp $(@D)/simcity_BANK_UI.bin $(@D)/disk/SIMCITY.UI && cp $(@D)/simcity_BANK_SIM.bin $(@D)/disk/SIMCITY.SIM && cp $(@D)/simcity_CODE_HI.bin $(@D)/disk/SIMCITY.HI
	@cp $@ $(@:.img=.dsk)
	@tail=`sed -n 's/^__BSS_END_tail *= \$$\([0-9A-Fa-f]*\).*/\1/p' $(@D)/simcity.map`; ui=`wc -c < $(@D)/simcity_BANK_UI.bin`; sim=`wc -c < $(@D)/simcity_BANK_SIM.bin`; hi=`wc -c < $(@D)/simcity_CODE_HI.bin`; \
	    echo "msx2: the resident program and its uninitialised data end at $$(printf '%04X' $$(( 0x$$tail ))); the UI's bank is $$ui bytes, the simulation's $$sim of 16384, and the code in page 3 $$hi (up to 4096)"; \
	    [ $$(( 0x$$tail )) -le $$(( 0x8000 )) ] && [ $$ui -le 16384 ] && [ $$sim -le 16384 ] && [ $$hi -le 4096 ] || { echo "the resident part must end below \$$8000, each bank fit 16 KB and the code in page 3 4 KB (the stack is under the DOS entry)"; rm -f $@; exit 1; }

# The Tatung Einstein 256: CP/M, V9938 screen 5 and the V9938 drawing core it shares with the MSX2 (target/common/v9938).
# One CP/M COM in the standard classic map (under 32 KB: the DOS will not load a bigger one); the two UI overlays are separate files that the start-up reads into
# a window above the BSS and keeps in the unused part of the screen page's VRAM, and copies back as needed.  See docs/EINSTEIN256-layout.md.
EINSTEIN256_PLATFORM = target/einstein256/einstein_boot.asm target/einstein256/einstein_io.asm target/einstein256/einstein_loader.c target/einstein256/einstein_dos.c target/einstein256/plat_einstein256.c target/common/minimap_key.c target/common/v9938/plat_v9938.c target/common/v9938/plat_v9938.asm target/common/v9938/v9938_data.asm target/einstein256/plat_sound.asm target/common/ay_hooks.asm target/common/ay_sfx.asm
EINSTEIN256_GAME = $(filter-out ui/main.c,$(GAME))
EINSTEIN256_TPA_TOP = E000          # the BDOS entry (the word at address 6) on the machine; the check script uses it

$(EINSTEIN256): $(DEPS) tools/check_einstein_layout.py target/einstein256/mmap.inc $(V9938_ASSETS)
	@mkdir -p $(@D)
	$(ZCC) +cpm -subtype=einstein256 $(COMMON) -pragma-include:target/einstein256/zpragma.inc -pragma-define:MMAP=-1 \
	    -Itarget/einstein256 -Ibuild/v9938 -Ca-Itarget/einstein256 -Ca-Ibuild/v9938 \
	    -DTARGET_EINSTEIN256 -Ca-DTARGET_EINSTEIN256 -Ca-DVDP_DATA=8 -Ca-DVDP_CMD=9 -Ca-DVDP_PAL=10 -Ca-DVDP_IND=11 -Ca-DFMT_WIDTH=32 -Ca-DHAVE_MINIMAP_SQUARE \
	    -Ca-DHAVE_SOUND -Ca-DAY_EINSTEIN -Ca-DAY_ADDR_PORT=2 -Ca-DAY_DATA_PORT=3 \
	    $(EINSTEIN256_PLATFORM) $(EINSTEIN256_GAME) $(ENTROPY) $(MENU) $(FIELDS) $(MMNATIVE) $(LINEEDIT) -o $(@D)/simcity
	python3 tools/check_einstein_layout.py $(@D)/simcity.map $(EINSTEIN256_TPA_TOP)
	@# appmake copies the CP/M name into the directory as is: it must be the 11-byte FCB form.  It also writes a
	@# zero record count for the last entry of a file that is an exact multiple of 16 KB, so TILES.DAT gets one spare record.
	(cat build/v9938/TILES.DAT; head -c 128 /dev/zero) > build/einstein256/TILES.PAD
	z88dk-appmake +cpmdisk -f einstein -b $(@D)/simcity -o $(@D)/simcity.dsk \
	    -a build/einstein256/TILES.PAD:'TILES   DAT' \
	    -a build/einstein256/simcity_EINSTEIN_GAME_OVL.bin:'SIMCITY GAM' \
	    -a build/einstein256/simcity_EINSTEIN_MODAL_OVL.bin:'SIMCITY MOD' \
	    -a build/einstein256/simcity_EINSTEIN_SND.bin:'SIMCITY SND'
	@echo "einstein256: COM, overlay and sound files packaged in $(@D)/simcity.dsk"

# Generic CP/M: any Z80 machine with an 80x24 ANSI terminal (CPM_VT52 in plat_cpm.c: a VT52).  A character a square (ui/game.c glyph()), no mini maps; one COM.
$(CPM): $(DEPS)
	@mkdir -p $(@D)
	$(ZCC) +cpm $(COMMON) -Itarget/cpm -Ca-Itarget/cpm -DTARGET_CPM \
	    target/cpm/plat_cpm.c target/cpm/cpm_common.c target/cpm/cpm_io.asm $(GAME) $(ENTROPY) $(MENU) $(NOSOUND) $(FIELDS) -o $(@D)/simcity.com

# The Amstrad PCW (CP/M Plus): 720x256 monochrome, drawn as 40x32 cells of 16x8 pixels, centred (target/pcw/).  The screen pages over the program, so the drawing code is in common memory (HIMEM).
build/pcw/icons.bin: assets/udgs.bin
	@mkdir -p $(@D)
	head -c 448 $< > $@

$(PCW): $(DEPS) build/pcw/icons.bin
	@mkdir -p $(@D)
	$(ZCC) +cpm -subtype=pcw80 $(COMMON) -pragma-include:target/pcw/zpragma.inc -Itarget/pcw -Ca-Itarget/pcw -DTARGET_PCW -Ca-DFMT_WIDTH=40 -Ca-DHAVE_MINIMAP_SQUARE \
	    $(MMNATIVE) target/pcw/plat_pcw.c target/pcw/plat_pcw.asm target/pcw/plat_pcw_font.asm target/pcw/plat_pcw_crt.asm target/cpm/cpm_common.c target/cpm/cpm_io.asm \
	    $(GAME) $(ENTROPY) $(MENU) $(NOSOUND) $(FIELDS) -o $(@D)/simcity
	z88dk-appmake +cpmdisk -f pcw80 -b $(@D)/simcity -o $(@D)/simcity.dsk

# The Casio FP-1100 on its own boot disc (no CP/M): 320x200 in 8 colours, three planes in the sub-CPU's video RAM, which a program running on the sub-CPU
# (target/fp1100/sub.s.in, assembled by z88dk-asm7801) draws into for the Z80 (fp_sub.asm).  Built by z88dk's +fp1100 -subtype=allram: the program is linked at $0000 and the
# whole machine is RAM; z88dk's bootstrap (the ROM reads the boot sector, which brings in a loader with a RAM copy of the polled disk driver, which loads the program) and appmake +fp1100
# make the disc, with the pictures (tools/fp1100_art.py) as the extra block after the program.  The program takes the sub-CPU over itself (fp_boot) and reads the pictures (fp_art).
FP1100_SAVE_SECTOR = 384        # the saved cities' first sector: track 24 (plat_fp1100_files.asm)
FP1100_PLATFORM = target/common/minimap_key_3bpp.c target/fp1100/plat_fp1100.c target/fp1100/fp_tile.asm target/fp1100/fp_sub.asm target/fp1100/fp_data.asm target/fp1100/plat_fp1100_files.asm target/common/plat_icons.c

# The sub program, assembled by z88dk's z88dk-asm7801: sub.all (both pages), the define file sub.inc (the PUBLIC labels as SUB_x DEFCs) and sub.map; the first page is cut at P1End (at most
# 256 bytes: the JB dispatch needs the entry points in one page, and Page2 must follow it), the rest is padded to 8 bytes (fp_boot sends it 8 at a time); the loader (at most 40 bytes) runs at FP1100_LOADER.
ASM7801 = z88dk-asm7801
FP1100_BASE = 9000
FP1100_BASE2 = 9100
FP1100_PAGE = 90
FP1100_LOADER = 3A60
fp1100_addr = $$(( 0x$$(awk '$$1=="$(1)" {print substr($$3, 2)}' build/fp1100/sub.map) - 0x$(FP1100_BASE) ))

build/fp1100/sub.all build/fp1100/sub.inc build/fp1100/sub.map: target/fp1100/sub.s.in
	@mkdir -p build/fp1100
	$(ASM7801) -DBASE='$$$(FP1100_BASE)' -DPAGE='$$$(FP1100_PAGE)' -DBASE2='$$$(FP1100_BASE2)' -o build/fp1100/sub.all -m build/fp1100/sub.map -d build/fp1100/sub.inc -p SUB_ -U target/fp1100/sub.s.in 0x$(FP1100_BASE) > /dev/null

build/fp1100/sub.bin: build/fp1100/sub.all build/fp1100/sub.map
	@p1=$(call fp1100_addr,P1End); p2=$(call fp1100_addr,Page2); \
	    if [ $$p1 -gt 256 ] || [ $$p2 -ne 256 ]; then echo "sub program layout is wrong: page 1 $$p1 bytes, page 2 at $$p2"; exit 1; fi; \
	    head -c $$p1 build/fp1100/sub.all > $@

build/fp1100/sub2.bin: build/fp1100/sub.all
	tail -c +257 build/fp1100/sub.all | dd bs=8 conv=sync of=$@ 2> /dev/null

build/fp1100/loader.raw: target/fp1100/loader.s.in build/fp1100/sub.inc
	cp target/fp1100/loader.s.in build/fp1100/loader.s       # (an INCLUDE is found next to the source)
	$(ASM7801) -o $@ build/fp1100/loader.s 0x$(FP1100_LOADER) > /dev/null

build/fp1100/loader.bin: build/fp1100/loader.raw
	@[ `wc -c < $<` -le 40 ] || { echo "the fp1100 loader is over 40 bytes"; exit 1; }; dd bs=40 conv=sync if=$< of=$@ 2> /dev/null

# 345 pictures of 24 bytes and the 112 cells of the tool icons (tools/fp1100_art.py), padded to 43 sectors, each byte turned about (the leftmost pixel is bit 0 on this machine)
build/fp1100/art.bin: build/common/tiles_640x200_3bpp.bin assets/cpc_icons.bin tools/fp1100_art.py
	@mkdir -p $(@D)
	python3 tools/fp1100_art.py build/common/tiles_640x200_3bpp.bin assets/cpc_icons.bin $@

$(FP1100): $(DEPS) build/fp1100/sub.bin build/fp1100/sub2.bin build/fp1100/loader.bin build/fp1100/sub.inc build/fp1100/art.bin
	@mkdir -p $(@D)
	$(ZCC) +fp1100 -subtype=allram $(COMMON) -pragma-include:target/fp1100/zpragma.inc -Itarget/fp1100 -Ca-Itarget/fp1100 -Ca-Ibuild/fp1100 -DTARGET_FP1100 -Ca-DTARGET_FP1100 -Ca-DSIM_YIELD_EXTRA -Ca-DHAVE_MINIMAP_SQUARE \
	    $(FP1100_PLATFORM) $(GAME) $(ENTROPY) $(MENU) $(NOSOUND) $(FIELDS) $(MMNATIVE) -o $(@D)/simcity.bin -create-app -Cz"--data build/fp1100/art.bin"
	@size=`wc -c < $(@D)/simcity.bin`; tail=`sed -n 's/^__BSS_END_tail *= \$$\([0-9A-Fa-f]*\).*/\1/p' $(@D)/simcity.map`; \
	    echo "fp1100: the program is $$size bytes and with its uninitialised data ends at $$tail (the loader is at F800, gone when the program runs)"; \
	    [ $$(( 0x$$tail )) -le $$(( 0xF800 )) ] || { echo "too big: the program's data must end below F800 (the stack's 2 KB)"; rm -f $@; exit 1; }; \
	    [ $$(( 9 + (size + 255) / 256 + `wc -c < build/fp1100/art.bin` / 256 )) -le $(FP1100_SAVE_SECTOR) ] || { echo "the program and pictures run into the saved cities (from sector $(FP1100_SAVE_SECTOR))"; rm -f $@; exit 1; }

# The Sharp MZ-2500 (z88dk +mz2500: a boot disk the IPL loads page by page).  320x200 in 16 colours, planar video RAM; the Atari ST's art in a planar atlas (pages 22-24), 32 x 24 cells
# of 8x8.  The program is linked at $0000 (RAM pages 16-17, started by the crt's BOOTSTRAP stub), the UI and the simulation are 16 KB banks at $4000 mapped into windows 2 and 3 by turns, the data is at
# $8000: see docs/MZ2500-layout.md.  MZ2500_MAP=120x100 is for later (the data does not fit yet).
MZ2500_PLATFORM = target/mz2500/mz_boot.asm target/mz2500/mz_data.asm target/mz2500/plat_mz2500.asm target/mz2500/plat_mz2500.c target/mz2500/mz_pointer.c target/mz2500/pointer_res.c target/mz2500/plat_sound.asm target/mz2500/mz_files.c $(LINEEDIT) target/common/minimap_key.c
MZ2500_GAME = $(filter-out ui/main.c,$(GAME))         # (main() is in mz_boot.asm)

build/mz2500/TILES.BIN build/mz2500/mz2500.inc build/mz2500/mz2500.h: assets/st_tiles.bin assets/st_icons.bin tools/st_tiles_3bpp.py
	@mkdir -p $(@D)
	python3 tools/st_tiles_3bpp.py assets/st_tiles.bin --icons assets/st_icons.bin --numbering cpc --mz2500 $(@D)

$(MZ2500): $(DEPS) build/mz2500/TILES.BIN build/mz2500/mz2500.inc build/mz2500/mz2500.h
	@mkdir -p $(@D)
	$(ZCC) +mz2500 $(COMMON) -pragma-include:target/mz2500/zpragma.inc --codeseg CODE_18 \
	    -Itarget/mz2500 -Ibuild/mz2500 -Ca-Itarget/mz2500 -Ca-Ibuild/mz2500 -DTARGET_MZ2500 -Ca-DTARGET_MZ2500 -Ca-DENGINE_BANK -DFINE_ZONE_LEVELS -Ca-DFINE_ZONE_LEVELS \
	    -Ca-DFMT_WIDTH=32 -Ca-DHAVE_MINIMAP_SQUARE -Ca-DHAVE_SOUND -Ca-DAY_SCALE -Ca-DAY_DIV2 -Ca-DAY_OPN -Ca-DAY_ADDR_PORT=0xC8 -Ca-DAY_DATA_PORT=0xC9 \
	    $(MZ2500_PLATFORM) $(MZ2500_GAME) $(ENTROPY) $(MENU) $(FIELDS) $(MMNATIVE) target/common/ay_hooks.asm target/common/ay_sfx.asm -create-app -o $(@D)/simcity
	@ls -l $(@D)/simcity $(@D)/simcity_BANK_*.bin

# The MGT SAM Coupe in its all RAM mode, screen mode 4 (256x192, 16 colours): the program, its data and its stack in the low 32 KB, the
# uninitialised data in the next 32 KB (which the startup code pages in over $8000-$FFFF), and the baked pictures in the 32 KB after that,
# where the placer pages them in a picture at a time (the screen is paged over the data window to draw).  The disk image is that
# one file, padded to a block boundary, so the loader's pages follow each other.
SAM_TEST =              # (-DSOUND_TEST -Ca-DSOUND_TEST: the build of test/sam/sound_check.py, which calls the sound hooks itself)
# The SAM has a picture for every growth level of a zone (the engine's FINE_ZONE_LEVELS: the CPC game's 471 pictures, made from the ST's art); SAM_FINE=0 makes the Spectrum's 345
SAM_FINE ?= 1
ifeq ($(SAM_FINE),1)
SAM_FINE_FLAG = -Ca-DFINE_ZONE_LEVELS
SAM_NUMBERING = cpc
else
SAM_NUMBERING = ours
endif
$(SAM): $(DEPS) build/sam/tiles.bin build/sam/anim.inc
	@mkdir -p $(@D)
	$(ZCC) +sam -subtype=allram $(COMMON) -pragma-include:target/sam/zpragma.inc \
	    -pragma-define:MMAP=-1 -Itarget/sam -Ca-Itarget/sam -DTARGET_SAM -DHAVE_MOUSE -DHAVE_POINTER -DHAVE_MOUSE_POINTER -Ca-DTARGET_SAM $(SAM_FINE_FLAG) -Ca-DENGINE_SIM_SECTION -Ca-DFMT_WIDTH=32 -Ca-DHAVE_MINIMAP_SQUARE -Ca-DHAVE_SOUND -Ca-DAY_SAA -Ca-DAY_ISR $(SAM_TEST) target/sam/plat_sam_files.asm $(GAME) $(ENTROPY) $(MENU) target/sam/plat_sound.asm target/common/ay_hooks.asm target/common/ay_sfx.asm $(FIELDS) $(MMNATIVE) $(LINEEDIT) $(SAM_PLATFORM_NOFILES) -o $(@D)/simcity.bin
	@size=`wc -c < $(@D)/simcity.bin`; echo "sam image: $$size bytes (BSS trimmed from the disk image)"; \
	    [ $$size -le 65536 ] || { echo "the initialized image exceeds the 64 KB program window"; rm -f $@; exit 1; }
	@# Screen-dependent routines must stay below $8000; mp_screen_end marks the start of the low code_driver section.
	@code=`sed -n 's/^mp_screen_end *= \$$\([0-9A-Fa-f]*\).*/\1/p' $(@D)/simcity.map`; \
	    [ -n "$$code" ] && [ $$(( 0x$$code )) -le 32768 ] || { echo "screen-dependent code/data crosses $$8000 (boundary at $$code)"; rm -f $@; exit 1; }
	@v=`sed -n 's/^mp_pix *= \$$\([0-9A-Fa-f]*\).*/\1/p' $(@D)/simcity.map`; \
	    [ -n "$$v" ] && [ $$(( 0x$$v )) -lt 32768 ] || { echo "the placer's variables are not below $$8000 (mp_pix at $$v)"; rm -f $@; exit 1; }
	@v=`sed -n 's/^mp_space *= \$$\([0-9A-Fa-f]*\).*/\1/p' $(@D)/simcity.map`; \
	    [ -n "$$v" ] && [ $$(( 0x$$v + 80 )) -le 32768 ] || { echo "the SAM lookup buffer is not in resident low RAM (mp_space at $$v)"; rm -f $@; exit 1; }
	@v=`sed -n 's/^mp_dpage *= \$$\([0-9A-Fa-f]*\).*/\1/p' $(@D)/simcity.map`; \
	    [ -n "$$v" ] && [ $$(( 0x$$v )) -lt 32768 ] || { echo "the screen restore state is not below $$8000 (mp_dpage at $$v)"; rm -f $@; exit 1; }
	python3 -c "from pathlib import Path; low=Path('$(@D)/simcity.bin').read_bytes(); high=Path('$(@D)/simcity_code_simulation.bin').read_bytes(); assert len(low) <= 32768, f'low RAM image is {len(low)} bytes (limit 32768)'; assert len(high) <= 32768, f'high RAM image is {len(high)} bytes (limit 32768)'; Path('$(@D)/simcity.all').write_bytes(low + bytes(32768-len(low)) + high + bytes(32768-len(high)) + Path('build/sam/tiles.bin').read_bytes())"
	z88dk-appmake +mgt -b $(@D)/simcity.all --org 0 --exec --default-dosfile $$ZCCCFG/../target/sam/classic/samdos2.bin -o $@

# The ZX Spectrum Next: Layer 2 (256x192, a byte a pixel), the Atari ST's art in its 16 colours, as the SAM Coupe.  The program is linked at
# $0000 (z88dk's zxn crt with CRT_ORG_CODE 0: target/zxn/zpragma.inc) and the stack and the uninitialised data are at
# ZXN_BSS; appmake makes the NEX file, with the program in a bank of its own and a loader that maps it (z88dk's zx-util.c: this needs z88dk's commit
# 81ee7e6dcc, "(zxn) Support .nex files starting at 0", which is also in the crt's CRT_ORG_CODE=0 mode).  The simulation, the pictures and the scenarios are
# `SECTION BANK_n` data that appmake merges into the NEX.
# The layout: the program (below $8000) is the code and the tables, in the lowest 16 KB (the crt, what the simulation calls: its hooks, the sound, the
# cooperative switch, the map drawing's tables) and in $4000 to $7FFF, where the NEX loader puts bank 5 and the game runs from; the simulation's code is in a bank of
# its own (BANK_6, linked at $4000, mapped over bank 5 while the simulation runs: engine/sections.asm); the data starts at $8000 (the image is padded to it:
# target/zxn/zxn_pad.asm), the stack is above it and the big arrays, the map and the minimaps, from ZXN_BSS.
ZXN_DATA = 0x9400
ZXN_BSS = 0x9C00
# The map is 120x100 (the engine is made for widths of 96 and 120: engine/mapsize.inc) and the title screen has the eight scenarios.  Its mini map keeps the 96x96
# square viewport and sidebar; cursor keys pan over the extra 24 columns and 4 rows.  ZXN_MAP=96x96 builds the original's size, with no scenarios.
ZXN_MAP ?= 120x100
ifeq ($(ZXN_MAP),120x100)
ZXN_MAPFLAGS = -DMAP_W=120 -DMAP_H=100 -Ca-DMAP_W=120 -Ca-DMAP_H=100
ZXN_MAPFLAGS += -DHAVE_SCENARIOS -Ca-DHAVE_SCENARIOS
ZXN_MAPFLAGS += -DPOWER_SHOWN -Ca-DPOWER_SHOWN
ZXN_SCENARIO_ASM = build/zxn/scenarios/scenarios.asm
ZXN_SCENARIO_C = target/zxn/scenarios.c
else ifneq ($(ZXN_MAP),96x96)
$(error ZXN_MAP must be 120x100 (the default) or 96x96)
endif
# The Next has a picture for every growth level of a zone (the engine's FINE_ZONE_LEVELS: the CPC game's 471 pictures, made from the Amiga's art; the scenarios' zones
# are converted to them); ZXN_FINE=0 makes the Spectrum's 345
ZXN_FINE ?= 1
ifeq ($(ZXN_FINE),1)
ZXN_FINE_FLAGS = -DFINE_ZONE_LEVELS -Ca-DFINE_ZONE_LEVELS
ZXN_NUMBERING = cpc
ZXN_SCENARIO_FINE = --fine
else
ZXN_NUMBERING = ours
endif
ZXN_FLAGS =                    # (-DZXN_NO_SCROLL: no scrolling by the DMA; -DZXN_PACE=2: 25 frames a second)
ZXN_ENTROPY = $(ENTROPY)       # (target/zxn/entropy_test.asm: the build test/zxn/run.py runs, which makes the same city each time)
ZXN_ASM = target/zxn/plat_zxn.asm target/zxn/plat_sound.asm target/zxn/zxn_boot.asm target/zxn/zxn_data.asm
# (the sound: the interrupt plays it, and the simulation's sound hooks start it, so it is in the lowest 16 KB: sections of code_home)
ZXN_LOW = target/common/ay_hooks.asm target/common/ay_sfx.asm
ZXN_PLATFORM = target/zxn/plat_zxn.c target/zxn/zxn_files.asm target/zxn/zxn_mouse.c target/common/pointer.c target/common/minimap_key.c
ZXN_PLATFORM += $(ZXN_SCENARIO_C)

# (the build's options are in a file that changes with them, so that the NEX is made again when they do)
$(ZXN:.nex=.flags): FORCE
	@mkdir -p $(@D); echo '$(ZXN_FLAGS) $(ZXN_MAPFLAGS) $(ZXN_FINE_FLAGS) $(ZXN_ENTROPY)' | cmp -s - $@ || echo '$(ZXN_FLAGS) $(ZXN_MAPFLAGS) $(ZXN_FINE_FLAGS) $(ZXN_ENTROPY)' > $@
FORCE:

$(ZXN): $(DEPS) build/zxn/head.bin $(ZXN:.nex=.flags) target/zxn/zxn_pad.asm $(ZXN_SCENARIO_ASM)
	@mkdir -p $(@D)
	@# The data must start at ZXN_DATA: the image is padded to it (zxn_pad.asm), by as much as the first link says, so the program is linked once or twice.
	@pad=0; for pass in 1 2 3; do \
	    $(ZCC) +zxn -clib=classic -lesxdos -subtype=nex -pragma-include:target/zxn/zpragma.inc -pragma-define:CRT_ORG_BSS=$(ZXN_BSS) -pragma-define:REGISTER_SP=$(ZXN_BSS) \
	        -pragma-define:CRT_ORG_BANK_6=0x4000 -Ca-DENGINE_BANK -Ca-DRODATA_IN_RAM -Ca-DZXN_PAD=$$pad -Ca-Itarget/zxn \
	        -Itarget/zxn -DTARGET_ZXN $(ZXN_FLAGS) $(ZXN_MAPFLAGS) $(ZXN_FINE_FLAGS) -Ca-DTARGET_ZXN -Ca-DFMT_WIDTH=32 -Ca-DHAVE_MINIMAP_SQUARE -Ca-DHAVE_SOUND -Ca-DAY_ISR -Ca-DAY_PORT16 -Ca-DAY_SCALE -Ca-DAY_DOWN -Ca-DAY_ADDR_PORT=65533 -Ca-DAY_DATA_PORT=49149 $(COMMON) \
	        $(ZXN_LOW) $(GAME) $(ZXN_ENTROPY) $(MENU) $(FIELDS) $(MMNATIVE) $(LINEEDIT) $(ZXN_ASM) target/zxn/zxn_pad.asm $(ZXN_PLATFORM) -create-app -o $(@D)/simcity.bin || exit 1; \
	    head=$$(sed -n 's/^__DATA_head *= \$$\([0-9A-F]*\).*/\1/p' $(@D)/simcity.map); \
	    need=$$(( $(ZXN_DATA) - 0x$$head )); \
	    [ $$need -ge 0 ] || { echo "the program is $$(( -need )) bytes too big: it must end below $(ZXN_DATA)"; rm -f $@; exit 1; }; \
	    [ $$need -eq $$pad ] && break; pad=$$need; done; \
	    [ $$need -eq $$pad ] || { echo "the padding to the data does not settle"; rm -f $@; exit 1; }; \
	    size=`wc -c < $(@D)/simcity.bin`; dtail=$$(sed -n 's/^__DATA_END_tail *= \$$\([0-9A-F]*\).*/\1/p' $(@D)/simcity.map); \
	    echo "zxn image: $$size bytes: the program ends at $$(( 0x$$head )), $$pad bytes of padding to the data at $(ZXN_DATA), which ends at $$(( 0x$$dtail )); the stack and the arrays start at $$(( $(ZXN_BSS) ))"; \
	    [ $$(( 0x$$dtail )) -le $$(( $(ZXN_BSS) - 512 )) ] || { echo "the data runs into the stack"; rm -f $@; exit 1; }

# The map's art: the Amiga SimCity 1 Meg's (assets/amiga_1meg_tiles.bin, tools/extract_amiga_1meg_tiles.py: 64 colours); ZXN_TILES=assets/amiga_tiles.bin makes it
# the 512K version's, assets/st_tiles.bin the Atari ST's.  The interface (text, charts, mini maps) is in the ST's colours either way.
# The tool icons: the 1 Meg Amiga's (assets/amiga_1meg_icons.bin, tools/extract_amiga_1meg_icons.py); ZXN_ICONS=assets/amiga_icons.bin makes them the 512K's.
ZXN_TILES ?= assets/amiga_1meg_tiles.bin
ZXN_ICONS ?= assets/amiga_1meg_icons.bin
build/zxn/head.bin: $(ZXN_TILES) $(ZXN_ICONS) tools/st_tiles_3bpp.py $(ZXN:.nex=.flags)
	@mkdir -p $(@D)
	python3 tools/st_tiles_3bpp.py $(ZXN_TILES) --amiga-icons $(ZXN_ICONS) --numbering $(ZXN_NUMBERING) --zxn $(@D)

# The scenarios (the 120x100 build): the eight Amiga SimCity maps and texts in assets/amiga_scenarios, extracted once from the 1 Meg disk and kept with the other art assets,
# converted to the Next's tiles and packed into NEX banks.  `make amiga-scenarios` extracts them again from the disk image (simclassics_scc_1meg.adf, which is not in the repository).
build/zxn/scenarios/scenarios.asm: $(wildcard assets/amiga_scenarios/*) assets/amiga_1meg_tiles.bin tools/convert_amiga_scenarios.py tools/st_tiles_3bpp.py $(ZXN:.nex=.flags)
	@mkdir -p $(@D)
	python3 tools/convert_amiga_scenarios.py $(ZXN_SCENARIO_FINE) assets/amiga_scenarios $(@D)

amiga-scenarios: simclassics_scc_1meg.adf tools/extract_amiga_adf.py tools/extract_amiga_scenarios.py
	python3 tools/extract_amiga_adf.py simclassics_scc_1meg.adf --outdir build/amiga_1meg_adf
	python3 tools/extract_amiga_scenarios.py build/amiga_1meg_adf --outdir assets/amiga_scenarios

build/sam/tiles.bin build/sam/anim.inc: assets/st_tiles.bin assets/st_icons.bin tools/st_tiles_3bpp.py
	@mkdir -p $(@D)
	python3 tools/st_tiles_3bpp.py assets/st_tiles.bin --icons assets/st_icons.bin --numbering $(SAM_NUMBERING) --sam build/sam/tiles.bin --sam-anim build/sam/anim.inc

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
