# raspbian-ua-netinst

- [Intro](#intro)
- [Features](#features)
- [Requirements](#requirements)
- [Writing the installer to the SD card](#writing-the-installer-to-the-sd-card)
- [Installing](#installing)
- [Installer customization](#installer-customization)
- [Logging](#logging)
- [First boot](#first-boot)
- [Reinstalling or replacing an existing system](#reinstalling-or-replacing-an-existing-system)
- [Reporting bugs and improving the installer](#reporting-bugs-and-improving-the-installer)
- [Disclaimer](#disclaimer)

## Intro

The minimal Raspbian unattended netinstaller for Raspberry Pi Model 1B, 1B+, 2B and 3B.

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

## Writing the installer to the SD card
### Obtaining installer files on Windows and Mac
Installer archive is around **19MB** and contains all firmware files and the installer.

Go to [our latest release page](https://github.com/debian-pi/raspbian-ua-netinst/releases/latest) and download the .zip file.

Format your SD card as **FAT32** (MS-DOS on _Mac OS X_) and extract the installer files in.  
**Note:** If you get an error saying it can't mount /dev/mmcblk0p1 on /boot then the most likely cause is that you're using exFAT instead of FAT32.
Try formatting the SD card with this tool: https://www.sdcard.org/downloads/formatter_4/

### Alternative method for Mac, writing image to SD card
Prebuilt image is around **19MB** bzip2 compressed and **64MB** uncompressed. It contains the same files as the .zip but is more convenient for Mac users.

Go to [our latest release page](https://github.com/debian-pi/raspbian-ua-netinst/releases/latest) and download the .img.bz2 file.

Extract the .img file from the archive with `bunzip2 raspbian-ua-netinst-<latest-version-number>.img.bz2`.  
Find the _/dev/diskX_ device you want to write to using `diskutil list`. It will probably be 1 or 2.  

To flash your SD card on Mac:

    diskutil unmountDisk /dev/diskX
    sudo dd bs=1m if=/path/to/raspbian-ua-netinst-<latest-version-number>.img of=/dev/rdiskX
    diskutil eject /dev/diskX

_Note the **r** in the of=/dev/rdiskX part on the dd line which should speed up writing the image considerably._

### SD card image for Linux
Prebuilt image is around **17MB** xz compressed and **64MB** uncompressed. It contains the same files as the .zip but is more convenient for Linux users.

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

## Installer customization
You can use the installer _as is_ and get a minimal system installed which you can then use and customize to your needs.  
But you can also customize the installation process and the primary way to do that is through a file named _installer-config.txt_. When you've written the installer to a SD card, you'll see a file named _cmdline.txt_ and you create the _installer-config.txt_ file alongside that file.
The defaults for _installer-config.txt_ are displayed below. If you want one of those settings changed for your installation, you should **only** place that changed setting in the _installer-config.txt_ file. So if you want to have vim and aptitude installed by default, create a _installer-config.txt_ file with the following contents:
```
packages=vim,aptitude
```
and that's it! While most settings stand on their own, some settings influence each other. For example `rootfstype` is tightly linked to the other settings that start with `rootfs_`.  
So don't copy and paste the defaults from below!

The _installer-config.txt_ is read in at the beginning of the installation process, shortly followed by the file pointed to with `online_config`, if specified.
There is also another configuration file you can provide, _post&#8209;install.txt_, and you place that in the same directory as _installer-config.txt_.
The _post&#8209;install.txt_ is executed at the very end of the installation process and you can use it to tweak and finalize your automatic installation.  
The configuration files are read in as  shell scripts, so you can abuse that fact if you so want to.

The format of the _installer-config.txt_ file and the current defaults:

    preset=server
    packages=                 # comma separated list of extra packages
    mirror=http://mirrordirector.raspbian.org/raspbian/
    release=jessie
    hostname=pi
    boot_volume_label=        # Sets the volume name of the boot partition. The volume name can be up to 11 characters
                              # long. The label is used by most OSes (Windows, Mac OSX and Linux) to identify the
                              # SD-card on the desktop and can be useful when using multiple SD-cards.
    domainname=
    rootpw=raspbian
    root_ssh_pubkey=          # public SSH key for root; on Debian "jessie" the SSH password login will be disabled for
                              # root if set; the public SSH key must be on a single line, enclosed in quotes
    disable_root=             # set to 1 to disable root login (and password) altogether
    username=                 # username of the user to create
    userpw=                   # password to use for created user
    user_ssh_pubkey=          # public SSH key for created user; the public SSH key must be on a single line, enclosed
                              # in quotes
    user_is_admin=            # set to 1 to install sudo and make the user a sudo user
    cdebootstrap_cmdline=
    bootsize=+128M            # /boot partition size in megabytes, provide it in the form '+<number>M' (without quotes)
    bootoffset=8192           # position in sectors where the boot partition should start. Valid values are > 2048.
                              # a bootoffset of 8192 is equal to 4MB and that should make for proper alignment
    rootsize=                 # / partition size in megabytes, provide it in the form '+<number>M' (without quotes),
                              # leave empty to use all free space
    timeserver=time.nist.gov
    timezone=Etc/UTC          # set to desired timezone (e.g. Europe/Ljubljana)
    locales=                  # a space delimited list of locales that will be generated during install
                              # (e.g. "en_US.UTF-8 nl_NL sl_SI.UTF-8")
    system_default_locale=    # the default system locale to set (using the LANG environment variable)
    disable_predictable_nin=1 # Disable Predictable Network Interface Names. Set to 0 if you want to use predictable
                              # network interface names, which means if you use the same SD card on a different
                              # RPi board, your network device might be named differently. This will result in the
                              # board having no network connectivity.
    ifname=eth0
    ip_addr=dhcp
    ip_netmask=0.0.0.0
    ip_broadcast=0.0.0.0
    ip_gateway=0.0.0.0
    ip_nameservers=
    drivers_to_load=
    online_config=            # URL to extra config that will be executed after installer-config.txt
    usbroot=                  # set to 1 to install to first USB disk
    cmdline="dwc_otg.lpm_enable=0 console=ttyAMA0,115200 kgdboc=ttyAMA0,115200 console=tty1 elevator=deadline"
    rootfstype=ext4
    rootfs_mkfs_options=
    rootfs_install_mount_options='noatime,data=writeback,nobarrier,noinit_itable'
    rootfs_mount_options='errors=remount-ro,noatime'
    final_action=reboot       # what to do at the end of install, one of poweroff / halt / reboot
    hardware_versions=detect  # "detect" supports the install hardware only, set to "1 2" to produce an install that
                              # supports both Pi1 and Pi2
    hwrng_support=1           # install support for the ARM hardware random number generator. The default is
                              # enabled (1) on all presets. Users requiring a `base` install are advised that
                              # `hwrng_support=0` must be added in `installer-config.txt` if HWRNG support is
                              # undesirable.
    enable_watchdog=0         # loads up the hardware watchdog module and configures systemd to use it. Set to
                              # "1" to enable this functionality.
    gpu_mem=                  # specify the amount of RAM in MB that should be reserved for the GPU

The timeserver parameter is only used during installation for _rdate_ which is used as fallback when setting the time with `ntpdate` fails.  

Available presets: _server_, _minimal_ and _base_.
Presets set the `cdebootstrap_cmdline` variable. For example, the current _server_ default is:

> _--flavour=minimal --include=kmod,fake-hwclock,ifupdown,net-tools,isc-dhcp-client,ntp,openssh-server,vim-tiny,iputils-ping,wget,ca-certificates,rsyslog,dialog,locales,less,man-db_

(If you build your own installer, which most won't need to, and the configuration files exist in the same directory as this `README.md`, it will be include in the installer image automatically.)

### Bring your own files
You can have the installer place your custom configuration files (or any other file you wish to add) on the installed system during the installation. For this, you need to provide the necessary files in the `/config/files/` directory of your SD card (you may need to create this directory if it doesn't exist). The `/config/files/` directory is the root-point. It must have the same structure as inside the installed system. So, a file that you place on the SD card in `/config/files/etc/wpa_supplicant/wpa_supplicant.conf` will end up on the installed system as `/etc/wpa_supplicant/wpa_supplicant.conf`.
Each file or directory that you wish to place on the target system must also be listed in a configuration file in the directory `/config` on your SD card. This allows you to specify the owner (and group) and the permissions of the file. An example file is provided with the installer (see `/config/my-files.list` for more information). ONLY files listed there are copied over to the installed system.
To have the installer actually copy the files to the target system, add the following command at an appropriate point in your `post-install.txt` file:
```
install_files my-files.list
```
where `my-files.list` is the name of the file containing the list of files.
If needed, you can call `install_files` multiple times with different list files.  
Please be aware that some restrictions may apply to the sum of the file sizes. If you wish to supply large files in this manner you may need to adjust the value of the `bootsize` parameter.

### Custom installer script

It is possible to replace the installer script completely, without rebuilding the installer image. To do this, place a custom `rcS` file in the config directory of your SD card. The installer script will check this location and run this script instead of itself. Take great care when doing this, as it is intended to be used for development purposes.

Should you still choose to go this route, please use the original [rcs](https://github.com/debian-pi/raspbian-ua-netinst/blob/master/scripts/etc/init.d/rcS) file as a starting point.

## Logging
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

> Optional: `apt-get install raspi-copies-and-fills` for improved memory management performance.  
> Optional: Create a swap file with `dd if=/dev/zero of=/swap bs=1M count=512 && mkswap /swap && chmod 600 /swap` (example is 512MB) and enable it on boot by appending `/swap none swap sw 0 0` to `/etc/fstab`.  
> Optional: `apt-get install rng-tools` and add `bcm2708-rng` to `/etc/modules` to auto-load and use the kernel module for the hardware random number generator. This improves the performance of various server applications needing random numbers significantly.

## Reinstalling or replacing an existing system
If you want to reinstall with the same settings you did your first install you can just move the original _config.txt_ back and reboot. Depending on the hardware you want to reinstall on (Raspberry Pi **1** or **2**), make sure you still have _kernel_rpi1_install.img_ / _kernel_rpi2_install.img_ and _installer-rpi1.cpio.gz_ / _installer-rpi2.cpio.gz_ in your _/boot_ partition. If you are replacing your existing system which was not installed using this method, make sure you copy those files in and the installer _config.txt_ from the original image.

    mv /boot/config-reinstall.txt /boot/config.txt
    reboot

**Remember to backup all your data and original config.txt before doing this!**

## Reporting bugs and improving the installer
When you encounter issues, have wishes or have code or documentation improvements, we'd like to hear from you!
We've actually written a document on how to best do this and you can find it [here](CONTRIBUTING.md).

## Disclaimer
We take no responsibility for ANY data loss. You will be reflashing your SD card anyway so it should be very clear to you what you are doing and will lose all your data on the card. Same goes for reinstallation.

See LICENSE for license information.

  [1]: http://www.raspbian.org/ "Raspbian"
