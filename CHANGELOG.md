# Release v1.0.6  (2015-01-09)

This release fixes the following issues:
- Updated the kernel used during installation to 3.12.
- The kernel modules needed as dependency of other modules are now dynamically determined.
- Lots of documentation corrections/improvements/etc.
- Set the console blank timeout to 1 hour so that (normally) the whole installation process can be viewed.
- Added script which handles kernel upgrades. This fixes [issue 88](https://github.com/debian-pi/raspbian-ua-netinst/issues/88) and [issue 89](https://github.com/debian-pi/raspbian-ua-netinst/issues/89)
- Changed permissions on log file so it is not world readable any more. This fixes [issue 106](https://github.com/debian-pi/raspbian-ua-netinst/issues/106).

This release also adds the following new functionality:
- Introduction of the `config` directory. Files and folders placed in that directory are made available in `/boot/config/` for further processing during the installation. 
It is strongly recommended to place all your configuration files and folders inside the `config` directory.
- When building the installer the `config` directory, `installer-config.txt` and `post-install.txt` are automatically packed inside the generated image/archive, so you won't have to do that manually afterwards any more.
- Added support for the serial console on the installed system. This fixes [issue 57](https://github.com/debian-pi/raspbian-ua-netinst/issues/57). The serial console can also be used during installation, but you'd have to modify `cmdline.txt` for that (place the `ttyAMA0` parameters at the end).
- Timing of the start/end and the durarion of the installation.
- Also create images compressed with bz2 which should be easier to use on a Mac.

Other changes:
- Added @goranche as official collaborator to the project.
- Code re-organization for better maintainability.
- Added workaround for non-working busybox-static ([full story](https://github.com/debian-pi/raspbian-ua-netinst/issues/80)).

See the [README](https://github.com/debian-pi/raspbian-ua-netinst/blob/v1.0.6/README.md) for features/installation instruction/etc for this release.


# Release v1.0.5  (2014-07-23)

This release fixes the following issues:
- When there were multiple logfiles of failures, they weren't all copied properly. Now they are.

This release also adds the following new functionality:
- Addition of the following commands: vcgencmd, edidparser, tvservice, vcdbg
and vchiq_test.  

The libraspberrypi-bin package is installed from the raspbian archive, thus available where ever you are, without additional configuration. This fixes [issue 65](https://github.com/debian-pi/raspbian-ua-netinst/issues/65).

See the [README](https://github.com/debian-pi/raspbian-ua-netinst/blob/v1.0.5/README.md) for features/installation instruction/etc for this release.


# Release v1.0.4  (2014-07-21)

This release fixes the following issues:
- Raspberry Pi Model B+ is now also supported.  
Thanks to plugwash for packaging the updated firmware files. This fixes [issue 73](https://github.com/debian-pi/raspbian-ua-netinst/issues/73).

This release also adds the following new functionality:
- Logging of the installation process.

See the [README](https://github.com/debian-pi/raspbian-ua-netinst/blob/v1.0.4/README.md) for features/installation instruction/etc for this release.


# Release v1.0.3  (2014-07-16)

This release fixes the following issues:
- Downloaded packages are now verified against the signing key and the GPG keys
are now included in the installer. This means that the '--allow-unauthenticated' parameter 
of debootstrap is now removed :-) 
Thanks a lot to Jim Turner for providing the pull request which implemented this!  
This closes [issue 55](https://github.com/debian-pi/raspbian-ua-netinst/issues/55) and [issue 66](https://github.com/debian-pi/raspbian-ua-netinst/issues/66).
- Removed an invalid mount parameter for f2fs. This closes [issue 67](https://github.com/debian-pi/raspbian-ua-netinst/issues/67).
- The kernel version and thereby the initramfs version is now dynamically
determined at install time, so that a new kernel version won't break the
installer anymore. This fixes [issue 68](https://github.com/debian-pi/raspbian-ua-netinst/issues/68).
- Fixed the check for the losetup version.
- Made retrieving/setting the date/time more resilient.
- Update the project URL as displayed during install.

See the [README](https://github.com/debian-pi/raspbian-ua-netinst/blob/v1.0.3/README.md) for features/installation instruction/etc for this release.


# Release v1.0.2  (2014-05-21)

This release fixes the following issues:
- Make the installation process more resilient by not aborting the installation
when a not fatal error occurs, like 'apt-get update' or the installation of
the firmware package.
- Hard code wheezy for the raspberrypi.org archive, since they don't support
jessie (yet).
- Support multiple compression methods and don't hard code it to bz2.
Recently the raspbian archives compression changed from bz2 to xz, making the
update.sh script fail.
- Fixed some documentation issues.

See the [README](https://github.com/hifi/raspbian-ua-netinst/blob/v1.0.2/README.md) for features/installation instruction/etc for this release.


# Release v1.0.1  (2014-05-18)

This release fixes the following issues:
- Unable to boot the system when installing / (root) on usb and ext4 was used
as filesystem (fixes [issue 47](https://github.com/debian-pi/raspbian-ua-netinst/issues/47)). Fixed by always installing latest kernel package.
- Configuration file not working as expected (fixes [issue 50](https://github.com/debian-pi/raspbian-ua-netinst/issues/50)). This appears to be
related to creating/modifying configuration files on windows, which has a
different line ending then linux. Fixed by pushing the configuration file
through dos2unix before using it.
- Unable to login to the system when jessie was used as release (fixes [issue 45](https://github.com/debian-pi/raspbian-ua-netinst/issues/45)).
This was caused by a change in default configuration of openssh-server, which
now disables password login by root. Fixed by re-enabling that for jessie.

See the [README](https://github.com/hifi/raspbian-ua-netinst/blob/v1.0.1/README.md) for features/installation instruction/etc for this release.


# Release v1.0.0  (2014-04-15)

This is the first release of the [Raspbian](http://www.raspbian.org/) (minimal) unattended netinstaller provided through GitHub.

If you find any issues, please report them through [the Issues feature](https://github.com/hifi/raspbian-ua-netinst/issues) here on GitHub.

Release Notes:
- First release through GitHub, see the [README](https://github.com/hifi/raspbian-ua-netinst/blob/v1.0/README.md) for features/installation instructions/etc for this release.

Enjoy!
