#!/bin/bash

KERNEL_VERSION=3.10-3-rpi

mirror=http://archive.raspbian.org/raspbian/
release=jessie
packages="busybox-static libc6 cdebootstrap-static e2fslibs e2fsprogs libcomerr2 libblkid1 libuuid1 libgcc1 dosfstools linux-image-${KERNEL_VERSION} raspberrypi-bootloader-nokernel f2fs-tools btrfs-tools zlib1g liblzo2-2"
packages_found=
packages_debs=
packages_sha256=

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

download_package_list() {
    # Download and verify package list for $package_section, then add to Packages file
    # Assume that the repository's base Release file is present

    extensions=( '.xz' '.bz2' '.gz' '' )
    for extension in "${extensions[@]}" ; do

        # Check that this extension is available
        if grep -q ${package_section}/binary-armhf/Packages${extension} Release ; then

            # Download Packages file
            wget -O tmp${extension} $mirror/dists/$release/$package_section/binary-armhf/Packages${extension}

            # Verify the checksum of the Packages file, assuming that the last checksums in the Release file are SHA256 sums
            if [ $(grep ${package_section}/binary-armhf/Packages${extension} Release | tail -n1 | awk '{print $1}') != \
                 $(sha256sum tmp${extension} | awk '{print $1}') ]; then
                echo "WARNING: The checksum of the ${package_section}/binary-armhf/Packages${extension} file doesn't match."
                read -p "Ignore and continue (not recommended) [y/n]? " ignore_verification
                if [ "$ignore_verification" != "y" ]; then
                    cd ..
                    exit 1
                fi
            fi

            # Decompress the Packages file
            if [ $extension = ".bz2" ] ; then
                decompressor="bunzip2 -c "
            elif [ $extension = ".xz" ] ; then
                decompressor="xzcat "
            elif [ $extension = ".gz" ] ; then
                decompressor="gunzip -c "
            elif [ $extension = "" ] ; then
                decompressor="cat "
            fi
            ${decompressor} tmp${extension} >> Packages
            rm tmp${extension}
            break
        fi
    done
}

download_package_lists() {

    # Download and verify the base Release file
    wget $mirror/dists/$release/Release $mirror/dists/$release/Release.gpg
    if ! gpg --verify Release.gpg Release; then
        echo "WARNING: Cannot verify GPG signature of Release file."
        read -p "Ignore and continue (not recommended) [y/n]? " ignore_verification
        if [ "$ignore_verification" != "y" ]; then
            cd ..
            exit 1
        fi
    fi

    # Get, verify, extract, and concatenate the Packages files
    echo -n > Packages
    package_section=firmware
    download_package_list
    package_section=main
    download_package_list
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

    if [ "$k" = "SHA256:" ]; then
        current_sha256=$v
    fi

    if [ "$k" = "" ]; then
        if required $current_package; then
            printf "  %-32s %s\n" $current_package `basename $current_filename`
            packages_debs="${mirror}${current_filename} ${packages_debs}"
            packages_sha256="${current_sha256}  $(basename ${current_filename})\n${packages_sha256}"
            packages_found="$current_package $packages_found"
            allfound && break
        fi

        current_package=
        current_filename=
    fi
done < Packages

allfound || exit

wget $packages_debs

echo "Verifying checksums of downloaded .deb packages..."
echo -ne "${packages_sha256}" > SHA256SUMS
sha256sum --quiet -c SHA256SUMS

cd ..
