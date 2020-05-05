# Makefile to rebuild SM64 split image

### Default target ###

default: all

### Build Options ###

# These options can either be changed by modifying the makefile, or
# by building with 'make SETTING=value'. 'make clean' may be required.

# Version of the game to build
VERSION ?= us
# Graphics microcode used
GRUCODE ?= f3d_old
# If COMPARE is 1, check the output sha1sum when building 'all'
COMPARE ?= 1
# If NON_MATCHING is 1, define the NON_MATCHING and AVOID_UB macros when building (recommended)
NON_MATCHING ?= 0

# Automatic settings only for ports
NON_MATCHING := 1
GRUCODE := f3dex2e
WINDOWS_BUILD := 0
ifeq ($(TARGET_WEB),0)
  ifeq ($(OS),Windows_NT)
    WINDOWS_BUILD := 1
  endif
endif

# Release

ifeq ($(VERSION),jp)
  VERSION_CFLAGS := -DVERSION_JP
  VERSION_ASFLAGS := --defsym VERSION_JP=1
  GRUCODE_CFLAGS := -DF3D_OLD
  GRUCODE_ASFLAGS := --defsym F3D_OLD=1
  TARGET := sm64.jp
else
ifeq ($(VERSION),us)
  VERSION_CFLAGS := -DVERSION_US
  VERSION_ASFLAGS := --defsym VERSION_US=1
  GRUCODE_CFLAGS := -DF3D_OLD
  GRUCODE_ASFLAGS := --defsym F3D_OLD=1
  TARGET := sm64.us
else
ifeq ($(VERSION),eu)
  $(warning Building EU is experimental and is prone to breaking. Try at your own risk.)
  VERSION_CFLAGS := -DVERSION_EU
  VERSION_ASFLAGS := --defsym VERSION_EU=1
  GRUCODE_CFLAGS := -DF3D_NEW
  GRUCODE_ASFLAGS := --defsym F3D_NEW=1
  TARGET := sm64.eu
else
  $(error unknown version "$(VERSION)")
endif
endif
endif

# Microcode

ifeq ($(GRUCODE),f3dex) # Fast3DEX
  GRUCODE_CFLAGS := -DF3DEX_GBI
  GRUCODE_ASFLAGS := --defsym F3DEX_GBI_SHARED=1 --defsym F3DEX_GBI=1
  TARGET := $(TARGET).f3dex
  COMPARE := 0
else
ifeq ($(GRUCODE), f3dex2) # Fast3DEX2
  GRUCODE_CFLAGS := -DF3DEX_GBI_2
  GRUCODE_ASFLAGS := --defsym F3DEX_GBI_SHARED=1 --defsym F3DEX_GBI_2=1
  TARGET := $(TARGET).f3dex2
  COMPARE := 0
else
ifeq ($(GRUCODE), f3dex2e) # Fast3DEX2 Extended (for PC)
  GRUCODE_CFLAGS := -DF3DEX_GBI_2E
  TARGET := $(TARGET).f3dex2e
  COMPARE := 0
else
ifeq ($(GRUCODE),f3d_new) # Fast3D 2.0H (Shindou)
  GRUCODE_CFLAGS := -DF3D_NEW
  GRUCODE_ASFLAGS := --defsym F3D_NEW=1
  TARGET := $(TARGET).f3d_new
  COMPARE := 0
else
ifeq ($(GRUCODE),f3dzex) # Fast3DZEX (2.0J / Animal Forest - Dōbutsu no Mori)
  $(warning Fast3DZEX is experimental. Try at your own risk.)
  GRUCODE_CFLAGS := -DF3DEX_GBI_2
  GRUCODE_ASFLAGS := --defsym F3DEX_GBI_SHARED=1 --defsym F3DZEX_GBI=1
  TARGET := $(TARGET).f3dzex
  COMPARE := 0
endif
endif
endif
endif
endif

ifeq ($(NON_MATCHING),1)
  VERSION_CFLAGS := $(VERSION_CFLAGS) -DNON_MATCHING -DAVOID_UB
  COMPARE := 0
