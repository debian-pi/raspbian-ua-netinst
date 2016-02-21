#!/usr/bin/env bash

KERNEL_VERSION_RPI1=3.18.0-trunk-rpi
KERNEL_VERSION_RPI2=3.18.0-trunk-rpi2

RASPBIAN_ARCHIVE_KEY_DIRECTORY="https://archive.raspbian.org"
RASPBIAN_ARCHIVE_KEY_FILE_NAME="raspbian.public.key"
RASPBIAN_ARCHIVE_KEY_URL="${RASPBIAN_ARCHIVE_KEY_DIRECTORY}/${RASPBIAN_ARCHIVE_KEY_FILE_NAME}"
RASPBIAN_ARCHIVE_KEY_FINGERPRINT="A0DA38D0D76E8B5D638872819165938D90FDDD2E"

RASPBERRYPI_ARCHIVE_KEY_DIRECTORY="https://archive.raspberrypi.org/debian"
RASPBERRYPI_ARCHIVE_KEY_FILE_NAME="raspberrypi.gpg.key"
RASPBERRYPI_ARCHIVE_KEY_URL="${RASPBERRYPI_ARCHIVE_KEY_DIRECTORY}/${RASPBERRYPI_ARCHIVE_KEY_FILE_NAME}"
RASPBERRYPI_ARCHIVE_KEY_FINGERPRINT="CF8A1AF502A2AA2D763BAE7E82B129927FA3303E"

mirror=http://archive.raspbian.org/raspbian/
release=jessie

packages=()

# programs
packages+=("raspberrypi-bootloader-nokernel")
packages+=("linux-image-${KERNEL_VERSION_RPI1}")
packages+=("linux-image-${KERNEL_VERSION_RPI2}")
packages+=("btrfs-tools")
packages+=("busybox")
packages+=("cdebootstrap-static")
packages+=("dosfstools")
packages+=("dpkg")
packages+=("e2fslibs")
packages+=("e2fsprogs")
packages+=("f2fs-tools")
packages+=("gpgv")
packages+=("ifupdown")
packages+=("iproute2")
packages+=("lsb-base")
packages+=("netbase")
packages+=("ntpdate")
packages+=("raspbian-archive-keyring")
packages+=("tar")
packages+=("util-linux")
packages+=("wpasupplicant")
packages+=("ndisc6")

# libraries
packages+=("libacl1")
packages+=("libatm1")
packages+=("libattr1")
packages+=("libaudit-common")
packages+=("libaudit1")
packages+=("libblkid1")
packages+=("libbz2-1.0")
packages+=("libc-bin")
packages+=("libc6")
packages+=("libcap2")
packages+=("libcomerr2")
packages+=("libdb5.3")
packages+=("libdbus-1-3")
packages+=("libgcc1")
packages+=("liblzma5")
packages+=("liblzo2-2")
packages+=("libmount1")
packages+=("libncurses5")
packages+=("libnl-3-200")
packages+=("libnl-genl-3-200")
packages+=("libpam0g")
packages+=("libpcre3")
packages+=("libpcsclite1")
packages+=("libselinux1")
packages+=("libslang2")
packages+=("libsmartcols1")
packages+=("libssl1.0.0")
packages+=("libtinfo5")
packages+=("libuuid1")
packages+=("zlib1g")

packages_found=
packages_debs=
packages_sha256=

check_key() {
    # param 1 = keyfile
    # param 2 = key fingerprint

    # check input parameters
    if [ -z $1 ] || [ ! -f $1 ] ; then
        echo "Parameter 1 of check_key() is not a file!"
        return 1
    fi

    if [ -z $2 ] ; then
        echo "Parameter 2 of check_key() is not a key fingerprint!"
        return 1
    fi

    KEY_FILE="$1"
    KEY_FINGERPRINT="$2"

    echo -n "Checking key file '${KEY_FILE}'... "

    # check that there is only 1 public key in the key file
    if [ ! $(gpg --homedir gnupg --keyid-format long --with-fingerprint --with-colons ${KEY_FILE} | grep ^pub: | wc -l) -eq 1 ] ; then
        echo "FAILED!"
        echo "There are zero or more than one keys in the ${KEY_FILE} key file!"
        return 1
    fi

    # check that the key file's fingerprint is correct
    if [ "$(gpg --homedir gnupg --keyid-format long --with-fingerprint --with-colons ${KEY_FILE} | grep ^fpr: | awk -F: '{print $10}')" != "${KEY_FINGERPRINT}" ] ; then
        echo "FAILED!"
        echo "Bad GPG key fingerprint for ${KEY_FILE}!"
        return 1
    fi

    echo "OK"
    return 0
}

