#!/usr/bin/env bash

KERNEL_VERSION_RPI1=3.18.0-trunk-rpi
KERNEL_VERSION_RPI2=3.18.0-trunk-rpi2

mirror=http://archive.raspbian.org/raspbian/
release=jessie

# programs
packages="$packages raspberrypi-bootloader-nokernel"
packages="$packages linux-image-${KERNEL_VERSION_RPI1}"
packages="$packages linux-image-${KERNEL_VERSION_RPI2}"
packages="$packages btrfs-tools"
packages="$packages busybox-static"
packages="$packages cdebootstrap-static"
packages="$packages dosfstools"
packages="$packages e2fslibs"
packages="$packages e2fsprogs"
packages="$packages f2fs-tools"
packages="$packages gpgv"
packages="$packages raspbian-archive-keyring"

# libraries
packages="$packages libblkid1"
packages="$packages libbz2-1.0"
packages="$packages libc6"
packages="$packages libcomerr2"
packages="$packages libgcc1"
packages="$packages liblzo2-2"
packages="$packages libuuid1"
packages="$packages zlib1g"

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
            echo -e "\nDownloading ${package_section} package list..."
            curl -# -o tmp${extension} $mirror/dists/$release/$package_section/binary-armhf/Packages${extension}

            # Verify the checksum of the Packages file, assuming that the last checksums in the Release file are SHA256 sums
            echo -n "Verifying ${package_section} package list... "
            if [ $(grep ${package_section}/binary-armhf/Packages${extension} Release | tail -n1 | awk '{print $1}') = \
                 $(sha256sum tmp${extension} | awk '{print $1}') ]; then
                echo "OK"
            else
                echo -e "ERROR\nThe checksum of the ${package_section}/binary-armhf/Packages${extension} file doesn't match!"
                cd ..
                exit 1
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

    mkdir -p gnupg
    chmod 0700 gnupg
    echo "Importing PGP keys..."
    gpg -q --homedir gnupg --import ../keys/raspbian.public.key
    gpg -q --homedir gnupg --import ../keys/raspberrypi.gpg.key

    echo -e "\nDownloading Release file and its signature..."
    curl -# -O $mirror/dists/$release/Release -O $mirror/dists/$release/Release.gpg
    echo -n "Verifying Release file... "
    if gpg --homedir gnupg --verify Release.gpg Release &> /dev/null ; then
        echo "OK"
    else
        echo -e "ERROR\nBroken GPG signature on Release file!"
        cd ..
        exit 1
    fi

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

echo -e "\nSearching for required packages..."
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
        current_sha256=
    fi
done < Packages

if ! allfound ; then
    echo "ERROR: Unable to find all required packages in package list!"
    cd ..
    exit 1
fi

echo -e "\nDownloading packages..."
curl -# --remote-name-all $packages_debs

echo -n "Verifying downloaded packages... "
echo -ne "${packages_sha256}" > SHA256SUMS
if sha256sum --quiet -c SHA256SUMS ; then
    echo "OK"
else
    echo -e "ERROR\nThe checksums of the downloaded packages don't match the package lists!"
    cd ..
    exit 1
fi

# ugly workaround for non-working busybox-static in jessie
echo -n "Copying older, but working, version of busybox as a workaround... "
rm busybox-static_*
bbfilename=busybox-static_1.20.0-7_armhf.deb
curl -s -o $bbfilename https://raw.githubusercontent.com/debian-pi/general/master/workarounds/busybox-static_1.20.0-7_armhf.deb
# test whether the file exists and it's size is > 100k
if [ -f $bbfilename ] && [ $(wc -c < $bbfilename) -gt 100000 ] ; then
    echo "OK"
else
    echo "FAILED"
    echo -e "ERROR\nThe download of busybox-static failed, thus the rest will also fail!"
    cd ..
    exit 1
fi

cd ..
