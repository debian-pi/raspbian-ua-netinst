#!/usr/bin/env bash
# shellcheck disable=SC1117

KERNEL_VERSION_RPI1=4.9.0-6-rpi
KERNEL_VERSION_RPI2=4.9.0-6-rpi2

RASPBIAN_ARCHIVE_KEY_DIRECTORY="https://archive.raspbian.org"
RASPBIAN_ARCHIVE_KEY_FILE_NAME="raspbian.public.key"
RASPBIAN_ARCHIVE_KEY_URL="${RASPBIAN_ARCHIVE_KEY_DIRECTORY}/${RASPBIAN_ARCHIVE_KEY_FILE_NAME}"
RASPBIAN_ARCHIVE_KEY_FINGERPRINT="A0DA38D0D76E8B5D638872819165938D90FDDD2E"

RASPBERRYPI_ARCHIVE_KEY_DIRECTORY="https://archive.raspberrypi.org/debian"
RASPBERRYPI_ARCHIVE_KEY_FILE_NAME="raspberrypi.gpg.key"
RASPBERRYPI_ARCHIVE_KEY_URL="${RASPBERRYPI_ARCHIVE_KEY_DIRECTORY}/${RASPBERRYPI_ARCHIVE_KEY_FILE_NAME}"
RASPBERRYPI_ARCHIVE_KEY_FINGERPRINT="CF8A1AF502A2AA2D763BAE7E82B129927FA3303E"

mirror_raspbian="http://archive.raspbian.org/raspbian"
mirror_raspberrypi="http://archive.raspberrypi.org/debian"
release=buster

packages=()

# programs
packages+=("raspberrypi-bootloader-nokernel")
packages+=("linux-image-${KERNEL_VERSION_RPI1}")
packages+=("linux-image-${KERNEL_VERSION_RPI2}")
packages+=("firmware-brcm80211")
packages+=("btrfs-progs")
packages+=("busybox")
packages+=("ca-certificates-udeb")
packages+=("cdebootstrap-static")
packages+=("curl")
packages+=("dosfstools")
packages+=("dpkg")
packages+=("e2fsprogs")
packages+=("f2fs-tools")
packages+=("fdisk")
packages+=("gpgv")
packages+=("ifupdown")
packages+=("iproute2")
packages+=("lsb-base")
packages+=("ndisc6")
packages+=("netbase")
packages+=("ntpdate")
packages+=("raspbian-archive-keyring")
packages+=("rng-tools")
packages+=("tar")
packages+=("util-linux")
packages+=("wpasupplicant")

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
packages+=("libcom-err2")
packages+=("libcurl4")
packages+=("libdb5.3")
packages+=("libdbus-1-3")
packages+=("libelf1")
packages+=("libext2fs2")
packages+=("libf2fs5")
packages+=("libfdisk1")
packages+=("libffi6")
packages+=("libgcc1")
packages+=("libgcrypt20")
packages+=("libgmp10")
packages+=("libgnutls30")
packages+=("libgpg-error0")
packages+=("libgssapi-krb5-2")
packages+=("libhogweed4")
packages+=("libidn2-0")
packages+=("libk5crypto3")
packages+=("libkeyutils1")
packages+=("libkrb5-3")
packages+=("libkrb5support0")
packages+=("libldap-2.4-2")
packages+=("liblz4-1")
packages+=("liblzma5")
packages+=("liblzo2-2")
packages+=("libmnl0")
packages+=("libmount1")
packages+=("libnettle6")
packages+=("libnghttp2-14")
packages+=("libnl-3-200")
packages+=("libnl-genl-3-200")
packages+=("libnl-route-3-200")
packages+=("libp11-kit0")
packages+=("libpam0g")
packages+=("libpcre3")
packages+=("libpcsclite1")
packages+=("libpsl5")
packages+=("librtmp1")
packages+=("libsasl2-2")
packages+=("libselinux1")
packages+=("libslang2")
packages+=("libsmartcols1")
packages+=("libssh2-1")
packages+=("libssl1.1")
packages+=("libsystemd0")
packages+=("libtasn1-6")
packages+=("libtinfo6")
packages+=("libudev1")
packages+=("libunistring2")
packages+=("libuuid1")
packages+=("zlib1g")