setup_archive_keys() {

    mkdir -m 0700 -p gnupg
    # Let gpg set itself up already in the 'gnupg' dir before we actually use it
    echo "Setting up gpg... "
    gpg --homedir gnupg --list-secret-keys
    echo ""

    echo "Downloading ${RASPBIAN_ARCHIVE_KEY_FILE_NAME}."
    curl -# -O ${RASPBIAN_ARCHIVE_KEY_URL}
    if check_key "${RASPBIAN_ARCHIVE_KEY_FILE_NAME}" "${RASPBIAN_ARCHIVE_KEY_FINGERPRINT}" ; then
        # GPG key checks out, thus import it into our own keyring
        echo -n "Importing '${RASPBIAN_ARCHIVE_KEY_FILE_NAME}' into keyring... "
        if gpg -q --homedir gnupg --import "${RASPBIAN_ARCHIVE_KEY_FILE_NAME}" ; then
            echo "OK"
        else
            echo "FAILED!"
            return 1
        fi
    else
        return 1
    fi

    echo ""

    echo "Downloading ${RASPBERRYPI_ARCHIVE_KEY_FILE_NAME}."
    curl -# -O ${RASPBERRYPI_ARCHIVE_KEY_URL}
    if check_key "${RASPBERRYPI_ARCHIVE_KEY_FILE_NAME}" "${RASPBERRYPI_ARCHIVE_KEY_FINGERPRINT}" ; then
        # GPG key checks out, thus import it into our own keyring
        echo -n "Importing '${RASPBERRYPI_ARCHIVE_KEY_FILE_NAME}' into keyring..."
        if gpg -q --homedir gnupg --import "${RASPBERRYPI_ARCHIVE_KEY_FILE_NAME}" ; then
            echo "OK"
        else
            echo "FAILED!"
            return 1
        fi
    else
        return 1
    fi

    return 0

}

required() {
    for i in ${packages[@]}; do
        [[ $i = $1 ]] && return 0
    done
    return 1
}

unset_required() {
    for i in ${!packages[@]}; do
        [[ ${packages[$i]} = $1 ]] && unset packages[$i] && return 0
    done
    return 1
}

allfound() {
    [[ ${#packages[@]} -eq 0 ]] && return 0
    return 1
}

filter_package_list() {
    grep -E 'Package:|Filename:|SHA256:|^$'
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

    setup_archive_keys
    if [ $? != 0 ] ; then
        echo -e "ERROR\nSetting up the archives failed! Exiting."
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
    package_section=non-free
    download_package_list
}

rm -rf packages/
mkdir packages
cd packages

download_package_lists

packages_debs=()
packages_sha256=()

echo -e "\nSearching for required packages..."
while read k v
do
    if [ "$k" = "Package:" ]; then
        current_package=$v
    elif [ "$k" = "Filename:" ]; then
        current_filename=$v
    elif [ "$k" = "SHA256:" ]; then
        current_sha256=$v
    elif [ "$k" = "" ]; then
        if required $current_package; then
            printf "  %-32s %s\n" $current_package $(basename $current_filename)
            unset_required $current_package
            packages_debs+=("${mirror}${current_filename}")
            packages_sha256+=("${current_sha256}  $(basename ${current_filename})")
            allfound && break
        fi

        current_package=
        current_filename=
        current_sha256=
    fi
done < <(filter_package_list <Packages)

if ! allfound ; then
    echo "ERROR: Unable to find all required packages in package list!"
    echo "Missing packages: ${packages[@]}"
    cd ..
    exit 1
fi

echo -e "\nDownloading packages..."
curl -# --remote-name-all ${packages_debs[@]}

echo -n "Verifying downloaded packages... "
printf "%s\n" "${packages_sha256[@]}" > SHA256SUMS
if sha256sum --quiet -c SHA256SUMS ; then
    echo "OK"
else
    echo -e "ERROR\nThe checksums of the downloaded packages don't match the package lists!"
    cd ..
    exit 1
fi

cd ..
