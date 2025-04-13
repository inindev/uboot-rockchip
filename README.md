# uboot-rockchip
u-boot for rockchip devices

<br/>

### u-boot binaries
- **idbloader.img** &emsp;This is the initial bootloader image for Rockchip-based devices. It contains the low-level code (like the DDR initialization and basic hardware setup) needed to start the boot process from an SD card or eMMC module. It is loaded first by the SoC Boot ROM.

- **idbloader-spi.img** &emsp;Similar to idbloader.img, but specifically tailored for booting from SPI NOR flash rather than an SD card or eMMC module. In earlier Rockchip designs, such as the rk3399, idbloader-spi.img has special padding to align with SPI NOR flash’s sector/block sizes and Boot ROM requirements. In the rk35xx series, idbloader.img and idbloader-spi.img are identical, as the bootloader image is unified to work across eMMC, SD, and SPI flash.

- **u-boot.itb** &emsp;This is a u-boot FIT (Flattened Image Tree) image, which includes the U-Boot bootloader, device tree blobs (DTBs), and sometimes a kernel or other boot components. It’s used to boot the system from an SD card or eMMC, providing the main bootloader functionality like loading the kernel and handling boot configurations.

- **u-boot-rockchip.bin** &emsp;This is a combined binary that includes both idbloader.img (offset 0) and u-boot.itb (offset 8m-32k). It’s designed for convenience when flashing to an SD card or eMMC module, providing a single file that covers the initial bootloader and U-Boot stages, simplifying the boot setup process.

- **u-boot-rockchip-spi.bin** &emsp;Similar to u-boot-rockchip.bin, this binary combines idbloader-spi.img (offset 32K) and u-boot.itb (offset CONFIG_SYS_SPI_U_BOOT_OFFS), and is specifically tailored for SPI flash storage. It’s optimized for devices that boot from SPI flash instead of SD card or eMMC, with adjustments for SPI’s smaller size and different access patterns.

<br/>

### Flashing to SD Card or eMMC

Flash u-boot-rockchip.bin to an SD card or eMMC module, which Rockchip devices access as /dev/mmcblkX.

1. Identify the Device
Insert the SD card or eMMC module and run:
```
lsblk
```
Check the output to find your device (e.g., ```/dev/mmcblk0``` or ```/dev/mmcblk1```). Confirm by size or mount points.

2. Flash U-Boot
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

### Flashing to SPI Flash

Flash u-boot-rockchip-spi.bin to the device's SPI flash: ```/dev/mtd0```

1. Install mtd-utils
Ensure mtd-utils is installed for flash_erase and flashcp:
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
This clears 16 blocks starting at offset 0, sufficient for U-Boot.

4. Flash U-Boot
Write the image with verification:
```
sudo flashcp -v -p u-boot-rockchip-spi.bin /dev/mtd0
```
The -v flag shows progress, and -p preserves padding.
