
# Copyright (C) 2024, John Clark <inindev@gmail.com>

UBOOT_TAG  := v2024.07-rc4

RKBASE := https://raw.githubusercontent.com/rockchip-linux/rkbin/master

RK3568_BL31 := downloads/rk3568_bl31_v*.elf
RK3568_DDR  := downloads/rk3568_ddr_*.bin

RK3588_BL31 := downloads/rk3588_bl31_v*.elf
RK3588_DDR  := downloads/rk3588_ddr_lp4_*.bin

UBOOT_BRANCH := $(UBOOT_TAG:v%=%)

TARGETS := target_nanopi-r5c target_nanopi-r5s target_odroid-m1 target_radxa-e25 \
           target_orangepi-5 target_orangepi-5-plus target_nanopc-t6 target_rock-5b


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

target_nanopi-r5c: $(RK3568_BL31) $(RK3568_DDR)
	$(MAKE) CFG=nanopi-r5c-rk3568_defconfig BL31=$$(realpath $(RK3568_BL31)) ROCKCHIP_TPL=$$(realpath $(RK3568_DDR)) BRD=$(@:target_%=%) build

target_nanopi-r5s: $(RK3568_BL31) $(RK3568_DDR)
	$(MAKE) CFG=nanopi-r5s-rk3568_defconfig BL31=$$(realpath $(RK3568_BL31)) ROCKCHIP_TPL=$$(realpath $(RK3568_DDR)) BRD=$(@:target_%=%) build

target_odroid-m1: $(RK3568_BL31) $(RK3568_DDR)
	$(MAKE) CFG=odroid-m1-rk3568_defconfig BL31=$$(realpath $(RK3568_BL31)) ROCKCHIP_TPL=$$(realpath $(RK3568_DDR)) BRD=$(@:target_%=%) build
	@$(MAKE) --no-print-directory help_spi

target_radxa-e25: $(RK3568_BL31) $(RK3568_DDR)
	$(MAKE) CFG=radxa-e25-rk3568_defconfig BL31=$$(realpath $(RK3568_BL31)) ROCKCHIP_TPL=$$(realpath $(RK3568_DDR)) BRD=$(@:target_%=%) build

target_orangepi-5: $(RK3588_BL31) $(RK3588_DDR)
	$(MAKE) CFG=orangepi-5-rk3588s_defconfig BL31=$$(realpath $(RK3588_BL31)) ROCKCHIP_TPL=$$(realpath $(RK3588_DDR)) BRD=$(@:target_%=%) build

target_orangepi-5-plus: $(RK3588_BL31) $(RK3588_DDR)
	$(MAKE) CFG=orangepi-5-plus-rk3588_defconfig BL31=$$(realpath $(RK3588_BL31)) ROCKCHIP_TPL=$$(realpath $(RK3588_DDR)) BRD=$(@:target_%=%) build

target_nanopc-t6: $(RK3588_BL31) $(RK3588_DDR)
	$(MAKE) CFG=nanopc-t6-rk3588_defconfig BL31=$$(realpath $(RK3588_BL31)) ROCKCHIP_TPL=$$(realpath $(RK3588_DDR)) BRD=$(@:target_%=%) build
	@$(MAKE) --no-print-directory help_spi

target_rock-5b: $(RK3588_BL31) $(RK3588_DDR)
	$(MAKE) CFG=rock5b-rk3588_defconfig BL31=$$(realpath $(RK3588_BL31)) ROCKCHIP_TPL=$$(realpath $(RK3588_DDR)) BRD=$(@:target_%=%) build
	@$(MAKE) --no-print-directory help_spi

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

rk_bl31:
	@bl31_val="$$(curl -s "$(RKBASE)/RKTRUST/RK$${rkmodel}TRUST.ini" | sed -rn 's/PATH=(.*\.elf)/\1/p')"; \
	bl31_rel="downloads/$$(basename "$$bl31_val")"; \
	if ! [ -e "$$bl31_rel" ]; then \
	    mkdir -p 'downloads'; \
	    wget -P 'downloads' "$(RKBASE)/$$bl31_val"; \
	fi

rk_ddr:
	@ddr_val="$$(curl -s "$(RKBASE)/RKBOOT/RK$${rkmodel}MINIALL.ini" | sed -rn 's/FlashData=(.*)/\1/p')"; \
	ddr_rel="downloads/$$(basename "$$ddr_val")"; \
	if ! [ -e "$$ddr_rel" ]; then \
	    mkdir -p 'downloads'; \
	    wget -P 'downloads' "$(RKBASE)/$$ddr_val"; \
	fi

$(RK3568_BL31):
	@$(MAKE) rkmodel=3568 rk_bl31

$(RK3568_DDR):
	@$(MAKE) rkmodel=3568 rk_ddr

$(RK3588_BL31):
	@$(MAKE) rkmodel=3588 rk_bl31

$(RK3588_DDR):
	@$(MAKE) rkmodel=3588 rk_ddr

clean: | $(wildcard u-boot)_clean
	@rm -rf outbin
	@echo "\nclean complete\n"

mrproper: | $(wildcard u-boot)_clean
	@rm -rf downloads
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


.PHONY: all configure build $(TARGETS) patch check_prereqs rk_bl31 rk_ddr clean mrproper _clean u-boot_clean help help_block help_spi


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
