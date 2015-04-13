# raspbian-ua-netinst

The minimal Raspbian unattended netinstaller for Raspberry Pi Model 1B, 1B+ and 2B.  

This project provides [Raspbian][1] power users the possibility to install a minimal base system unattended using latest Raspbian packages regardless when the installer was built.

The installer with default settings configures eth0 with DHCP to get Internet connectivity and completely wipes the SD card from any previous installation.

There are different kinds of "presets" that define the default packages that are going to be installed. Currently, the default one is called _server_ which installs only the essential base system packages including _NTP_ and _OpenSSH_ to provide a sane minimal base system that you can immediately after install ssh in and continue installing your software.

Other presets include _minimal_ which has even less packages (no logging, no text editor, no cron) and _base_ which doesn't even have networking. You can customize the installed packages by adding a small configuration file to your SD card before booting up.

## Features
 - completely unattended, you only need working Internet connection through the Ethernet port
 - DHCP and static ip configuration (DHCP is the default)
 - always installs the latest version of Raspbian
 - configurable default settings
 - extra configuration over HTTP possible - gives unlimited flexibility
 - installation takes about **15 minutes** with fast Internet from power on to sshd running
 - can fit on 512MB SD card, but 1GB is more reasonable
 - default install includes fake-hwclock to save time on shutdown
 - default install includes NTP to keep time
 - /tmp is mounted as tmpfs to improve speed
 - no clutter included, you only get the bare essential packages
 - option to install root to USB drive

## Requirements
 - a Raspberry Pi Model 1B, Model 1B+ or Model 2B
 - SD card of at least 640MB or at least 128MB for USB root install (without customization)
 - working Ethernet with Internet connectivity

## Obtaining installer files on Windows and Mac
Installer archive is around **17MB** and contains all firmware files and the installer.

