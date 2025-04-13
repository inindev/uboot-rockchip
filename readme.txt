Flashing to SD Card or eMMC
~~~~~~~~~~~~~~~~~~~~~~~~~~~

Flash u-boot-rockchip.bin to an SD card or eMMC module, which Rockchip devices access as /dev/mmcblkX.

1. Identify the Device
Insert the SD card or eMMC module and run:

  lsblk

Check the output to find your device (e.g., /dev/mmcblk0 or /dev/mmcblk1). Confirm by size or mount points.

2. Flash U-Boot
Write u-boot-rockchip.bin to sector 64 (offset required for Rockchip boot):

  sudo dd if=u-boot-rockchip.bin of=/dev/mmcblkX bs=32k seek=1 conv=fsync

Replace /dev/mmcblkX with your device (e.g., /dev/mmcblk0).
The bs=32k seek=1 ensures the image starts at the correct offset (32KiB * 1 = sector 64).

Run sync to flush buffers:

  sync



Flashing to SPI Flash
~~~~~~~~~~~~~~~~~~~~~

Flash u-boot-rockchip-spi.bin to the device's SPI flash: /dev/mtd0

1. Install mtd-utils
Ensure mtd-utils is installed for flash_erase and flashcp:

  sudo apt update && sudo apt install mtd-utils

2. Confirm MTD Device
On the Rockchip device (or via a connected terminal), check MTD devices:

  cat /proc/mtd

Look for output like:

  dev:    size   erasesize  name
  mtd0: 00800000 00010000 "spi0.0"

Note the device (usually /dev/mtd0).

3. Erase SPI Flash
Erase the flash to prepare it:

  sudo flash_erase /dev/mtd0 0 16

This clears 16 blocks starting at offset 0, sufficient for U-Boot.

4. Flash U-Boot
Write the image with verification:

  sudo flashcp -v -p u-boot-rockchip-spi.bin /dev/mtd0

The -v flag shows progress, and -p preserves padding.

