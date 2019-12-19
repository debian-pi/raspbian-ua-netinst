#!/usr/bin/env bash

set -e

# configuration
KERNEL_VERSION_RPI1=4.9.0-6-rpi
KERNEL_VERSION_RPI2=4.9.0-6-rpi2

INSTALL_MODULES=("kernel/fs/btrfs/btrfs.ko")
INSTALL_MODULES+=("kernel/drivers/scsi/sg.ko")
INSTALL_MODULES+=("kernel/drivers/char/hw_random/bcm2835-rng.ko")
INSTALL_MODULES+=("kernel/net/ipv6/ipv6.ko")
INSTALL_MODULES+=("kernel/net/wireless/cfg80211.ko")

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
    for mod in "${mods[@]}"; do
        # find the modules dependencies, convert into array
        deps=($(grep "^${mod}" "${depmod_file}" | cut -d':' -f2))
        # iterate over the found dependencies
        for dep in "${deps[@]}"; do
            # check if the dependency is in $modules, if not, add to temp array
            contains_element "${dep}" "${modules[@]}" || new_found+=("${dep}")
        done
    done
    # add the newly found dependencies to the end of the $modules array
    modules+=("${new_found[@]}")
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
    local tmp_ptrn
    tmp_ptrn="/tmp/$(basename "${0}").${$}"
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

# copies kernel modules into the rootfs
#   use: add_kernel_modules "rpi-target-version"
function add_kernel_modules {
    local KERNEL_VERSION=""

    case "$1" in
        "rpi1")
            KERNEL_VERSION=$KERNEL_VERSION_RPI1
            ;;
        "rpi2")
            KERNEL_VERSION=$KERNEL_VERSION_RPI2
            ;;
        *)
            echo "Invalid parameter to 'add_kernel_modules' function!"
            exit 1
    esac

    # copy builtin modules
    mkdir -p rootfs/lib/modules/${KERNEL_VERSION}/
    cp -a tmp/lib/modules/${KERNEL_VERSION}/modules.{builtin,order} rootfs/lib/modules/${KERNEL_VERSION}/

    # copy drivers
    mkdir -p rootfs/lib/modules/$KERNEL_VERSION/kernel/drivers/net/
    cp -r tmp/lib/modules/$KERNEL_VERSION/kernel/drivers/net/{wireless,usb} rootfs/lib/modules/$KERNEL_VERSION/kernel/drivers/net/

    # calculate module dependencies
    depmod_file=$(create_tempfile)
    /sbin/depmod -nab tmp ${KERNEL_VERSION} > "${depmod_file}"

    modules=("${INSTALL_MODULES[@]}")

    # new_count contains the number of new elements in the $modules array for each iteration
    new_count=${#modules[@]}
    # repeat the hunt for dependencies until no new ones are found (the loop takes care
    # of finding nested dependencies)
    until [ "${new_count}" == 0 ]; do
        # check the dependencies for the modules in the last $new_count elements
        check_dependencies "${modules[@]:$((${#modules[@]}-${new_count}))}"
    done

    # do some cleanup
    rm -f "${depmod_file}"

    # copy the needed kernel modules to the rootfs (create directories as needed)
    srcdir="tmp/lib/modules/${KERNEL_VERSION}"
    dstdir="rootfs/lib/modules/${KERNEL_VERSION}"
    for module in "${modules[@]}"; do
        mkdir -p "${dstdir}/$(dirname "${module}")"
        cp -a "${srcdir}/${module}" "${dstdir}/$(dirname "${module}")"
    done

    /sbin/depmod -a -b rootfs ${KERNEL_VERSION}
}