Go to [our latest release page](https://github.com/debian-pi/raspbian-ua-netinst/releases/latest) and download the .zip file.

Format your SD card as **FAT32** (MS-DOS on _Mac OS X_) and extract the installer files in.  
**Note:** If you get an error saying it can't mount /dev/mmcblk0p1 on /boot then the most likely cause is that you're using exFAT instead of FAT32.
Try formatting the SD card with this tool: https://www.sdcard.org/downloads/formatter_4/

## Alternative method for Mac, writing image to SD card
Prebuilt image is around **17MB** bzip2 compressed and **32MB** uncompressed. It contains the same files as the .zip but is more convenient for Mac users.

Go to [our latest release page](https://github.com/debian-pi/raspbian-ua-netinst/releases/latest) and download the .img.bz2 file.

Extract the .img file from the archive with `bunzip2 raspbian-ua-netinst-<latest-version-number>.img.bz2`.  
Find the _/dev/diskX_ device you want to write to using `diskutil list`. It will probably be 1 or 2.  

To flash your SD card on Mac:

    diskutil unmountDisk /dev/diskX
    sudo dd bs=1m if=/path/to/raspbian-ua-netinst-<latest-version-number>.img of=/dev/rdiskX
    diskutil eject /dev/diskX

_Note the **r** in the of=/dev/rdiskX part on the dd line which should speed up writing the image considerably._

## SD card image for Linux
Prebuilt image is around **11MB** xz compressed and **32MB** uncompressed. It contains the same files as the .zip but is more convenient for Linux users.

Go to [our latest release page](https://github.com/debian-pi/raspbian-ua-netinst/releases/latest) and download the .img.xz file.

To flash your SD card on Linux:

    xzcat /path/to/raspbian-ua-netinst-<latest-version-number>.img.xz > /dev/sdX

Replace _/dev/sdX_ with the real path to your SD card.

## Installing
In normal circumstances, you can just power on your Pi and cross your fingers.

If you don't have a display attached you can monitor the Ethernet card leds to guess activity. When it finally reboots after installing everything you will see them going out and on a few times when Raspbian configures it on boot.

If you do have a display, you can follow the progress and catch any possible errors in the default configuration or your own modifications.  
If you have a serial cable, then remove 'console=tty1' at then end of the `cmdline.txt` file.

**Note:** During the installation you'll see various warning messages, like "Warning: cannot read table of mounted file systems" and "dpkg: warning: ignoring pre-dependency problem!". Those are expected and harmless.

### Logging
The output of the installation process is now also logged to file.  
When the installation completes successfully, the logfile is moved to /var/log/raspbian-ua-netinst.log on the installed system.  
When an error occurs during install, the logfile is moved to the sd card, which gets normally mounted on /boot/ and will be named raspbian-ua-netinst-\<datetimestamp\>.log

## First boot
The system is almost completely unconfigured on first boot. Here are some tasks you most definitely want to do on first boot.

The default **root** password is **raspbian**.

> Set new root password: `passwd`  (can also be set during installation using **rootpw** in [installer-config.txt](#installer-customization))  
> Configure your default locale: `dpkg-reconfigure locales`  
> Configure your timezone: `dpkg-reconfigure tzdata`  

The latest kernel and firmware packages are now automatically installed during the unattended installation process.
When you need a kernel module that isn't loaded by default, you will still have to configure that manually.
When a new kernel becomes available in the archives and is installed, the system will update config.txt, so it boots up the new kernel at the next reboot.

> Optional: `apt-get install raspi-copies-and-fills` for improved memory management performance.  
> Optional: Create a swap file with `dd if=/dev/zero of=/swap bs=1M count=512 && mkswap /swap` (example is 512MB) and enable it on boot by appending `/swap none swap sw 0 0` to `/etc/fstab`.  
> Optional: `apt-get install rng-tools` and add `bcm2708-rng` to `/etc/modules` to auto-load and use the kernel module for the hardware random number generator. This improves the performance of various server applications needing random numbers significantly.

## Reinstalling or replacing an existing system
If you want to reinstall with the same settings you did your first install you can just move the original _config.txt_ back and reboot. Make sure you still have _kernel_install.img_ and _installer.cpio.gz_ in your _/boot_ partition. If you are replacing your existing system which was not installed using this method, make sure you copy those two files in and the installer _config.txt_ from the original image.

    mv /boot/config-reinstall.txt /boot/config.txt
    reboot

**Remember to backup all your data and original config.txt before doing this!**

## Installer customization
While defaults should work for most power users, some might want to customize default configuration or the package set even further. The installer provides support for this by reading a configuration file `installer-config.txt` from the first vfat partition. The configuration file is read in as a shell script so you can abuse that fact if you so want to. 
See `scripts/etc/init.d/rcS` for more details what kind of environment your script will be run in (currently 'busybox sh'). 

If an `installer-config.txt` file exists in the same directory as this `README.md`, it will be added to the installer image automatically.

The format of the file and the current defaults:

    preset=server
    packages= # comma separated list of extra packages
    mirror=http://mirrordirector.raspbian.org/raspbian/
    release=wheezy
    hostname=pi
    domainname=
    rootpw=raspbian
    cdebootstrap_cmdline=
    bootsize=+128M # /boot partition size in megabytes, provide it in the form '+<number>M' (without quotes)
    rootsize=     # / partition size in megabytes, provide it in the form '+<number>M' (without quotes), leave empty to use all free space
    timeserver=time.nist.gov
    ip_addr=dhcp
    ip_netmask=0.0.0.0
    ip_broadcast=0.0.0.0
    ip_gateway=0.0.0.0
    ip_nameservers=
    online_config= # URL to extra config that will be executed after installer-config.txt
    usbroot= # set to 1 to install to first USB disk
    cmdline="dwc_otg.lpm_enable=0 console=ttyAMA0,115200 kgdboc=ttyAMA0,115200 console=tty1 elevator=deadline"
    rootfstype=ext4
    rootfs_mkfs_options=
    rootfs_install_mount_options='noatime,data=writeback,nobarrier,noinit_itable'
    rootfs_mount_options='errors=remount-ro,noatime'

All of the configuration options should be clear. You can override any of these in your _installer-config.txt_ by placing your own `installer-config.txt` in the main directory.  
The time server is only used during installation and is for _rdate_ which doesn't support the NTP protocol.  
**Note:** You only need to provide the options which you want to **override** in your _installer-config.txt_ file.  
All non-provided options will use the defaults as mentioned above.

Available presets: _server_, _minimal_ and _base_.

Presets set the `cdebootstrap_cmdline` variable. For example, the current _server_ default is:

> _--flavour=minimal --include=kmod,fake-hwclock,ifupdown,net-tools,isc-dhcp-client,ntp,openssh-server,vim-tiny,iputils-ping,wget,ca-certificates,rsyslog,dialog,locales,less,man-db_

There's also support for a `post-install.txt` script which is executed just before unmounting the filesystems. You can use it to tweak and finalize your automatic installation. Just like above, if `post-install.txt` exists in the same directory as this `README.md`, it will be added to the installer image automatically.

## Disclaimer
We take no responsibility for ANY data loss. You will be reflashing your SD card anyway so it should be very clear to you what you are doing and will lose all your data on the card. Same goes for reinstallation.

See LICENSE for license information.

  [1]: http://www.raspbian.org/ "Raspbian"
