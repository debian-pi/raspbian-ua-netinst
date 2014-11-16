raspbian-ua-netinst build instructions
======================================

To create an image yourself, you need to have various packages installed on the host machine.
On a Debian system those are the following, excluding packages with priority essential and required:
- git
- curl
- bzip2
- zip
- xz-utils
- gnupg
- kpartx
- dosfstools
- binutils

The following scripts are used to build the raspbian-ua-netinst installer, listed in the same order they would be used:

 - update.sh - Downloads latest Raspbian packages that will be used to build the installer.
 - build.sh - Builds the installer initramfs and .zip package for Windows/Mac SD card extraction method.
 - buildroot.sh - Builds the installer SD card image, it requires root priviledges and it makes some assumptions like not having any other loop devices in use. **NOTE**: This script may not be needed if the result of the `build.sh` script is directly transferred to a FAT32 formatted SD card.
 - clean.sh - Remove everything created by above scripts.