download_file() {
    local source="$1"
    local target="$2"
    local options=(-q --show-progress --no-cache)
    local wget_retval

    if [ -n "${target}" ] ; then
        options+=(-O "${target}")
    fi
    wget_retval=$(wget "${options[@]}" "${source}")
    if ! $wget_retval ; then
        echo -e "ERROR\nDownloading file '${source}' failed! Exiting."
        exit 1
    fi
}

check_key() {
    # param 1 = keyfile
    # param 2 = key fingerprint
    local gpg_key_count
    local gpg_key_fingerprint

    # check input parameters
    if [ -z "$1" ] || [ ! -f "$1" ] ; then
        echo "Parameter 1 of check_key() is not a file!"
        return 1
    fi

    if [ -z "$2" ] ; then
        echo "Parameter 2 of check_key() is not a key fingerprint!"
        return 1
    fi

    KEY_FILE="$1"
    KEY_FINGERPRINT="$2"

    echo -n "Checking key file '${KEY_FILE}'... "

    # check that there is only 1 public key in the key file
    gpg_key_count=$(gpg --homedir gnupg --keyid-format long --with-fingerprint --with-colons "${KEY_FILE}" | grep -c ^pub:)
    if [ "$gpg_key_count" -ne 1 ] ; then
        echo "FAILED!"
        echo "There are zero or more than one keys in the ${KEY_FILE} key file!"
        return 1
    fi

    # check that the key file's fingerprint is correct
    gpg_key_fingerprint=$(gpg --homedir gnupg --keyid-format long --with-fingerprint --with-colons "${KEY_FILE}" | grep ^fpr: | awk -F: '{print $10}')
    if [ "$gpg_key_fingerprint" != "${KEY_FINGERPRINT}" ] ; then
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
    download_file "${RASPBIAN_ARCHIVE_KEY_URL}"
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
    download_file "${RASPBERRYPI_ARCHIVE_KEY_URL}"
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
    for i in "${packages[@]}"; do
        [[ $i = "$1" ]] && return 0
    done
    return 1
}

unset_required() {
    for i in "${!packages[@]}"; do
        [[ ${packages[$i]} = "$1" ]] && unset 'packages[$i]' && return 0
    done
    return 1
}

