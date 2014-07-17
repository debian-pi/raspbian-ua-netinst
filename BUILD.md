raspbian-ua-netinst build instructions
======================================

The Required packages are zip, kpartx (sudo apt-get install zip kpartx).

The following scripts are used to build the raspbian-ua-netinst installer, listed in the same order they would be used:

 - update.sh - Downloads latest Raspbian packages that will be used to build the installer.
 - build.sh - Builds the installer initramfs and .zip package for Windows/Mac SD card extraction method.
 - buildroot.sh - Builds the installer SD card image, it requires root priviledges and it makes some assumptions like not having any other loop devices in use.
 - clean.sh - Remove everything created by above scripts.
