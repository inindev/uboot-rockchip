
# Copyright (C) 2025, John Clark <inindev@gmail.com>

UBOOT_REF := v2025.04
RKBIN_REF := master
ATF_REF := master

# 1 = use atf bl31, 0 = use rockchip bl31
USE_ARM_TF := 1

# directory paths for repositories
RKBIN_DIR := rkbin
ATF_DIR := arm-trusted-firmware
UBOOT_DIR := u-boot

# list of supported boards and their configurations
BOARDS_RAW = $(shell find u-boot/configs -type f -name '*rk3[5][0-9][0-9]*_defconfig' -exec basename {} \; | \
	awk '/rk3[3,5][0-9][0-9][0-9]?s?_defconfig/ { \
	    filename = $$0; \
	    soc_match = match($$0, /rk3[3,5][0-9][0-9][0-9]?s?/); \
	    if (soc_match) { \
	        soc = substr($$0, soc_match, RLENGTH); \
	        board = $$0; \
	        sub(/-rk3[3,5][0-9][0-9][0-9]?s?_defconfig/, "", board); \
	        print soc "-" board ":" filename; \
	    } \
	}' | sort)

# format BOARDS as a space-separated list
BOARDS = $(strip $(BOARDS_RAW))

# extract board names for validation
BOARD_NAMES = $(sort $(patsubst %:%,%,$(BOARDS)))

# get the defconfig for the specified board
BOARD_CONFIG = $(word 2,$(subst :, ,$(filter $(BOARD):%,$(BOARDS))))

# determine platform based on BOARD
PLAT =	$(strip \
	$(if $(filter rk356% ,$(BOARD)),rk3568, \
	$(if $(filter rk3576%,$(BOARD)),rk3576, \
	$(if $(filter rk3588%,$(BOARD)),rk3588, \
	$(error Unsupported platform for BOARD '$(BOARD)')))))
RKBIN_PREFIX = $(shell echo $(PLAT) | sed 's/rk/RK/')
ROCKCHIP_TPL = $(RKBIN_DIR)/$(shell awk -F'=' '$$1 == "[LOADER_OPTION]" {f=1; next} f && $$1 == "FlashData" {print $$2; exit}' $(RKBIN_DIR)/RKBOOT/$(RKBIN_PREFIX)MINIALL.ini)

# default target
.PHONY: all
all: build

# clone repositories
$(RKBIN_DIR):
	@echo "\n$(h1)cloning rockchip rkbin...$(rst)"
	git clone --depth 1 --branch $(RKBIN_REF) https://github.com/rockchip-linux/rkbin.git $(RKBIN_DIR)

$(ATF_DIR):
ifeq ($(USE_ARM_TF),1)
	@echo "\n$(h1)cloning arm trusted firmware...$(rst)"
	git clone --depth 1 --branch $(ATF_REF) https://github.com/ARM-software/arm-trusted-firmware.git $(ATF_DIR)
endif

$(UBOOT_DIR):
	@echo "\n$(h1)cloning u-boot...$(rst)"
	git clone --depth 1 --branch $(UBOOT_REF) https://github.com/u-boot/u-boot.git $(UBOOT_DIR)

# build bl31 with arm trusted firmware
.PHONY: bl31
bl31: $(ATF_DIR)
ifeq ($(USE_ARM_TF),1)
	@echo "\n$(h1)building arm trusted firmware...$(rst)"
	$(MAKE) -C $(ATF_DIR) PLAT=$(PLAT) bl31
	$(eval BL31 := $(ATF_DIR)/build/$(PLAT)/release/bl31/bl31.elf)
else
	$(eval BL31 := $(RKBIN_DIR)/$(shell awk -F'=' '$$1 == "[BL31_OPTION]" {f=1; next} f && $$1 == "PATH" {print $$2; exit}' $(RKBIN_DIR)/RKTRUST/$(RKBIN_PREFIX)TRUST.ini))
endif

# main build target
.PHONY: build
build: validate_board check_prereqs $(RKBIN_DIR) $(UBOOT_DIR) bl31
	@echo "\n$(h1)beginning compile...$(rst)"
	$(MAKE) -C $(UBOOT_DIR) mrproper
	$(MAKE) -C $(UBOOT_DIR) $(BOARD_CONFIG)
	$(MAKE) -C $(UBOOT_DIR) -j$(shell nproc) KCFLAGS="-Werror" ROCKCHIP_TPL=../$(ROCKCHIP_TPL) BL31=../$(BL31) TEE=
	@echo "$(grn)"
	$(UBOOT_DIR)/tools/mkimage -l $(UBOOT_DIR)/u-boot.itb
	@echo "$(cya)"
	@rm -rf $(BOARD) && mkdir -p $(BOARD)
	@cp $(UBOOT_DIR)/idbloader*.img $(UBOOT_DIR)/u-boot.itb $(UBOOT_DIR)/u-boot-rockchip*.bin $(BOARD)/
	@cd $(BOARD) && sha256sum * | tee sha256sums.txt
	@cp readme.txt $(BOARD)
	@zip -r $(BOARD).zip $(BOARD)
	@rm -rf $(BOARD)
	@echo "\nbuild complete: $(yel)$(BOARD).zip$(rst)\n"

# clean repositories
.PHONY: clean
clean:
	[ ! -d $(UBOOT_DIR) ] || $(MAKE) -C $(UBOOT_DIR) mrproper
	[ ! -d $(ATF_DIR) ] || $(MAKE) -C $(ATF_DIR) clean
	rm -f $(UBOOT_DIR)/sha256sums.txt

# distclean: remove cloned repositories
.PHONY: distclean
distclean:
	rm -rf $(RKBIN_DIR) $(ATF_DIR) $(UBOOT_DIR)

# list all BOARD targets
.PHONY: list
list:
	@echo "$(BOARD_NAMES)" | tr ' ' '\n'

# validate BOARD variable
.PHONY: validate_board
validate_board:
	@if [ -z "$(BOARD)" ]; then \
	    echo "BOARD is not set. Please specify a board, e.g., 'make BOARD=rk3588-nanopc-t6'. Supported boards: $(BOARD_NAMES)"; \
	    exit 1; \
	fi
	@if [ -z "$(BOARD_CONFIG)" ]; then \
	    echo "Invalid BOARD: '$(BOARD)'"; \
	    echo "Supported boards: $(BOARD_NAMES)"; \
	    exit 1; \
	fi

# check_prereqs: check toolchain
.PHONY: check_prereqs
check_prereqs:
	@todo=""; \
	for item in screen bc bison flex libssl-dev libgnutls28-dev make python3-dev python3-pyelftools python3-setuptools swig; do \
	    dpkg -l "$$item" 2>/dev/null | grep -q "ii  $$item" || todo="$$todo $$item"; \
	done; \
	\
	if ! test -z "$$todo"; then \
	    echo "the following packages need to be installed:$(bld)$(yel)$$todo$(rst)"; \
	    echo "   run: $(bld)$(grn)sudo apt update && sudo apt -y install$$todo$(rst)\n"; \
	    exit 1; \
	fi

# colors
rst := \033[m
bld := \033[1m
red := \033[31m
grn := \033[32m
yel := \033[33m
blu := \033[34m
mag := \033[35m
cya := \033[36m
h1  := $(blu)==>$(rst) $(bld)

