#!/bin/bash

KERNEL_VERSION=3.10-3-rpi

mirror=http://archive.raspbian.org/raspbian/
release=jessie
packages="busybox-static libc6 cdebootstrap-static e2fslibs e2fsprogs libcomerr2 libblkid1 libuuid1 libgcc1 dosfstools linux-image-${KERNEL_VERSION} raspberrypi-bootloader-nokernel f2fs-tools btrfs-tools zlib1g liblzo2-2"
packages_found=
packages_debs=

required() {
    for i in $packages; do
        [[ $i = $1 ]] && return 0
    done

    return 1
}

allfound() {
    for i in $packages; do
        found=0

        for j in $packages_found; do
            [[ $i = $j ]] && found=1
        done

        [[ $found -eq 0 ]] && return 1
    done

    return 0
}

download_package_lists() {
    baseurl=$mirror/dists/$release/main/binary-armhf/Packages
    extension=""
    decompressor=""

    # First test which extension is supported
    extensions="xz bz2 gz"
    for i in $extensions
    do
        echo -n "Does '${baseurl}.${i}' exists... "
        wget -q --spider ${baseurl}.${i}
        if [ $? -eq 0 ] ; then
            echo "YES"
	    extension=".${i}"
	    break
        else
            echo "NO"
        fi
    done

    # Based on the extension, set the decompressor
    if [ $extension = ".bz2" ] ; then
        decompressor="bunzip2 -c "
    elif [ $extension = ".xz" ] ; then
        decompressor="xzcat "
    elif [ $extension = ".gz" ] ; then
        decompressor="gunzip -c "
    fi

    echo "Using extension '${extension}' and decompressor '${decompressor}' to download packages..."

    wget -O - $mirror/dists/$release/firmware/binary-armhf/Packages${extension} | ${decompressor} > Packages
    wget -O - $mirror/dists/$release/main/binary-armhf/Packages${extension} | ${decompressor} >> Packages
}

rm -rf packages/
mkdir packages
cd packages

download_package_lists

echo "Searching for required packages..."
while read k v
do
    if [ "$k" = "Package:" ]; then
        current_package=$v
    fi

    if [ "$k" = "Filename:" ]; then
        current_filename=$v
    fi

    if [ "$k" = "" ]; then
        if required $current_package; then
            printf "  %-32s %s\n" $current_package `basename $current_filename`
            packages_debs="${mirror}${current_filename} ${packages_debs}"
            packages_found="$current_package $packages_found"
            allfound && break
        fi

        current_package=
        current_filename=
    fi
done < Packages

allfound || exit

wget $packages_debs
cd ..
