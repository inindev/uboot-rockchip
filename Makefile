
# Copyright (C) 2024, John Clark <inindev@gmail.com>

UBOOT_TAG = v2024.01-rc5

RK3568_ATF = ../rkbin/rk3568_bl31_v1.28.elf
RK3568_TPL = ../rkbin/rk3568_ddr_1560MHz_v1.15.bin

RK3588_ATF = ../rkbin/rk3588_bl31_v1.34.elf
RK3588_TPL = ../rkbin/rk3588_ddr_lp4_2112MHz_lp5_2736MHz_v1.08.bin

UBOOT_BRANCH := $(UBOOT_TAG:v%=%)


all: check_prereqs build

configure: u-boot patch
	@echo "\n$(h1)configuring source tree...$(rst)"

	@rm -f idbloader.img u-boot.itb
	$(MAKE) -C u-boot nanopc-t6-rk3588_defconfig

build: configure
	@echo "\n$(h1)beginning compile...$(rst)"
	$(MAKE) -C u-boot -j$$(nproc) BL31=$(RK3588_ATF) ROCKCHIP_TPL=$(RK3588_TPL)
	$(MAKE) help

u-boot:
	@git clone https://github.com/u-boot/u-boot.git
	@git -C u-boot fetch --tags

patch:
	@if ! git -C u-boot branch | grep -q $(UBOOT_BRANCH); then \
	    git -C u-boot checkout -b $(UBOOT_BRANCH) $(UBOOT_TAG); \
	    \
	    patches="$$(find patches -maxdepth 2 -name '*.patch' 2>/dev/null | sort)"; \
	    test -z $$patches || echo "\n$(h1)patching...$(rst)"; \
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
	@rm -f *.img *.itb
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

help:
	@echo "$(cya)"
	@echo "copy u-boot to block media (replace sdX)"
	@echo "  sudo dd bs=4K seek=8 if=idbloader.img of=/dev/sdX conv=notrunc"
	@echo "  sudo dd bs=4K seek=2048 if=u-boot.itb of=/dev/sdX conv=notrunc,fsync"
	@echo "$(blu)"
	@echo "copy u-boot to spi flash mtd media (apt install mtd-utils)"
	@echo "  sudo flashcp -Av idbloader.img /dev/mtd0"
	@echo "  sudo flashcp -Av u-boot.itb /dev/mtd2"
	@echo "$(rst)"


.PHONY: all configure build patch check_prereqs clean _clean u-boot_clean help


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