endif

ifeq ($(TARGET_WEB),1)
  VERSION_CFLAGS := $(VERSION_CFLAGS) -DTARGET_WEB
endif

################### Universal Dependencies ###################

# (This is a bit hacky, but a lot of rules implicitly depend
# on tools and assets, and we use directory globs further down
# in the makefile that we want should cover assets.)

ifneq ($(MAKECMDGOALS),clean)
ifneq ($(MAKECMDGOALS),distclean)

# Make sure assets exist
NOEXTRACT ?= 0
ifeq ($(NOEXTRACT),0)
DUMMY != ./extract_assets.py $(VERSION) >&2 || echo FAIL
ifeq ($(DUMMY),FAIL)
  $(error Failed to extract assets)
endif
endif

# Make tools if out of date
DUMMY != make -s -C tools >&2 || echo FAIL
ifeq ($(DUMMY),FAIL)
  $(error Failed to build tools)
endif

endif
endif

################ Target Executable and Sources ###############

# BUILD_DIR is location where all build artifacts are placed
BUILD_DIR_BASE := build
ifeq ($(TARGET_WEB),1)
  BUILD_DIR := $(BUILD_DIR_BASE)/$(VERSION)_web
else
  BUILD_DIR := $(BUILD_DIR_BASE)/$(VERSION)_pc
endif

