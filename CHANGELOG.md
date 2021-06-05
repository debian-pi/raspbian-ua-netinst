# Changelog

## Changes in v1.2.x

- Removed raspberrypi.org repo and APT/GPG key from installer and installed system and fixed resulting issues. This fixes issue #529.  
  The user can still add it themselves if they want to and can deal with resulting issues in a way that best fits their situation.
- Added (binary) raspbian.org APT/GPG key to the repo and use that instead of downloading the (ascii-armored) key online.
- Changed default boot partition size to 256MB. With the previous value, 128MB, one could run out of space if multiple kernels got installed and there is no easy workaround for that. One can still override it of course.
- Added Debian's default shell, `dash`, and make that the default and use that for the installer itself as well.  
  Fix the resulting issue which were (apparently) caused by some internal workings of busybox, but a hard dependency on a particular shell is not/never good.
- Replace the `try_again` setting with `fail_action`. The latter is more flexible and isn't tied to a busybox specific functionality.
- Added `mawk` and made that the default awk interpreter, just like on Debian.
- Added `tr` program from the coreutils program as that is POSIX compliant, whereas busybox's was not.

## Deprecated settings in 1.x

A number of configuration settings are deprecated and will be removed in a next major version.

- `ip_addr`: use `ip4_addr` instead
- `ip_gateway`: use `ip4_gateway` instead
- `ip_nameservers`: use `ip4_nameservers` instead
- `ip_netmask`: use `ip4_netmask` instead
- `try_again`: use `fail_action` instead
- Only support the following `preset`s: `base`, `minimal`, `server`
