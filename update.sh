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
packages="$packages busybox"
packages="$packages cdebootstrap-static"
packages="$packages dosfstools"
packages="$packages dpkg"
packages="$packages e2fslibs"
packages="$packages e2fsprogs"
packages="$packages f2fs-tools"
packages="$packages gpgv"
packages="$packages raspbian-archive-keyring"
packages="$packages tar"

# libraries
packages="$packages libacl1"
packages="$packages libattr1"
packages="$packages libblkid1"
packages="$packages libbz2-1.0"
packages="$packages libc-bin"
packages="$packages libc6"
packages="$packages libcap2"
packages="$packages libcomerr2"
packages="$packages libgcc1"
packages="$packages liblzma5"
packages="$packages liblzo2-2"
packages="$packages libmount1"
packages="$packages libncurses5"
packages="$packages libpcre3"
packages="$packages libselinux1"
packages="$packages libsmartcols1"
packages="$packages libtinfo5"
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
    echo "Downloading and importing raspbian.public.key..."
    curl -# -O https://archive.raspbian.org/raspbian.public.key
    gpg -q --homedir gnupg --import raspbian.public.key
    echo -n "Verifying raspbian.public.key... "
    if gpg --homedir gnupg -k 0xA0DA38D0D76E8B5D638872819165938D90FDDD2E &> /dev/null ; then
        echo "OK"
    else
        echo -e "ERROR\nBad GPG key fingerprint for raspbian.org!"
        cd ..
        exit 1
    fi
    echo -e "\nDownloading and importing raspberrypi.gpg.key..."
    curl -# -O http://archive.raspberrypi.org/debian/raspberrypi.gpg.key
    gpg -q --homedir gnupg --import raspberrypi.gpg.key
    echo -n "Verifying raspberrypi.gpg.key... "
    if gpg --homedir gnupg -k 0xCF8A1AF502A2AA2D763BAE7E82B129927FA3303E &> /dev/null ; then
        echo "OK"
    else
        echo -e "ERROR\nBad GPG key fingerprint for raspberrypi.org!"
        cd ..
        exit 1
    fi

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

cd ..