LIBULTRA := $(BUILD_DIR)/libultra.a
ifeq ($(TARGET_WEB),1)
EXE := $(BUILD_DIR)/$(TARGET).html
else
ifeq ($(WINDOWS_BUILD),1)
EXE := $(BUILD_DIR)/$(TARGET).exe
else
EXE := $(BUILD_DIR)/$(TARGET)
endif
endif
ROM := $(BUILD_DIR)/$(TARGET).z64
ELF := $(BUILD_DIR)/$(TARGET).elf
LD_SCRIPT := sm64.ld
MIO0_DIR := $(BUILD_DIR)/bin
SOUND_BIN_DIR := $(BUILD_DIR)/sound
TEXTURE_DIR := textures
ACTOR_DIR := actors
LEVEL_DIRS := $(patsubst levels/%,%,$(dir $(wildcard levels/*/header.h)))

# Directories containing source files
SRC_DIRS := src src/engine src/game src/audio src/menu src/buffers actors levels bin data assets
ASM_DIRS := lib
SRC_DIRS := $(SRC_DIRS) src/pc src/pc/gfx src/pc/audio src/pc/controller
BIN_DIRS := bin bin/$(VERSION)

ULTRA_SRC_DIRS := lib/src lib/src/math
ULTRA_ASM_DIRS := lib/asm lib/data
ULTRA_BIN_DIRS := lib/bin

GODDARD_SRC_DIRS := src/goddard src/goddard/dynlists


MIPSISET := -mips2 -32

ifeq ($(VERSION),eu)
  OPT_FLAGS := -O2
else
  OPT_FLAGS := -g -m32
endif

ifeq ($(TARGET_WEB),1)
  OPT_FLAGS := -O2 -g4 --source-map-base http://localhost:8080/
endif

# File dependencies and variables for specific files
include Makefile.split

# Source code files
LEVEL_C_FILES := $(wildcard levels/*/leveldata.c) $(wildcard levels/*/script.c) $(wildcard levels/*/geo.c)
C_FILES := $(foreach dir,$(SRC_DIRS),$(wildcard $(dir)/*.c)) $(LEVEL_C_FILES)
CXX_FILES := $(foreach dir,$(SRC_DIRS),$(wildcard $(dir)/*.cpp))
S_FILES := $(foreach dir,$(ASM_DIRS),$(wildcard $(dir)/*.s))
ULTRA_C_FILES := $(foreach dir,$(ULTRA_SRC_DIRS),$(wildcard $(dir)/*.c))
GODDARD_C_FILES := $(foreach dir,$(GODDARD_SRC_DIRS),$(wildcard $(dir)/*.c))
GENERATED_C_FILES := $(BUILD_DIR)/assets/mario_anim_data.c $(BUILD_DIR)/assets/demo_data.c \
  $(addprefix $(BUILD_DIR)/bin/,$(addsuffix _skybox.c,$(notdir $(basename $(wildcard textures/skyboxes/*.png)))))

ifeq ($(WINDOWS_BUILD),0)
  CXX_FILES :=
endif

ULTRA_C_FILES_SKIP := \
    sqrtf.c \
    string.c \
    sprintf.c \
    _Printf.c \
    kdebugserver.c \
    osInitialize.c \
    osCreateThread.c \
    osDestroyThread.c \
    osStartThread.c \
    osSetThreadPri.c \
    osPiStartDma.c \
    osPiRawStartDma.c \
    osPiRawReadIo.c \
    osPiGetCmdQueue.c \
    osJamMesg.c \
    osSendMesg.c \
    osRecvMesg.c \
    osSetEventMesg.c \
    osTimer.c \
    osSetTimer.c \
    osSetTime.c \
    osCreateViManager.c \
    osViSetSpecialFeatures.c \
    osVirtualToPhysical.c \
    osViBlack.c \
    osViSetEvent.c \
    osViSetMode.c \
    osViSwapBuffer.c \
    osSpTaskLoadGo.c \
    osCreatePiManager.c \
    osGetTime.c \
    osEepromProbe.c \
    osEepromWrite.c \
    osEepromLongWrite.c \
    osEepromRead.c \
    osEepromLongRead.c \
    osContInit.c \
    osContStartReadData.c \
    osAiGetLength.c \
    osAiSetFrequency.c \
    osAiSetNextBuffer.c \
    __osViInit.c \
    __osSyncPutChars.c \
    __osAtomicDec.c \
    __osSiRawStartDma.c \
    __osViSwapContext.c \
    __osViGetCurrentContext.c

  C_FILES := $(filter-out src/game/main.c,$(C_FILES))
  ULTRA_C_FILES := $(filter-out $(addprefix lib/src/,$(ULTRA_C_FILES_SKIP)),$(ULTRA_C_FILES))

SOUND_BANK_FILES := $(wildcard sound/sound_banks/*.json)
SOUND_SEQUENCE_FILES := $(wildcard sound/sequences/$(VERSION)/*.m64) \
    $(wildcard sound/sequences/*.m64) \
    $(foreach file,$(wildcard sound/sequences/$(VERSION)/*.s),$(BUILD_DIR)/$(file:.s=.m64)) \
    $(foreach file,$(wildcard sound/sequences/*.s),$(BUILD_DIR)/$(file:.s=.m64))
SOUND_SAMPLE_DIRS := $(wildcard sound/samples/*)
SOUND_SAMPLE_AIFFS := $(foreach dir,$(SOUND_SAMPLE_DIRS),$(wildcard $(dir)/*.aiff))
SOUND_SAMPLE_TABLES := $(foreach file,$(SOUND_SAMPLE_AIFFS),$(BUILD_DIR)/$(file:.aiff=.table))
SOUND_SAMPLE_AIFCS := $(foreach file,$(SOUND_SAMPLE_AIFFS),$(BUILD_DIR)/$(file:.aiff=.aifc))
SOUND_OBJ_FILES := $(SOUND_BIN_DIR)/sound_data.ctl.o \
                   $(SOUND_BIN_DIR)/sound_data.tbl.o \
                   $(SOUND_BIN_DIR)/sequences.bin.o \
                   $(SOUND_BIN_DIR)/bank_sets.o


# Object files
O_FILES := $(foreach file,$(C_FILES),$(BUILD_DIR)/$(file:.c=.o)) \
           $(foreach file,$(CXX_FILES),$(BUILD_DIR)/$(file:.cpp=.o)) \
           $(foreach file,$(S_FILES),$(BUILD_DIR)/$(file:.s=.o)) \
           $(foreach file,$(GENERATED_C_FILES),$(file:.c=.o))

ULTRA_O_FILES := $(foreach file,$(ULTRA_S_FILES),$(BUILD_DIR)/$(file:.s=.o)) \
                 $(foreach file,$(ULTRA_C_FILES),$(BUILD_DIR)/$(file:.c=.o))

GODDARD_O_FILES := $(foreach file,$(GODDARD_C_FILES),$(BUILD_DIR)/$(file:.c=.o))

# Automatic dependency files
DEP_FILES := $(O_FILES:.o=.d) $(ULTRA_O_FILES:.o=.d) $(GODDARD_O_FILES:.o=.d) $(BUILD_DIR)/$(LD_SCRIPT).d

# Files with GLOBAL_ASM blocks
ifneq ($(NON_MATCHING),1)
  GLOBAL_ASM_C_FILES != grep -rl 'GLOBAL_ASM(' $(wildcard src/audio/*.c) $(wildcard src/game/*.c)
  GLOBAL_ASM_O_FILES = $(foreach file,$(GLOBAL_ASM_C_FILES),$(BUILD_DIR)/$(file:.c=.o))
  GLOBAL_ASM_DEP = $(BUILD_DIR)/src/audio/non_matching_dep
endif

# Segment elf files
SEG_FILES := $(SEGMENT_ELF_FILES) $(ACTOR_ELF_FILES) $(LEVEL_ELF_FILES)

##################### Compiler Options #######################
INCLUDE_CFLAGS := -I include -I $(BUILD_DIR) -I $(BUILD_DIR)/include -I src -I .
ENDIAN_BITWIDTH := $(BUILD_DIR)/endian-and-bitwidth

AS        := $(CROSS)as
CC        := $(QEMU_IRIX) -silent -L $(IRIX_ROOT) $(IRIX_ROOT)/usr/bin/cc
CPP       := cpp -P -Wno-trigraphs
LD        := $(CROSS)ld
AR        := $(CROSS)ar
OBJDUMP   := $(CROSS)objdump
OBJCOPY   := $(CROSS)objcopy
PYTHON    := python3

# Check code syntax with host compiler
CC_CHECK := gcc -fsyntax-only -fsigned-char $(CC_CFLAGS) $(TARGET_CFLAGS) $(INCLUDE_CFLAGS) -std=gnu90 -Wall -Wextra -Wno-format-security -DNON_MATCHING -DAVOID_UB $(VERSION_CFLAGS) $(GRUCODE_CFLAGS)

ASFLAGS := -march=vr4300 -mabi=32 -I include -I $(BUILD_DIR) $(VERSION_ASFLAGS) $(GRUCODE_ASFLAGS)
CFLAGS = -Wab,-r4300_mul -non_shared -G 0 -Xcpluscomm -Xfullwarn -signed $(OPT_FLAGS) $(TARGET_CFLAGS) $(INCLUDE_CFLAGS) $(VERSION_CFLAGS) $(MIPSISET) $(GRUCODE_CFLAGS)
OBJCOPYFLAGS := --pad-to=0x800000 --gap-fill=0xFF
SYMBOL_LINKING_FLAGS := $(addprefix -R ,$(SEG_FILES))
LDFLAGS := -T undefined_syms.txt -T $(BUILD_DIR)/$(LD_SCRIPT) -Map $(BUILD_DIR)/sm64.$(VERSION).map --no-check-sections $(SYMBOL_LINKING_FLAGS)
ENDIAN_BITWIDTH := $(BUILD_DIR)/endian-and-bitwidth

ifeq ($(shell getconf LONG_BIT), 32)
  # Work around memory allocation bug in QEMU
  export QEMU_GUEST_BASE := 1
else
  # Ensure that gcc treats the code as 32-bit
  CC_CHECK += -m32
endif

####################### Other Tools #########################

# N64 tools
TOOLS_DIR = tools
MIO0TOOL = $(TOOLS_DIR)/mio0
N64CKSUM = $(TOOLS_DIR)/n64cksum
N64GRAPHICS = $(TOOLS_DIR)/n64graphics
N64GRAPHICS_CI = $(TOOLS_DIR)/n64graphics_ci
TEXTCONV = $(TOOLS_DIR)/textconv
IPLFONTUTIL = $(TOOLS_DIR)/iplfontutil
AIFF_EXTRACT_CODEBOOK = $(TOOLS_DIR)/aiff_extract_codebook
VADPCM_ENC = $(TOOLS_DIR)/vadpcm_enc
EXTRACT_DATA_FOR_MIO = $(TOOLS_DIR)/extract_data_for_mio
SKYCONV = $(TOOLS_DIR)/skyconv
EMULATOR = mupen64plus
EMU_FLAGS = --noosd
LOADER = loader64
LOADER_FLAGS = -vwf
SHA1SUM = sha1sum

######################## Targets #############################

clean:
	$(RM) -r $(BUILD_DIR_BASE)

distclean:
	$(RM) -r $(BUILD_DIR_BASE)
	./extract_assets.py --clean

test: $(ROM)
	$(EMULATOR) $(EMU_FLAGS) $<

load: $(ROM)
	$(LOADER) $(LOADER_FLAGS) $<

libultra: $(BUILD_DIR)/libultra.a

asm/boot.s: $(BUILD_DIR)/lib/bin/ipl3_font.bin

$(BUILD_DIR)/lib/bin/ipl3_font.bin: lib/ipl3_font.png
	$(IPLFONTUTIL) e $< $@

$(BUILD_DIR)/include/text_strings.h: include/text_strings.h.in
	$(TEXTCONV) charmap.txt $< $@

$(BUILD_DIR)/include/text_menu_strings.h: include/text_menu_strings.h.in
	$(TEXTCONV) charmap_menu.txt $< $@

ifeq ($(VERSION),eu)
TEXT_DIRS := text/de text/us text/fr

# EU encoded text inserted into individual segment 0x19 files
$(BUILD_DIR)/bin/eu/translation_en.o: $(BUILD_DIR)/text/us/define_text.inc.c
$(BUILD_DIR)/bin/eu/translation_de.o: $(BUILD_DIR)/text/de/define_text.inc.c
$(BUILD_DIR)/bin/eu/translation_fr.o: $(BUILD_DIR)/text/fr/define_text.inc.c

else
TEXT_DIRS := text/$(VERSION)

# non-EU encoded text inserted into segment 0x02
$(BUILD_DIR)/bin/segment2.o: $(BUILD_DIR)/text/$(VERSION)/define_text.inc.c
endif

$(BUILD_DIR)/text/%/define_text.inc.c: text/define_text.inc.c text/%/courses.h text/%/dialogs.h
	$(CPP) $(VERSION_CFLAGS) $< -o $@ -I text/$*/
	$(TEXTCONV) charmap.txt $@ $@

ALL_DIRS := $(BUILD_DIR) $(addprefix $(BUILD_DIR)/,$(SRC_DIRS) $(ASM_DIRS) $(GODDARD_SRC_DIRS) $(ULTRA_SRC_DIRS) $(ULTRA_ASM_DIRS) $(ULTRA_BIN_DIRS) $(BIN_DIRS) $(TEXTURE_DIRS) $(TEXT_DIRS) $(SOUND_SAMPLE_DIRS) $(addprefix levels/,$(LEVEL_DIRS)) include) $(MIO0_DIR) $(addprefix $(MIO0_DIR)/,$(VERSION)) $(SOUND_BIN_DIR) $(SOUND_BIN_DIR)/sequences/$(VERSION)

# Make sure build directory exists before compiling anything
DUMMY != mkdir -p $(ALL_DIRS)

$(BUILD_DIR)/include/text_strings.h: $(BUILD_DIR)/include/text_menu_strings.h
$(BUILD_DIR)/src/menu/file_select.o: $(BUILD_DIR)/include/text_strings.h
$(BUILD_DIR)/src/menu/star_select.o: $(BUILD_DIR)/include/text_strings.h
$(BUILD_DIR)/src/game/ingame_menu.o: $(BUILD_DIR)/include/text_strings.h

################################################################
# TEXTURE GENERATION                                           #
################################################################

# RGBA32, RGBA16, IA16, IA8, IA4, IA1, I8, I4
$(BUILD_DIR)/%: %.png
	$(N64GRAPHICS) -i $@ -g $< -f $(lastword $(subst ., ,$@))

$(BUILD_DIR)/%.inc.c: $(BUILD_DIR)/% %.png
	hexdump -v -e '1/1 "0x%X,"' $< > $@
	echo >> $@

# Color Index CI8
$(BUILD_DIR)/%.ci8: %.ci8.png
	$(N64GRAPHICS_CI) -i $@ -g $< -f ci8

# Color Index CI4
$(BUILD_DIR)/%.ci4: %.ci4.png
	$(N64GRAPHICS_CI) -i $@ -g $< -f ci4

################################################################

# compressed segment generation

$(BUILD_DIR)/%.table: %.aiff
	$(AIFF_EXTRACT_CODEBOOK) $< >$@

$(BUILD_DIR)/%.aifc: $(BUILD_DIR)/%.table %.aiff
	$(VADPCM_ENC) -c $^ $@

$(ENDIAN_BITWIDTH): tools/determine-endian-bitwidth.c
	$(CC) -c $(CFLAGS) -o $@.dummy2 $< 2>$@.dummy1; true
	grep -o 'msgbegin --endian .* --bitwidth .* msgend' $@.dummy1 > $@.dummy2
	head -n1 <$@.dummy2 | cut -d' ' -f2-5 > $@
	@rm $@.dummy1
	@rm $@.dummy2

$(SOUND_BIN_DIR)/sound_data.ctl: sound/sound_banks/ $(SOUND_BANK_FILES) $(SOUND_SAMPLE_AIFCS) $(ENDIAN_BITWIDTH)
	$(PYTHON) tools/assemble_sound.py $(BUILD_DIR)/sound/samples/ sound/sound_banks/ $(SOUND_BIN_DIR)/sound_data.ctl $(SOUND_BIN_DIR)/sound_data.tbl $(VERSION_CFLAGS) $$(cat $(ENDIAN_BITWIDTH))

$(SOUND_BIN_DIR)/sound_data.tbl: $(SOUND_BIN_DIR)/sound_data.ctl
	@true

$(SOUND_BIN_DIR)/sequences.bin: $(SOUND_BANK_FILES) sound/sequences.json sound/sequences/ sound/sequences/$(VERSION)/ $(SOUND_SEQUENCE_FILES) $(ENDIAN_BITWIDTH)
	$(PYTHON) tools/assemble_sound.py --sequences $@ $(SOUND_BIN_DIR)/bank_sets sound/sound_banks/ sound/sequences.json $(SOUND_SEQUENCE_FILES) $(VERSION_CFLAGS) $$(cat $(ENDIAN_BITWIDTH))

$(SOUND_BIN_DIR)/bank_sets: $(SOUND_BIN_DIR)/sequences.bin
	@true

$(SOUND_BIN_DIR)/%.m64: $(SOUND_BIN_DIR)/%.o
	$(OBJCOPY) -j .rodata $< -O binary $@

$(SOUND_BIN_DIR)/%.o: $(SOUND_BIN_DIR)/%.s
	$(AS) $(ASFLAGS) -o $@ $<

$(BUILD_DIR)/levels/scripts.o: $(BUILD_DIR)/include/level_headers.h

$(BUILD_DIR)/include/level_headers.h: levels/level_headers.h.in
	$(CPP) -I . levels/level_headers.h.in | $(PYTHON) tools/output_level_headers.py > $(BUILD_DIR)/include/level_headers.h

$(BUILD_DIR)/assets/mario_anim_data.c: $(wildcard assets/anims/*.inc.c)
	$(PYTHON) tools/mario_anims_converter.py > $@

$(BUILD_DIR)/assets/demo_data.c: assets/demo_data.json $(wildcard assets/demos/*.bin)
	$(PYTHON) tools/demo_data_converter.py assets/demo_data.json $(VERSION_CFLAGS) > $@


# Source code
$(BUILD_DIR)/src/goddard/%.o: OPT_FLAGS := -g
$(BUILD_DIR)/src/goddard/%.o: MIPSISET := -mips1
$(BUILD_DIR)/src/audio/%.o: OPT_FLAGS := -O2 -Wo,-loopunroll,0
$(BUILD_DIR)/src/audio/load.o: OPT_FLAGS := -O2 -framepointer -Wo,-loopunroll,0
$(BUILD_DIR)/lib/src/%.o: OPT_FLAGS :=
$(BUILD_DIR)/lib/src/math/ll%.o: MIPSISET := -mips3 -32
$(BUILD_DIR)/lib/src/math/%.o: OPT_FLAGS := -O2
$(BUILD_DIR)/lib/src/math/ll%.o: OPT_FLAGS :=
$(BUILD_DIR)/lib/src/ldiv.o: OPT_FLAGS := -O2
$(BUILD_DIR)/lib/src/string.o: OPT_FLAGS := -O2
$(BUILD_DIR)/lib/src/gu%.o: OPT_FLAGS := -O3
$(BUILD_DIR)/lib/src/al%.o: OPT_FLAGS := -O3

ifeq ($(VERSION),eu)
$(BUILD_DIR)/lib/src/_Litob.o: OPT_FLAGS := -O3
$(BUILD_DIR)/lib/src/_Ldtob.o: OPT_FLAGS := -O3
$(BUILD_DIR)/lib/src/_Printf.o: OPT_FLAGS := -O3
endif

ifeq ($(NON_MATCHING),0)
$(GLOBAL_ASM_O_FILES): CC := $(PYTHON) tools/asm_processor/build.py $(CC) -- $(AS) $(ASFLAGS) --
endif

# Rebuild files with 'GLOBAL_ASM' if the NON_MATCHING flag changes.
$(GLOBAL_ASM_O_FILES): $(GLOBAL_ASM_DEP).$(NON_MATCHING)
$(GLOBAL_ASM_DEP).$(NON_MATCHING):
	@rm -f $(GLOBAL_ASM_DEP).*
	touch $@

$(BUILD_DIR)/%.o: %.cpp
	@$(CXX) -fsyntax-only $(CFLAGS) -MMD -MP -MT $@ -MF $(BUILD_DIR)/$*.d $<
	$(CXX) -c $(CFLAGS) -o $@ $<

$(BUILD_DIR)/%.o: %.c
	@$(CC_CHECK) -MMD -MP -MT $@ -MF $(BUILD_DIR)/$*.d $<
	$(CC) -c $(CFLAGS) -o $@ $<


$(BUILD_DIR)/%.o: $(BUILD_DIR)/%.c
	@$(CC_CHECK) -MMD -MP -MT $@ -MF $(BUILD_DIR)/$*.d $<
	$(CC) -c $(CFLAGS) -o $@ $<

$(BUILD_DIR)/%.o: %.s
	$(AS) $(ASFLAGS) -MD $(BUILD_DIR)/$*.d -o $@ $<

$(EXE): $(O_FILES) $(MIO0_FILES:.mio0=.o) $(SOUND_OBJ_FILES) $(ULTRA_O_FILES) $(GODDARD_O_FILES)
	$(LD) -L $(BUILD_DIR) -o $@ $(O_FILES) $(SOUND_OBJ_FILES) $(ULTRA_O_FILES) $(GODDARD_O_FILES) $(LDFLAGS)

run: all
	cd build/us_pc && ./sm64.us.f3dex2e

.PHONY: all clean distclean default diff test load libultra
.PRECIOUS: $(BUILD_DIR)/bin/%.elf $(SOUND_BIN_DIR)/%.ctl $(SOUND_BIN_DIR)/%.tbl $(SOUND_SAMPLE_TABLES) $(SOUND_BIN_DIR)/%.s $(BUILD_DIR)/%
.DELETE_ON_ERROR:

# Remove built-in rules, to improve performance
MAKEFLAGS += --no-builtin-rules

-include $(DEP_FILES)

print-% : ; $(info $* is a $(flavor $*) variable set to [$($*)]) @true
