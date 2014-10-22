#!/bin/bash

set -e

KERNEL_VERSION=3.12-1-rpi
INSTALL_MODULES="kernel/fs/f2fs/f2fs.ko"
INSTALL_MODULES="$INSTALL_MODULES kernel/fs/btrfs/btrfs.ko"
INSTALL_MODULES="$INSTALL_MODULES kernel/drivers/usb/storage/usb-storage.ko"
INSTALL_MODULES="$INSTALL_MODULES kernel/drivers/scsi/sg.ko"
INSTALL_MODULES="$INSTALL_MODULES kernel/drivers/scsi/sd_mod.ko"

# checks if first parameter is contained in the array passed as the second parameter
#   use: contains_element "search_for" "${some_array[@]}" || do_if_not_found
function contains_element {
    local elem
    for elem in "${@:2}"; do [[ "${elem}" == "$1" ]] && return 0; done
    return 1
}

# expects an array with kernel modules as a parameter, checks each module for dependencies
# and if a dependency isn't already in the $modules array, adds it to it (through a temporary
# local array).
# in addition sets the global $new_count variable to the number of dependencies added, so
# that the newly added dependencies can be checked as well
#   use: check_dependencies "${modules[@]:${index}}"
function check_dependencies {
    # collect the parameters into an array
    mods=("${@}")
    # temp array to hold the newly found dependencies
    local -a new_found
    # temp array to hold the found dependencies for a single module
    local -a deps
    local mod
    local dep
    # iterate over the passed modules
    for mod in ${mods[@]}; do
        # find the modules dependencies, convert into array
        deps=($(cat "${depmod_file}" | grep "^${mod}" | cut -d':' -f2))
        # iterate over the found dependencies
        for dep in ${deps[@]}; do
            # check if the dependency is in $modules, if not, add to temp array
            contains_element "${dep}" "${modules[@]}" || new_found[${#new_found[@]}]="${dep}"
        done
    done
    # add the newly found dependencies to the end of the $modules array
    modules=("${modules[@]}" "${new_found[@]}")
    # set the global variable to the number of newly found dependencies
    new_count=${#new_found[@]}
}

# creates the file passed as an argument and sets permissions
function touch_tempfile {
    [[ -z "${1}" ]] && return 1
    touch "${1}" && chmod 600 "${1}"
    echo "${1}"
}

# creates a temporary file and returns (echos) its filename
#   the function checks for different commands and uses the appropriate one
#   it will fallback to creating a file in /tmp
function create_tempfile {
    local tmp_ptrn="/tmp/$(basename "${0}").${$}"
    if type mktemp &> /dev/null; then
        mktemp 2> /dev/null || \
            mktemp -t raspbian-ua-netinst 2> /dev/null || \
            touch_tempfile "${tmp_ptrn}"
    else
        if type tempfile &> /dev/null; then
            tempfile
        else
            touch_tempfile "${tmp_ptrn}"
        fi
    fi
}

if [ ! -d packages ]; then
    . ./update.sh
fi

rm -rf tmp
mkdir tmp

# extract debs
for i in packages/*.deb; do
    cd tmp && ar x ../$i && tar -xf data.tar.*; rm data.tar.*; cd ..
done

# initialize bootfs
rm -rf bootfs
mkdir -p bootfs

# raspberrypi-bootloader-nokernel components and kernel
cp tmp/boot/* bootfs/
rm bootfs/System*
rm bootfs/config-*
mv bootfs/vmlinuz* bootfs/kernel_install.img

# initialize rootfs
rm -rf rootfs
mkdir -p rootfs
# create all the directories needed to copy the various components into place
mkdir -p rootfs/bin/
mkdir -p rootfs/lib/
mkdir -p rootfs/lib/modules/${KERNEL_VERSION}
mkdir -p rootfs/sbin/
mkdir -p rootfs/usr/bin/
mkdir -p rootfs/usr/share/
mkdir -p rootfs/usr/share/keyrings/

cp -a tmp/lib/modules/${KERNEL_VERSION}/modules.{builtin,order} rootfs/lib/modules/${KERNEL_VERSION}

# calculate module dependencies
depmod_file=$(create_tempfile)
/sbin/depmod -nab tmp ${KERNEL_VERSION} > ${depmod_file}

modules=(${INSTALL_MODULES})

# new_count contains the number of new elements in the $modules array for each iteration
new_count=${#modules[@]}
# repeat the hunt for dependencies until no new ones are found (the loop takes care
# of finding nested dependencies)
until [ "${new_count}" == 0 ]; do
    # check the dependencies for the modules in the last $new_count elements
    check_dependencies "${modules[@]:$((${#modules[@]}-${new_count}))}"
done

# do some cleanup
rm -f ${depmod_file}

# copy the needed kernel modules to the rootfs (create directories as needed)
for module in ${modules[@]}; do
    # calculate the target dir, just so the following line of code is shorter :)
    dstdir="rootfs/lib/modules/${KERNEL_VERSION}/$(dirname ${module})"
    # check if destination dir exist, create it otherwise
    [ -d "${dstdir}" ] || mkdir -p "${dstdir}"
    cp -a "tmp/lib/modules/${KERNEL_VERSION}/${module}" "${dstdir}"
done

/sbin/depmod -a -b rootfs ${KERNEL_VERSION}

# install scripts
cp -r scripts/* rootfs/

# update version and date
sed -i "s/__VERSION__/git~`git rev-parse --short @{0}`/" rootfs/etc/init.d/rcS
sed -i "s/__DATE__/`date`/" rootfs/etc/init.d/rcS


# btrfs-tools components
cp tmp/sbin/mkfs.btrfs rootfs/sbin/
cp tmp/usr/lib/*/libbtrfs.so.0  rootfs/lib/libbtrfs.so.0

# busybox-static components
cp tmp/bin/busybox rootfs/bin
cd rootfs && ln -s bin/busybox init; cd ..

# cdebootstrap-static components
cp -r tmp/usr/share/cdebootstrap-static rootfs/usr/share/
cp tmp/usr/bin/cdebootstrap-static rootfs/usr/bin/

# dosfstools components
cp tmp/sbin/mkfs.vfat rootfs/sbin/

# e2fslibs components
cp tmp/lib/*/libe2p.so.2.3 rootfs/lib/libe2p.so.2
cp tmp/lib/*/libext2fs.so.2.4  rootfs/lib/libext2fs.so.2

# e2fsprogs components
cp tmp/sbin/mkfs.ext4 rootfs/sbin/

# f2fs-tools components
cp tmp/sbin/mkfs.f2fs rootfs/sbin/
cp tmp/lib/*/libf2fs.so.0  rootfs/lib/libf2fs.so.0

# gpgv components
cp tmp/usr/bin/gpgv rootfs/usr/bin/

# raspberrypi.org GPG key 
cp packages/raspberrypi.gpg.key rootfs/usr/share/keyrings/

# raspbian-archive-keyring components
cp tmp/usr/share/keyrings/raspbian-archive-keyring.gpg rootfs/usr/share/keyrings/

# libblkid1 components
cp tmp/lib/*/libblkid.so.1.1.0 rootfs/lib/libblkid.so.1

# libbz2-1.0 components
cp tmp/lib/*/libbz2.so.1.0.* rootfs/lib/libbz2.so.1.0

# libc6 components
cp tmp/lib/*/ld-*.so rootfs/lib/ld-linux-armhf.so.3
cp tmp/lib/*/libc-*.so rootfs/lib/libc.so.6
cp tmp/lib/*/libm.so.6  rootfs/lib/libm.so.6
cp tmp/lib/*/libresolv-*.so rootfs/lib/libresolv.so.2
cp tmp/lib/*/libnss_dns-*.so rootfs/lib/libnss_dns.so.2
cp tmp/lib/*/libpthread-*.so rootfs/lib/libpthread.so.0

# libcomerr2 components
cp tmp/lib/*/libcom_err.so.2.1 rootfs/lib/libcom_err.so.2

# libgcc1 components
cp tmp/lib/*/libgcc_s.so.1 rootfs/lib/

# liblzo2-2 components
cp tmp/lib/*/liblzo2.so.2 rootfs/lib/liblzo2.so.2

# libuuid1 components
cp tmp/lib/*/libuuid.so.1.3.0 rootfs/lib/libuuid.so.1

# zlib1g components
cp tmp/lib/*/libz.so.1  rootfs/lib/libz.so.1

cd rootfs && find . | cpio -H newc -ov > ../installer.cpio
cd ..

rm -rf tmp
rm -rf rootfs

cp installer.cpio bootfs/

echo "kernel=kernel_install.img" > bootfs/config.txt
echo "initramfs installer.cpio" >> bootfs/config.txt
echo "consoleblank=0 console=ttyAMA0,115200 kgdboc=ttyAMA0,115200 console=tty1" > bootfs/cmdline.txt

if [ -f installer-config.txt ]; then
    cp installer-config.txt bootfs/installer-config.txt
fi

if [ -f post-install.txt ]; then
    cp post-install.txt bootfs/post-install.txt
fi

if [ -d config ] ; then
    mkdir bootfs/config
    cp -r config/* bootfs/config
fi

ZIPFILE=raspbian-ua-netinst-`date +%Y%m%d`-git`git rev-parse --short @{0}`.zip
rm -f $ZIPFILE

cd bootfs && zip -r -9 ../$ZIPFILE *; cd ..
