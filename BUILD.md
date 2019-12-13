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
- bc

On Debian based systems you can install them as root or with sudo as follows:
```
aptitude install git curl bzip2 zip xz-utils gnupg kpartx dosfstools binutils bc
```

The following scripts are used to build the raspbian-ua-netinst installer, listed in the same order they would be used:

 - clean.sh - Start with a clean slate by removing everything created by earlier builds. This is not needed on a first build, but won't hurt either.
 - update.sh - Downloads latest Raspbian packages that will be used to build the installer.
 - build.sh - Builds the installer initramfs and .zip package for Windows/Mac SD card extraction method. Transfer the .zip package to a Windows/Mac computer, then simply unzip it and copy the files onto a FAT formatted SD card.
 - buildroot.sh - Builds the installer SD card image, it requires root privileges and it makes some assumptions like not having any other loop devices in use. You only need to execute this script if you need more than a .zip package. The script produces an .img package and also its bzip2 and xz compressed versions.
