raspbian-ua-netinst build instructions
======================================

_Note: The following notes are also implemented in `./autobuild.sh`. If you like to use Docker, use `./autobuild-docker.sh` instead._

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

The following scripts are used to build the raspbian-ua-netinst installer, listed in the same order they would be used:

 - update.sh - Downloads latest Raspbian packages that will be used to build the installer.
 - issue-80-workaround-busybox-static-1.20.0-7.sh - Hopefully temporary workaround for issue #80.
 - build.sh - Builds the installer initramfs and .zip package for Windows/Mac SD card extraction method.
 - buildroot.sh - Builds the installer SD card image, it requires root priviledges and it makes some assumptions like not having any other loop devices in use.
 - clean.sh - Remove everything created by above scripts.