function create_cpio {
    local INITRAMFS="$1"
    
    # initialize rootfs
    rm -rf rootfs
    mkdir -p rootfs
    
    # create all the directories needed to copy the various components into place
    mkdir -p rootfs/bin/
    mkdir -p rootfs/lib/arm-linux-gnueabihf/
    mkdir -p rootfs/lib/lsb/init-functions.d/
    mkdir -p rootfs/etc/{alternatives,cron.daily,default,init,init.d,iproute2,ld.so.conf.d,logrotate.d,network/if-up.d/,ssl/certs}
    mkdir -p rootfs/etc/dpkg/dpkg.cfg.d/
    mkdir -p rootfs/etc/network/{if-down.d,if-post-down.d,if-pre-up.d,if-up.d,interfaces.d}
    mkdir -p rootfs/lib/ifupdown/
    mkdir -p rootfs/lib/lsb/init-functions.d/
    mkdir -p rootfs/sbin/
    mkdir -p rootfs/usr/bin/
    mkdir -p rootfs/usr/lib/mime/packages/
    mkdir -p rootfs/usr/lib/engines-1.1/
    mkdir -p rootfs/usr/lib/{ssl,tar,tc}
    mkdir -p rootfs/usr/sbin/
    mkdir -p rootfs/usr/share/{dpkg,keyrings,libc-bin}
    mkdir -p rootfs/var/lib/dpkg/{alternatives,info,parts,updates}
    mkdir -p rootfs/var/lib/ntpdate
    mkdir -p rootfs/var/log/
    mkdir -p rootfs/var/run/

    # add kernel modules
    add_kernel_modules "rpi1"
    add_kernel_modules "rpi2"

    # install scripts
    cp -r scripts/* rootfs/

    # update version and date
    sed -i "s/__VERSION__/git~$(git rev-parse --short "@{0}")/" rootfs/etc/init.d/rcS
    sed -i "s/__DATE__/$(date)/" rootfs/etc/init.d/rcS

    # add firmware for wireless chipset (RPi 3 and Zero W)
    mkdir -p rootfs/lib/firmware/brcm
    cp tmp/lib/firmware/brcm/brcmfmac43430-sdio.{bin,txt} rootfs/lib/firmware/brcm

    # btrfs-progs components
    cp tmp/bin/mkfs.btrfs rootfs/bin/

    # busybox components
    cp tmp/bin/busybox rootfs/bin
    ln -s bin/busybox rootfs/init

    # ca-certificates-udeb components
    cp tmp/etc/ssl/certs/* rootfs/etc/ssl/certs/
    cd rootfs/usr/lib/ssl
    ln -s ../../../etc/ssl/certs certs 
    cd ../../../..

    # cdebootstrap-static components
    cp -r tmp/usr/share/cdebootstrap-static rootfs/usr/share/
    cp tmp/usr/bin/cdebootstrap-static rootfs/usr/bin/

    # curl components
    cp tmp/usr/bin/curl rootfs/usr/bin/

    # dosfstools components
    cp tmp/sbin/fatlabel rootfs/sbin/
    cp tmp/sbin/fsck.fat rootfs/sbin/
    cp tmp/sbin/mkfs.fat rootfs/sbin/
    cd rootfs/sbin
    ln -s fatlabel dosfslabel
    ln -s fsck.fat dosfsck
    ln -s fsck.fat fsck.msdos
    ln -s fsck.fat fsck.vfat
    ln -s mkfs.fat mkdosfs
    ln -s mkfs.fat mkfs.msdos
    ln -s mkfs.fat mkfs.vfat
    cd ../..

    # dpkg components
    cp tmp/etc/alternatives/README rootfs/etc/alternatives/
    cp tmp/etc/cron.daily/dpkg rootfs/etc/cron.daily/
    cp tmp/etc/dpkg/dpkg.cfg rootfs/etc/dpkg/
    cp tmp/etc/logrotate.d/dpkg rootfs/etc/logrotate.d/
    cp tmp/sbin/start-stop-daemon rootfs/sbin/
    cp tmp/usr/bin/dpkg rootfs/usr/bin/
    cp tmp/usr/bin/dpkg-deb rootfs/usr/bin/
    cp tmp/usr/bin/dpkg-divert rootfs/usr/bin/
    cp tmp/usr/bin/dpkg-maintscript-helper rootfs/usr/bin/
    cp tmp/usr/bin/dpkg-query rootfs/usr/bin/
    cp tmp/usr/bin/dpkg-split rootfs/usr/bin/
    cp tmp/usr/bin/dpkg-statoverride rootfs/usr/bin/
    cp tmp/usr/bin/dpkg-trigger rootfs/usr/bin/
    cp tmp/usr/bin/update-alternatives rootfs/usr/bin/
    cp tmp/usr/share/dpkg/abitable rootfs/usr/share/dpkg/
    cp tmp/usr/share/dpkg/cputable rootfs/usr/share/dpkg/
    cp tmp/usr/share/dpkg/ostable rootfs/usr/share/dpkg/
    cp tmp/usr/share/dpkg/tupletable rootfs/usr/share/dpkg/
    cd rootfs/usr/sbin
    ln -s ../bin/dpkg-divert dpkg-divert
    ln -s ../bin/dpkg-statoverride dpkg-statoverride
    ln -s ../bin/update-alternatives update-alternatives
    cd ../../..
    touch rootfs/var/lib/dpkg/status

    # libext2fs2 components
    cp tmp/lib/*/libe2p.so.2.* rootfs/lib/libe2p.so.2
    cp tmp/lib/*/libext2fs.so.2.*  rootfs/lib/libext2fs.so.2

    # e2fsprogs components
    cp tmp/etc/mke2fs.conf rootfs/etc/
    cp tmp/sbin/badblocks rootfs/sbin/
    cp tmp/sbin/debugfs rootfs/sbin/
    cp tmp/sbin/dumpe2fs rootfs/sbin/
    cp tmp/sbin/e2fsck rootfs/sbin/
    cp tmp/sbin/e2image rootfs/sbin/
    cp tmp/sbin/e2undo rootfs/sbin/
    cp tmp/sbin/logsave rootfs/sbin/
    cp tmp/sbin/mke2fs rootfs/sbin/
    cp tmp/sbin/resize2fs rootfs/sbin/
    cp tmp/sbin/tune2fs rootfs/sbin/
    cp tmp/usr/bin/chattr rootfs/usr/bin/
    cp tmp/usr/bin/lsattr rootfs/usr/bin/
    cp tmp/usr/sbin/e2freefrag rootfs/usr/sbin/
    cp tmp/usr/sbin/e4defrag rootfs/usr/sbin/
    cp tmp/usr/sbin/filefrag rootfs/usr/sbin/
    cp tmp/usr/sbin/mklost+found rootfs/usr/sbin/
    cd rootfs/sbin
    ln -s tune2fs e2lablel
    ln -s e2fsck fsck.ext2
    ln -s e2fsck fsck.ext3
    ln -s e2fsck fsck.ext4
    ln -s e2fsck fsck.ext4dev
    ln -s mke2fs mkfs.ext2
    ln -s mke2fs mkfs.ext3
    ln -s mke2fs mkfs.ext4
    ln -s mke2fs mkfs.ext4dev
    cd ../..

    # f2fs-tools components
    cp tmp/sbin/mkfs.f2fs rootfs/sbin/

    # fdisk components
    cp tmp/sbin/fdisk rootfs/sbin/

    # gpgv components
    cp tmp/usr/bin/gpgv rootfs/usr/bin/

    # ifupdown components
    cp tmp/etc/default/networking rootfs/etc/default/
    cp tmp/etc/init.d/networking rootfs/etc/init.d/
    cp tmp/lib/ifupdown/settle-dad.sh rootfs/lib/ifupdown/
    cp tmp/lib/ifupdown/wait-for-ll6.sh rootfs/lib/ifupdown/
    cp tmp/lib/ifupdown/wait-online.sh rootfs/lib/ifupdown/
    cp tmp/sbin/ifup rootfs/sbin/
    cd rootfs/sbin
    ln -s ifup ifdown
    ln -s ifup ifquery
    cd ../..

    # iproute2 components
    cp tmp/bin/ip rootfs/bin/
    cp tmp/bin/ss rootfs/bin/
    cp tmp/etc/iproute2/ematch_map rootfs/etc/iproute2/
    cp tmp/etc/iproute2/group rootfs/etc/iproute2/
    cp tmp/etc/iproute2/rt_dsfield rootfs/etc/iproute2/
    cp tmp/etc/iproute2/rt_protos rootfs/etc/iproute2/
    cp tmp/etc/iproute2/rt_realms rootfs/etc/iproute2/
    cp tmp/etc/iproute2/rt_scopes rootfs/etc/iproute2/
    cp tmp/etc/iproute2/rt_tables rootfs/etc/iproute2/
    cp tmp/sbin/bridge rootfs/sbin/
    cp tmp/sbin/rtacct rootfs/sbin/
    cp tmp/sbin/rtmon rootfs/sbin/
    cp tmp/sbin/tc rootfs/sbin/
    cd rootfs/sbin
    ln -s ../bin/ip ip
    cd ../..
    cp tmp/usr/bin/lnstat rootfs/usr/bin/
    cp tmp/usr/bin/nstat rootfs/usr/bin/
    cp tmp/usr/bin/routef rootfs/usr/bin/
    cp tmp/usr/bin/routel rootfs/usr/bin/
    cd rootfs/usr/bin
    ln -s lnstat ctstat
    ln -s lnstat rtstat
    cd ../../..
    cp tmp/usr/lib/tc/experimental.dist rootfs/usr/lib/tc
    cp tmp/usr/lib/tc/m_xt.so rootfs/usr/lib/tc
    cp tmp/usr/lib/tc/normal.dist rootfs/usr/lib/tc
    cp tmp/usr/lib/tc/pareto.dist rootfs/usr/lib/tc
    cp tmp/usr/lib/tc/paretonormal.dist rootfs/usr/lib/tc
    cp tmp/usr/lib/tc/q_atm.so rootfs/usr/lib/tc
    cd rootfs/usr/lib/tc
    ln -s m_xt.so m_ipt.so
    cd ../../../..
    cp tmp/usr/sbin/arpd rootfs/usr/sbin/

    # ndisc6 components
    cp tmp/bin/rdisc6 rootfs/bin

    # lsb-base components
    cp tmp/lib/lsb/init-functions rootfs/lib/lsb/
    cp tmp/lib/lsb/init-functions.d/20-left-info-blocks rootfs/lib/lsb/init-functions.d/

    # netbase components
    cp tmp/etc/protocols rootfs/etc/
    cp tmp/etc/rpc rootfs/etc/
    cp tmp/etc/services rootfs/etc/

    # ntpdate components
    cp tmp/etc/default/ntpdate rootfs/etc/default/
    # don't use /etc/ntp.conf since we don't have it
    sed -i s/NTPDATE_USE_NTP_CONF=yes/NTPDATE_USE_NTP_CONF=no/ rootfs/etc/default/ntpdate
    cp tmp/usr/sbin/ntpdate rootfs/usr/sbin/
    cp tmp/usr/sbin/ntpdate-debian rootfs/usr/sbin/

    # raspberrypi.org GPG key
    cp packages/raspberrypi.gpg.key rootfs/usr/share/keyrings/

    # raspbian-archive-keyring components
    cp tmp/usr/share/keyrings/raspbian-archive-keyring.gpg rootfs/usr/share/keyrings/

    # rng-tools components
    cp tmp/usr/bin/rngtest rootfs/usr/bin/
    cp tmp/usr/sbin/rngd rootfs/usr/sbin/
    cp tmp/etc/default/rng-tools rootfs/etc/default/
    cp tmp/etc/init.d/rng-tools rootfs/etc/init.d/

    # tar components
    cp tmp/bin/tar rootfs/bin/
    cp tmp/etc/rmt rootfs/etc/
    cp tmp/usr/lib/mime/packages/tar rootfs/usr/lib/mime/packages/
    cp tmp/usr/sbin/rmt-tar rootfs/usr/sbin/
    cp tmp/usr/sbin/tarcat rootfs/usr/sbin/

    # util-linux components
    cp tmp/sbin/blkid rootfs/sbin/
    cp tmp/sbin/blockdev rootfs/sbin/
    cp tmp/sbin/fsck rootfs/sbin/
    cp tmp/sbin/mkswap rootfs/sbin/
    cp tmp/sbin/swaplabel rootfs/sbin/

    # wpa_supplicant components
    cp tmp/sbin/wpa_supplicant rootfs/sbin/wpa_supplicant
    cp -r tmp/etc/wpa_supplicant rootfs/etc/wpa_supplicant

    # libacl1 components
    cp tmp/usr/lib/*/libacl.so.1.* rootfs/usr/lib/libacl.so.1

    # libatm1 components
    cp tmp/lib/*/libatm.so.1.* rootfs/lib/libatm.so.1

    # libattr1 components
    cp tmp/usr/lib/*/libattr.so.1.* rootfs/usr/lib/libattr.so.1

    # libaudit-common components
    cp tmp/etc/libaudit.conf rootfs/etc/

    # libaudit1 components
    cp tmp/lib/*/libaudit.so.1.* rootfs/lib/libaudit.so.1

    # libblkid1 components
    cp tmp/lib/*/libblkid.so.1.* rootfs/lib/libblkid.so.1

    # libbz2-1.0 components
    cp tmp/lib/*/libbz2.so.1.0.* rootfs/lib/libbz2.so.1.0

    # libc-bin components
    cp tmp/etc/default/nss rootfs/etc/default/
    cp tmp/etc/ld.so.conf.d/libc.conf rootfs/etc/ld.so.conf.d/
    cp tmp/etc/bindresvport.blacklist rootfs/etc/
    cp tmp/etc/gai.conf rootfs/etc/
    cp tmp/etc/ld.so.conf rootfs/etc/
    cp tmp/sbin/ldconfig rootfs/sbin/
    cp tmp/usr/bin/catchsegv rootfs/usr/bin/
    cp tmp/usr/bin/getconf rootfs/usr/bin/
    cp tmp/usr/bin/getent rootfs/usr/bin/
    cp tmp/usr/bin/iconv rootfs/usr/bin/
    cp tmp/usr/bin/ldd rootfs/usr/bin/
    cp tmp/usr/bin/locale rootfs/usr/bin/
    cp tmp/usr/bin/localedef rootfs/usr/bin/
    cp tmp/usr/bin/pldd rootfs/usr/bin/
    cp tmp/usr/bin/tzselect rootfs/usr/bin/
    cp tmp/usr/bin/zdump rootfs/usr/bin/
    # lib/locale ?
    cp tmp/usr/sbin/iconvconfig rootfs/usr/sbin/
    cp tmp/usr/sbin/zic rootfs/usr/sbin/
    cp tmp/usr/share/libc-bin/nsswitch.conf rootfs/usr/share/libc-bin/

    # libc6 components
    cp tmp/lib/*/ld-*.so rootfs/lib/ld-linux-armhf.so.3
    # some executables require the dynamic linker to be found
    # at this path, so leave a symlink there
    ln -s /lib/ld-linux-armhf.so.3 rootfs/lib/arm-linux-gnueabihf/ld-linux.so.3
    cp tmp/lib/*/libanl-*.so rootfs/lib/libanl.so.1
    cp tmp/lib/*/libBrokenLocale-*.so rootfs/lib/libBrokenLocale.so.1
    cp tmp/lib/*/libc-*.so rootfs/lib/libc.so.6
    cp tmp/lib/*/libcrypt-*.so rootfs/lib/libcrypt.so.1
    cp tmp/lib/*/libdl-*.so rootfs/lib/libdl.so.2
    cp tmp/lib/*/libm-*.so  rootfs/lib/libm.so.6
    cp tmp/lib/*/libmemusage.so rootfs/lib/
    cp tmp/lib/*/libnsl-*.so rootfs/lib/libnsl.so.1
    cp tmp/lib/*/libnss_compat-*.so rootfs/lib/libnss_compat.so.2
    cp tmp/lib/*/libnss_dns-*.so rootfs/lib/libnss_dns.so.2
    cp tmp/lib/*/libnss_files-*.so rootfs/lib/libnss_files.so.2
    cp tmp/lib/*/libnss_hesiod-*.so rootfs/lib/libnss_hesiod.so.2
    cp tmp/lib/*/libnss_nis-*.so rootfs/lib/libnss_nis.so.2
    cp tmp/lib/*/libnss_nisplus-*.so rootfs/lib/libnss_nisplus.so.2
    cp tmp/lib/*/libpcprofile.so rootfs/lib/
    cp tmp/lib/*/libpthread-*.so rootfs/lib/libpthread.so.0
    cp tmp/lib/*/libresolv-*.so rootfs/lib/libresolv.so.2
    cp tmp/lib/*/librt-*.so rootfs/lib/librt.so.1
    cp tmp/lib/*/libSegFault.so rootfs/lib/
    cp tmp/lib/*/libthread_db-*.so rootfs/lib/libthread_db.so.1
    cp tmp/lib/*/libutil-*.so rootfs/lib/libutil.so.1

    # libcap2 components
    cp tmp/lib/*/libcap.so.2.* rootfs/lib/libcap.so.2

    # libcom-err2 components
    cp tmp/lib/*/libcom_err.so.2.* rootfs/lib/libcom_err.so.2

    # libcurl4 components
    cp tmp/usr/lib/*/libcurl.so.4.* rootfs/usr/lib/libcurl.so.4

    # libdb5.3 components
    cp tmp/usr/lib/*/libdb-5.3.so rootfs/usr/lib/libdb5.3.so

    # libdbus-1-3 components
    cp tmp/lib/*/libdbus-1.so.3 rootfs/lib/libdbus-1.so.3
    cp tmp/lib/*/libdl.so.2 rootfs/lib/libdl.so.2

    # libelf1 components
    cp tmp/usr/lib/*/libelf-0.*.so rootfs/usr/lib/libelf.so.1

    # libf2fs5 components
    cp tmp/lib/*/libf2fs.so.5  rootfs/lib/

    # libfdisk1 components
    cp tmp/lib/*/libfdisk.so.1.* rootfs/lib/libfdisk.so.1

    # libffi6 components
    cp tmp/usr/lib/*/libffi.so.6.* rootfs/usr/lib/libffi.so.6

    # libgcc1 components
    cp tmp/lib/*/libgcc_s.so.1 rootfs/lib/
    cp tmp/lib/*/librt.so.1 rootfs/lib/

    # libgcrypt20 components
    cp tmp/lib/*/libgcrypt.so.20.* rootfs/lib/libgcrypt.so.20

    # libgmp10 components
    cp tmp/usr/lib/*/libgmp.so.10.* rootfs/usr/lib/libgmp.so.10

    # libgnutls30 components
    cp tmp/usr/lib/*/libgnutls.so.30.* rootfs/usr/lib/libgnutls.so.30

    # libgpg-error0 components
    cp tmp/lib/*/libgpg-error.so.0.* rootfs/lib/libgpg-error.so.0

    # libgssapi-krb5-2 components
    cp tmp/usr/lib/*/libgssapi_krb5.so.2.* rootfs/usr/lib/libgssapi_krb5.so.2

    # libhogweed4 components
    cp tmp/usr/lib/*/libhogweed.so.4.* rootfs/usr/lib/libhogweed.so.4

    # libidn2-0 components
    cp tmp/usr/lib/*/libidn2.so.0.* rootfs/usr/lib/libidn2.so.0

    # libk5crypto3 components
    cp tmp/usr/lib/*/libk5crypto.so.3.* rootfs/usr/lib/libk5crypto.so.3

    # libkeyutils1 components
    cp tmp/lib/*/libkeyutils.so.1.* rootfs/lib/libkeyutils.so.1

    # libkrb5-3 components
    cp tmp/usr/lib/*/libkrb5.so.3.* rootfs/usr/lib/libkrb5.so.3

    # libkrb5support0 components
    cp tmp/usr/lib/*/libkrb5support.so.0.* rootfs/usr/lib/libkrb5support.so.0

    # libldap-2.4-2 components
    cp tmp/usr/lib/*/liblber-2.4.so.2.* rootfs/usr/lib/liblber-2.4.so.2
    cp tmp/usr/lib/*/libldap-2.4.so.2 rootfs/usr/lib/
    cp tmp/usr/lib/*/libldap_r-2.4.so.2.* rootfs/usr/lib/libldap_r-2.4.so.2

    # liblz4-1 components
    cp tmp/usr/lib/*/liblz4.so.1.* rootfs/lib/liblz4.so.1

    # liblzma5 components
    cp tmp/lib/*/liblzma.so.5.* rootfs/lib/liblzma.so.5

    # liblzo2-2 components
    cp tmp/lib/*/liblzo2.so.2 rootfs/lib/

    # libmnl0 components
    cp tmp/lib/*/libmnl.so.0.* rootfs/lib/libmnl.so.0

    # libmount1 components
    cp tmp/lib/*/libmount.so.1.* rootfs/lib/libmount.so.1

    # libnettle6 components
    cp tmp/usr/lib/*/libnettle.so.6.* rootfs/usr/lib/libnettle.so.6

    # libnghttp2-14 components
    cp tmp/usr/lib/*/libnghttp2.so.14.* rootfs/usr/lib/libnghttp2.so.14

    # libnl-3-200 components
    cp tmp/lib/*/libnl-3.so.200.* rootfs/lib/libnl-3.so.200

    # libnl-genl-3-200 components
    cp tmp/lib/*/libnl-genl-3.so.200.* rootfs/lib/libnl-genl-3.so.200

    # libnl-genl-3-200 components
    cp tmp/usr/lib/*/libnl-route-3.so.200.* rootfs/lib/libnl-route-3.so.200

    # libp11-kit0 components
    cp tmp/usr/lib/*/libp11-kit.so.0.* rootfs/usr/lib/libp11-kit.so.0

    # libpam0g components
    cp tmp/lib/*/libpam.so.0.* rootfs/lib/libpam.so.0
    cp tmp/lib/*/libpam_misc.so.0.* rootfs/lib/libpam_misc.so.0
    cp tmp/lib/*/libpamc.so.0.* rootfs/lib/libpamc.so.0

    # libpcre3 components
    cp tmp/lib/*/libpcre.so.3.* rootfs/lib/libpcre.so.3
    cp tmp/usr/lib/*/libpcreposix.so.3.* rootfs/usr/lib/libpcreposix.so.3

    # libpcsclite components
    cp tmp/usr/lib/*/libpcsclite.so.1 rootfs/lib/libpcsclite.so.1

    # libpsl5 components
    cp tmp/usr/lib/*/libpsl.so.5.* rootfs/usr/lib/libpsl.so.5

    # librtmp1 components
    cp tmp/usr/lib/*/librtmp.so.1 rootfs/usr/lib/

    # libsasl2-2 components
    cp tmp/usr/lib/*/libsasl2.so.2.* rootfs/usr/lib/libsasl2.so.2

    # libselinux1 components
    cp tmp/lib/*/libselinux.so.1 rootfs/lib/

    # libslang2 components
    cp tmp/lib/*/libslang.so.2.* rootfs/lib/libslang.so.2

    # libsmartcols1 components
    cp tmp/lib/*/libsmartcols.so.1.* rootfs/lib/libsmartcols.so.1

    # libssh2-1 components
    cp tmp/usr/lib/*/libssh2.so.1.* rootfs/usr/lib/libssh2.so.1

    # libssl1.1.0 components
    cp tmp/usr/lib/*/libcrypto.so.1.1 rootfs/usr/lib/
    cp tmp/usr/lib/*/libssl.so.1.1 rootfs/usr/lib/
    cp tmp/usr/lib/*/engines-1.1/afalg.so rootfs/usr/lib/engines-1.1/
    cp tmp/usr/lib/*/engines-1.1/capi.so rootfs/usr/lib/engines-1.1/
    cp tmp/usr/lib/*/engines-1.1/padlock.so rootfs/usr/lib/engines-1.1/

    # libsystemd0 components
    cp tmp/lib/*/libsystemd.so.0.* rootfs/lib/libsystemd.so.0

    # libtasn1-6 components
    cp tmp/usr/lib/*/libtasn1.so.6.* rootfs/usr/lib/libtasn1.so.6

    # libtinfo6 components
    cp tmp/lib/*/libtinfo.so.6.* rootfs/lib/libtinfo.so.6
    cp tmp/usr/lib/*/libtic.so.6.* rootfs/usr/lib/libtic.so.6

    # libudev1 components
    cp tmp/lib/*/libudev.so.1.* rootfs/lib/libudev.so.1

    # libunistring2 components
    cp tmp/usr/lib/*/libunistring.so.2.* rootfs/usr/lib/libunistring.so.2

    # libuuid1 components
    cp tmp/lib/*/libuuid.so.1.* rootfs/lib/libuuid.so.1

    # zlib1g components
    cp tmp/lib/*/libz.so.1 rootfs/lib/

    (cd rootfs && find . | cpio -H newc -ov | gzip --best > "../${INITRAMFS}")

    rm -rf rootfs
}

