
# Copyright (C) 2024, John Clark <inindev@gmail.com>

UBOOT_TAG  := v2024.07-rc4

RK3568_ATF := ../rkbin/rk3568_bl31_v1.44.elf
RK3568_TPL := ../rkbin/rk3568_ddr_1560MHz_v1.21.bin

RK3588_ATF := ../rkbin/rk3588_bl31_v1.45.elf
RK3588_TPL := ../rkbin/rk3588_ddr_lp4_2112MHz_lp5_2400MHz_v1.16.bin

UBOOT_BRANCH := $(UBOOT_TAG:v%=%)

TARGETS := target_rock-5b target_nanopc-t6 target_orangepi-5 target_orangepi-5-plus \
           target_nanopi-r5c target_nanopi-r5s target_odroid-m1 target_radxa-e25


all: $(TARGETS)

configure: u-boot patch
	@echo "\n$(h1)configuring source tree...$(rst)"
	@rm -fv "outbin/$(BRD)_idbloader.img" "outbin/$(BRD)_u-boot.itb"
	$(MAKE) -C u-boot $(CFG)

build: configure
	@echo "\n$(h1)beginning compile...$(rst)"
	$(MAKE) -C u-boot -j$$(nproc)

	@echo "\n$(h1)success, $(BRD) build complete:$(rst)"
	@echo "$(bld)$(red)"
	@install -Dvm 644 "u-boot/idbloader.img" "outbin/$(BRD)_idbloader.img";
	@install -Dvm 644 "u-boot/u-boot.itb" "outbin/$(BRD)_u-boot.itb"
	@echo "$(rst)"

	@$(MAKE) --no-print-directory help_block

u-boot: | check_prereqs
	git clone "https://github.com/u-boot/u-boot.git"
	git -C u-boot fetch --tags

target_rock-5b:
	$(MAKE) CFG=rock5b-rk3588_defconfig BL31=$(RK3588_ATF) ROCKCHIP_TPL=$(RK3588_TPL) BRD=$(@:target_%=%) build
	@$(MAKE) --no-print-directory help_spi

target_nanopc-t6:
	$(MAKE) CFG=nanopc-t6-rk3588_defconfig BL31=$(RK3588_ATF) ROCKCHIP_TPL=$(RK3588_TPL) BRD=$(@:target_%=%) build
	@$(MAKE) --no-print-directory help_spi

target_orangepi-5:
	$(MAKE) CFG=orangepi-5-rk3588s_defconfig BL31=$(RK3588_ATF) ROCKCHIP_TPL=$(RK3568_TPL) BRD=$(@:target_%=%) build

target_orangepi-5-plus:
	$(MAKE) CFG=orangepi-5-plus-rk3588_defconfig BL31=$(RK3588_ATF) ROCKCHIP_TPL=$(RK3568_TPL) BRD=$(@:target_%=%) build

target_nanopi-r5c:
	$(MAKE) CFG=nanopi-r5c-rk3568_defconfig BL31=$(RK3568_ATF) ROCKCHIP_TPL=$(RK3568_TPL) BRD=$(@:target_%=%) build

target_nanopi-r5s:
	$(MAKE) CFG=nanopi-r5s-rk3568_defconfig BL31=$(RK3568_ATF) ROCKCHIP_TPL=$(RK3568_TPL) BRD=$(@:target_%=%) build

target_odroid-m1:
	$(MAKE) CFG=odroid-m1-rk3568_defconfig BL31=$(RK3568_ATF) ROCKCHIP_TPL=$(RK3568_TPL) BRD=$(@:target_%=%) build
	@$(MAKE) --no-print-directory help_spi

target_radxa-e25:
	$(MAKE) CFG=radxa-e25-rk3568_defconfig BL31=$(RK3568_ATF) ROCKCHIP_TPL=$(RK3568_TPL) BRD=$(@:target_%=%) build

patch:
	@git -C u-boot rev-parse $(UBOOT_TAG) >/dev/null
	@if ! git -C u-boot branch | grep -q $(UBOOT_BRANCH); then \
	    git -C u-boot checkout -b $(UBOOT_BRANCH) $(UBOOT_TAG); \
	    \
	    patches="$$(find patches -maxdepth 2 -name '*.patch' 2>/dev/null | sort)"; \
	    test -z "$$patches" || echo "\n$(h1)patching...$(rst)"; \
	    for patch in $$patches; do \
	        echo "\n$(grn)$$patch$(rst)"; \
	        git -C u-boot am "../$$patch"; \
	    done; \
	elif test _$(UBOOT_BRANCH) != _$$(git -C u-boot branch --show-current); then \
	    git -C u-boot checkout $(UBOOT_BRANCH); \
	fi

check_prereqs:
	@todo=""; \
	for item in screen bc bison flex libssl-dev make python3-dev python3-pyelftools python3-setuptools swig; do \
	    dpkg -l "$$item" 2>/dev/null | grep -q "ii  $$item" || todo="$$todo $$item"; \
	done; \
	\
	if ! test -z "$$todo"; then \
	    echo "the following packages need to be installed:$(bld)$(yel)$$todo$(rst)"; \
	    echo "   run: $(bld)$(grn)sudo apt update && sudo apt -y install$$todo$(rst)\n"; \
	    exit 1; \
	fi

clean: | $(wildcard u-boot)_clean
	@rm -rf outbin
	@echo "\nclean complete\n"

u-boot_clean:
	@echo "\n$(h1)cleaning...$(rst)"
	@rm -f 'u-boot/mkimage-in-simple-bin'*
	@rm -f 'u-boot/simple-bin.fit'*
	$(MAKE) -C u-boot distclean
	@git -C u-boot clean -f
	@git -C u-boot checkout master
	@-git -C u-boot branch -D $(UBOOT_BRANCH) 2>/dev/null
	@git -C u-boot pull --ff-only

help: help_block help_spi

help_block:
	@echo "$(cya)"
	@echo "copy u-boot to block media (replace sdX)"
	@echo "  sudo dd bs=4K seek=8 if=idbloader.img of=/dev/sdX conv=notrunc"
	@echo "  sudo dd bs=4K seek=2048 if=u-boot.itb of=/dev/sdX conv=notrunc,fsync"
	@echo "$(rst)"

help_spi:
	@echo "$(blu)"
	@echo "copy u-boot to spi flash mtd media (apt install mtd-utils)"
	@echo "  sudo flashcp -Av idbloader.img /dev/mtd0"
	@echo "  sudo flashcp -Av u-boot.itb /dev/mtd2"
	@echo "$(rst)"


.PHONY: all configure build $(TARGETS) patch check_prereqs clean _clean u-boot_clean help help_block help_spi


# colors
rst := [m
bld := [1m
red := [31m
grn := [32m
yel := [33m
blu := [34m
mag := [35m
cya := [36m
h1  := $(blu)==>$(rst) $(bld)
