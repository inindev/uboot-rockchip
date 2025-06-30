
# Copyright (C) 2025, John Clark <inindev@gmail.com>

RKBIN_REF := master
ATF_REF := master
UBOOT_REF := v2025.07-rc6

# 1 = use atf bl31, 0 = use rockchip bl31
USE_ARM_TF := 1

# directory paths for repositories
RKBIN_DIR := rockchip-rkbin
ATF_DIR := arm-trusted-firmware
UBOOT_DIR := u-boot

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
	git clone --no-checkout https://github.com/u-boot/u-boot.git $(UBOOT_DIR)
	cd $(UBOOT_DIR) && git fetch --depth 1 origin refs/tags/$(UBOOT_REF):refs/tags/$(UBOOT_REF) && git checkout $(UBOOT_REF) 2>/dev/null && git checkout -b $(UBOOT_REF:v%=%)
	@patches="$$(find patches -maxdepth 2 -name '*.patch' 2>/dev/null | sort)"; \
	if [ -n "$$patches" ]; then \
	    echo "\n$(h1)applying patches...$(rst)"; \
	    cd $(UBOOT_DIR) && for patch in $$patches; do \
	        echo "Applying $$patch"; \
	        git am ../$$patch || { echo "failed to apply: $(yel)$$patch$(rst)"; exit 1; }; \
	    done; \
	    echo; \
	fi

# list of supported boards and their configurations (evaluated after u-boot is cloned)
.PHONY: boards_raw
boards_raw: $(UBOOT_DIR)
	$(eval BOARDS_RAW := $(shell for file in $$(find u-boot/configs -type f -name '*rk3[3,5][0-9][0-9]*_defconfig'); do \
	    filename=$$(basename $$file); \
	    dts=$$(grep '^CONFIG_DEFAULT_DEVICE_TREE=' $$file | sed 's/.*="//;s/.*[:\/]//;s/"$$//'); \
	    if [ -n "$$dts" ]; then \
	        echo "$$dts:$$filename"; \
	    fi; \
	done | sort))

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
build: validate_board check_prereqs boards_raw $(RKBIN_DIR) $(UBOOT_DIR) bl31
	@echo "\n$(h1)beginning compile...$(rst)"
	$(MAKE) -C $(UBOOT_DIR) mrproper
	$(MAKE) -C $(UBOOT_DIR) $(BOARD_CONFIG)
	$(MAKE) -C $(UBOOT_DIR) -j$(shell nproc) KCFLAGS="-Werror" ROCKCHIP_TPL=../$(ROCKCHIP_TPL) BL31=../$(BL31) TEE=
	@echo "$(grn)"
	$(UBOOT_DIR)/tools/mkimage -l $(UBOOT_DIR)/u-boot.itb
	@echo "$(cya)"
	@rm -rf output/$(BOARD) && mkdir -p output/$(BOARD)/base-files
	@cp $(UBOOT_DIR)/idbloader*.img $(UBOOT_DIR)/u-boot.itb output/$(BOARD)/base-files/ 2>/dev/null || true
	@cp $(UBOOT_DIR)/u-boot-rockchip*.bin output/$(BOARD)/ 2>/dev/null || true
	@cp readme.txt output/$(BOARD)/
	@cd output/$(BOARD) && sha256sum u-boot-rockchip*.bin > sha256sums.txt 2>/dev/null || true
	@cd output/$(BOARD)/base-files && sha256sum idbloader*.img u-boot.itb > sha256sums.txt 2>/dev/null || true
	@cd output && zip -r ../$(BOARD).zip $(BOARD)
	@rm -rf output
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
list: boards_raw
	@echo "$(BOARD_NAMES)" | tr ' ' '\n'

# validate BOARD variable
.PHONY: validate_board
validate_board: boards_raw
	@print_boards() { \
	    echo "Supported boards:"; \
	    for board in $(BOARD_NAMES); do \
	        echo "  $$board" | cut -d':' -f1; \
	    done; \
	}; \
	if [ -z "$(BOARD)" ]; then \
	    echo "$(yel)BOARD is not set. Please specify a board, e.g., $(grn)'make BOARD=rk3588-nanopc-t6'$(rst)"; \
	    print_boards; \
	    echo "$(yel)BOARD is not set. Please specify a board, e.g., $(grn)'make BOARD=rk3588-nanopc-t6'$(rst)"; \
	    exit 1; \
	fi; \
	if [ -z "$(BOARD_CONFIG)" ]; then \
	    echo "$(yel)Invalid BOARD: '$(BOARD)'$(rst)"; \
	    print_boards; \
	    echo "$(yel)Invalid BOARD: '$(BOARD)'$(rst)"; \
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
