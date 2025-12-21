# uboot-rockchip

Pre-built **u-boot** binaries for Rockchip SoCs (RK33xx, RK35xx series), optimized for popular ARM single-board computers.

This repository provides ready-to-flash u-boot images based on upstream u-boot with Rockchip-specific patches and configurations. Binaries are packaged per-board for easy installation on SD/eMMC or SPI flash.

<br/>

## Features
- Based on recent u-boot releases (e.g., **v2025.10** arm64).
- Board-specific binaries including:
  - `u-boot-rockchip.bin` — Combined image for SD/eMMC (idbloader + u-boot.itb)
  - `u-boot-rockchip-spi.bin` — For SPI NOR flash (with offset adjustments)
  - `idbloader.img` / `idbloader-spi.img` — Initial bootloaders
  - `u-boot.itb` — FIT image containing u-boot proper and device trees
- Patches in `patches/` directory for enhanced feature support

<br/>

## Releases
Pre-built binaries are available in [Releases](https://github.com/inindev/uboot-rockchip/releases):

- **u-boot arm64 v2025.10** (Oct 8, 2025) – Latest, with per-board ZIP files.
- Older releases available for previous u-boot versions.

Each release contains ZIP files named after supported boards (e.g., `rock-5b.zip`, `nanopi-m5.zip`), including the necessary binaries and SHA256 checksums.

<br/>

## u-boot binaries
- **idbloader.img** &emsp;This is the initial bootloader image for Rockchip-based devices. It contains the low-level code (like the DDR initialization and basic hardware setup) needed to start the boot process from an SD card or eMMC module. It is loaded first by the SoC Boot ROM.

- **idbloader-spi.img** &emsp;Similar to idbloader.img, but specifically tailored for booting from SPI NOR flash rather than an SD card or eMMC module. In earlier Rockchip designs, such as the rk3399, idbloader-spi.img has special padding to align with SPI NOR flash’s sector/block sizes and Boot ROM requirements. In the rk35xx series, idbloader.img and idbloader-spi.img are identical, as the bootloader image is unified to work across eMMC, SD, and SPI flash.

- **u-boot.itb** &emsp;This is a u-boot FIT (Flattened Image Tree) image, which includes the u-boot bootloader, device tree blobs (DTBs), and sometimes a kernel or other boot components. It’s used to boot the system from an SD card or eMMC, providing the main bootloader functionality like loading the kernel and handling boot configurations.

- **u-boot-rockchip.bin** &emsp;This is a combined binary that includes both idbloader.img (offset 0) and u-boot.itb (offset 8m-32k). It’s designed for convenience when flashing to an SD card or eMMC module, providing a single file that covers the initial bootloader and u-boot stages, simplifying the boot setup process.

- **u-boot-rockchip-spi.bin** &emsp;Similar to u-boot-rockchip.bin, this binary combines idbloader-spi.img (offset 32K) and u-boot.itb (offset CONFIG_SYS_SPI_U_BOOT_OFFS), and is specifically tailored for SPI flash storage. It’s optimized for devices that boot from SPI flash instead of SD card or eMMC, with adjustments for SPI’s smaller size and different access patterns.

<br/>

## Flashing to SD Card or eMMC

Flash u-boot-rockchip.bin to an SD card or eMMC module, which Rockchip devices access as /dev/mmcblkX.

1. Identify the Device
Insert the SD card or eMMC module and run:
```
lsblk
```
Check the output to find your device (e.g., ```/dev/mmcblk0``` or ```/dev/mmcblk1```). Confirm by size or mount points.

2. Flash u-boot
Write u-boot-rockchip.bin to sector 64 (offset required for Rockchip boot):
```
sudo dd if=u-boot-rockchip.bin of=/dev/mmcblkX bs=32k seek=1 conv=fsync
```
Replace /dev/mmcblkX with your device (e.g., ```/dev/mmcblk0```).
The bs=32k seek=1 ensures the image starts at the correct offset (32k = sector 64).

Run sync to flush buffers:
```
sync
```

<br/>

## Flashing to SPI Flash

Flash u-boot-rockchip-spi.bin to the device's SPI flash: ```/dev/mtd0```

1. Install mtd-utils
Ensure ```mtd-utils``` is installed for ```flash_erase``` and ```flashcp```:
```
sudo apt update
sudo apt install mtd-utils
```

2. Confirm MTD Device
On the Rockchip device (or via a connected terminal), check MTD devices:
```
  cat /proc/mtd
```
Look for output like:
```
  dev:    size   erasesize  name
  mtd0: 00800000 00010000 "spi0.0"
```
Note the device (usually ```/dev/mtd0```).

3. Erase SPI Flash
Erase the flash to prepare it:
```
sudo flash_erase /dev/mtd0 0 16
```
This clears 16 blocks starting at offset 0, sufficient for u-boot.

4. Flash u-boot
Write the image with verification:
```
sudo flashcp -v -p u-boot-rockchip-spi.bin /dev/mtd0
```
The -v flag shows progress, and -p preserves padding.

<br/>

## Building from Source
The repository includes sources, patches, and a Makefile. To build:

```bash
git clone https://github.com/inindev/uboot-rockchip.git
cd uboot-rockchip
make BOARD=<board> # e.g., make BOARD=rk3588-nanopc-t6
```

(type ```make``` for a list of targets available)

<br/>

## Related Projects
- [inindev/linux-rockchip](https://github.com/inindev/linux-rockchip) – Matching custom kernels.
- [inindev/debian-image](https://github.com/inindev/debian-image) – Debian images that use these u-boot binaries.

<br/>

## License
GNU General Public License v3.0 (GPL-3.0) – see [LICENSE](LICENSE) file.