allfound() {
    [[ ${#packages[@]} -eq 0 ]] && return 0
    return 1
}

filter_package_list() {
    awk -v p="${packages[*]}" 'BEGIN{ split(p, packages) } /^Package:/{ flag=0; for (i in packages) if ($2 == packages[i]) flag=1 }; flag{ print }'
}

download_package_list() {
    # Download and verify package list for $package_section, then add to Packages file
    # Assume that the repository's base Release file is present
    local source="$1"
    local base_url="$2"
    local sha256_calc_val_pkg_file
    local sha256_val_from_release_file

    extensions=( '.xz' '.bz2' '.gz' '' )
    for extension in "${extensions[@]}" ; do

        # Check that this extension is available
        if grep -q "${package_section}/binary-armhf/Packages${extension}" "${source}_Release" ; then

            # Download Packages file
            echo -e "\nDownloading ${package_section} package list..."
            if ! download_file "${base_url}/dists/${release}/${package_section}/binary-armhf/Packages${extension}" "Packages${extension}" ; then
                echo -e "ERROR\nDownloading '${package_section}' package list failed! Exiting."
                cd ..
                exit 1
            fi

            # Verify the checksum of the Packages file, assuming that the last checksums in the Release file are SHA256 sums
            sha256_val_from_release_file=$(grep "${package_section}/binary-armhf/Packages${extension}" "${source}_Release" | tail -n1 | awk '{print $1}')
            echo "SHA256 of Packages${extension} from Release file: " "$sha256_val_from_release_file"
            sha256_calc_val_pkg_file=$(sha256sum "Packages${extension}" | awk '{print $1}')
            echo "SHA256 calculated on Packages${extension}:        " "$sha256_calc_val_pkg_file"

            echo -n "Verifying ${package_section} package list... "
            if [ "$sha256_val_from_release_file" = "$sha256_calc_val_pkg_file" ] ; then
                echo "OK"
            else
                echo -e "ERROR\nThe checksum of file '${package_section}/binary-armhf/Packages${extension}' doesn't match!"
                cd ..
                exit 1
            fi

            # Decompress the Packages file
            if [ "${extension}" = ".bz2" ] ; then
                decompressor="bunzip2 -c "
            elif [ "${extension}" = ".xz" ] ; then
                decompressor="xzcat "
            elif [ "${extension}" = ".gz" ] ; then
                decompressor="gunzip -c "
            elif [ "${extension}" = "" ] ; then
                decompressor="cat "
            fi
            ${decompressor} "Packages${extension}" >> "${source}_Packages"
            rm "Packages${extension}"
            break
        fi
    done
}

download_package_lists() {
    local source="$1"
    local base_url="$2"
    local gpg_release_verify_retval

    echo -e "\nDownloading Release file and its signature..."
    download_file "${base_url}/dists/$release/Release" "${source}_Release"
    download_file "${base_url}/dists/$release/Release.gpg" "${source}_Release.gpg"
    echo -n "Verifying Release file... "
    gpg_release_verify_retval=$(gpg --homedir gnupg --verify "${source}_Release.gpg" "${source}_Release" &> /dev/null)
    if $gpg_release_verify_retval ; then
        echo "OK"
    else
        echo -e "ERROR\nBroken GPG signature on Release file!"
        cd ..
        exit 1
    fi

    echo -n > "${source}_Packages"

    for package_section in firmware main non-free main/debian-installer; do
        download_package_list "${source}" "${base_url}"
    done
}

search_for_packages() {
    local source="$1"
    local base_url="$2"

    while read -r k v
    do
        if [ "${k}" = "Package:" ] ; then
            current_package="${v}"
        elif [ "${k}" = "Filename:" ] ; then
            current_filename="${v}"
        elif [ "${k}" = "SHA256:" ] ; then
            current_sha256="${v}"
        elif [ "${k}" = "" ] ; then
            if required "$current_package" ; then
                printf "  %-32s %s\n" "${current_package}" "$(basename "${current_filename}")"
                unset_required "${current_package}"
                packages_debs+=("${base_url}/${current_filename}")
                packages_sha256+=("${current_sha256} $(basename "${current_filename}")")
                allfound && break
            fi

            current_package=
            current_filename=
            current_sha256=
        fi
    done < <(filter_package_list <"${source}_Packages")
}

download_packages() {
    local wget_retval
    #echo "Files to download:"
    #echo "${packages_debs[@]}"
    echo -e "\nDownloading packages..."
    wget_retval=$(wget -q --show-progress --no-cache -- "${packages_debs[@]}")
    if ! $wget_retval ; then
        echo -e "ERROR\nDownloading packages failed! Exiting."
        cd ..
        exit 1
    fi
    
    echo -ne "\nVerifying downloaded packages... "
    printf "%s\n" "${packages_sha256[@]}" > SHA256SUMS
    if sha256sum --quiet -c SHA256SUMS; then
        echo "OK"
    else
        echo -e "ERROR\nThe checksums of the downloaded packages don't match the package lists!"
        cd ..
        exit 1
    fi
}

# Setup
rm -rf packages/
mkdir packages/ && cd packages || exit 1

if ! setup_archive_keys ; then
    echo -e "ERROR\nSetting up the archives failed! Exiting."
    exit 1
fi

## Download package list
download_package_lists raspberry "${mirror_raspberrypi}"
download_package_lists raspbian "${mirror_raspbian}"

## Select packages for download
echo -e "\nSearching for required packages..."

packages_debs=()
packages_sha256=()

search_for_packages raspberry "${mirror_raspberrypi}"
search_for_packages raspbian "${mirror_raspbian}"

if ! allfound ; then
    echo "ERROR: Unable to find all required packages in package list!"
    echo "Missing packages: " "${packages[@]}"
    cd ..
    exit 1
fi

## Download selected packages
download_packages

cd ..