# start
if [ ! -d packages ]; then
    . ./update.sh
fi

echo Preparing...
rm -rf tmp
mkdir tmp

# extract debs
for deb in packages/*.*deb; do
    echo "Extracting " "$(basename "$deb")..."
    (cd tmp && ar x ../"$deb" && tar -xf data.tar.*; rm data.tar.*)
done

# initialize bootfs
rm -rf bootfs
mkdir bootfs

# raspberrypi-bootloader-nokernel components and kernel
cp -r tmp/boot/* bootfs/
rm bootfs/System*
rm bootfs/config-*
mv bootfs/vmlinuz-${KERNEL_VERSION_RPI1} bootfs/kernel-rpi1_install.img
mv bootfs/vmlinuz-${KERNEL_VERSION_RPI2} bootfs/kernel-rpi2_install.img

if [ ! -f bootfs/config.txt ] ; then
    touch bootfs/config.txt
fi

# initramfs
create_cpio "installer-rpi.cpio.gz"
cp installer-rpi.cpio.gz bootfs/

# write boot config
{
    # rpi zero uses the same kernel as rpi1
    echo "[pi0]"
    echo "kernel=kernel-rpi1_install.img"
    echo "initramfs installer-rpi.cpio.gz"
    echo "[pi1]"
    echo "kernel=kernel-rpi1_install.img"
    echo "initramfs installer-rpi.cpio.gz"
    echo "[pi2]"
    echo "kernel=kernel-rpi2_install.img"
    echo "initramfs installer-rpi.cpio.gz"
    # rpi3 uses the same kernel as rpi2
    echo "[pi3]"
    echo "kernel=kernel-rpi2_install.img"
    echo "initramfs installer-rpi.cpio.gz"
    # on the rpi3 the uart port is used by bluetooth by default
    # but during the installation we want the serial console
    # the next statement does that, but has an effect on bluetooth
    # not sure how/what as I don't fully understand
    # https://github.com/raspberrypi/documentation/blob/master/configuration/uart.md
    echo "dtoverlay=pi3-miniuart-bt"
    # rpi4 uses the same kernel as rpi2
    echo "[pi4]"
    echo "kernel=kernel-rpi2_install.img"
    echo "initramfs installer-rpi.cpio.gz"
    # reset filter
    echo "[all]"
} >> bootfs/config.txt

# clean up
rm -rf tmp

echo "consoleblank=0 console=ttyAMA0,115200 kgdboc=ttyAMA0,115200 console=tty1" > bootfs/cmdline.txt

if [ -f installer-config.txt ]; then
    cp installer-config.txt bootfs/
fi

if [ -f post-install.txt ]; then
    cp post-install.txt bootfs/
fi

if [ -d config ] ; then
    mkdir bootfs/config
    cp -r config/* bootfs/config
fi

ZIPFILE=raspbian-ua-netinst-$(date +%Y%m%d)-git$(git rev-parse --short "@{0}").zip
rm -f "$ZIPFILE"

(cd bootfs && zip -r -9 ../"$ZIPFILE" -- *)
