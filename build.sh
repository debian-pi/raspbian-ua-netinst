#!/usr/bin/env bash

set -e

KERNEL_VERSION_RPI1=3.18.0-trunk-rpi
KERNEL_VERSION_RPI2=3.18.0-trunk-rpi2

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

function create_cpio {
    local KERNEL_VERSION=""
    local target_system

    if [ "$1" = "rpi1" ] ; then
        KERNEL_VERSION=$KERNEL_VERSION_RPI1
        target_system="rpi1"
    elif [ "$1" = "rpi2" ] ; then
        KERNEL_VERSION=$KERNEL_VERSION_RPI2
        target_system="rpi2"
    else
        echo "Invalid parameter to 'create_cpio' function!"
        return 1
    fi

    # initialize rootfs
    rm -rf rootfs
    mkdir -p rootfs
    # create all the directories needed to copy the various components into place
    mkdir -p rootfs/bin/
    mkdir -p rootfs/lib/lsb/init-functions.d/
    mkdir -p rootfs/etc/{alternatives,cron.daily,default,ld.so.conf.d,logrotate.d,network/if-up.d/}
    mkdir -p rootfs/etc/dpkg/dpkg.cfg.d/
    mkdir -p rootfs/lib/lsb/init-functions.d/
    mkdir -p rootfs/lib/modules/${KERNEL_VERSION}
    mkdir -p rootfs/sbin/
    mkdir -p rootfs/usr/bin/
    mkdir -p rootfs/usr/lib/mime/packages/
    mkdir -p rootfs/usr/lib/openssl-1.0.0/engines/
    mkdir -p rootfs/usr/lib/tar/
    mkdir -p rootfs/usr/sbin/
    mkdir -p rootfs/usr/share/{dpkg,keyrings,libc-bin}
    mkdir -p rootfs/var/lib/dpkg/{alternatives,info,parts,updates}
    mkdir -p rootfs/var/lib/ntpdate
    mkdir -p rootfs/var/log/

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
    cp tmp/usr/lib/*/libbtrfs.so.0  rootfs/lib/

    # busybox components
    cp tmp/bin/busybox rootfs/bin
    cd rootfs && ln -s bin/busybox init; cd ..

    # cdebootstrap-static components
    cp -r tmp/usr/share/cdebootstrap-static rootfs/usr/share/
    cp tmp/usr/bin/cdebootstrap-static rootfs/usr/bin/

    # dosfstools components
    cp tmp/sbin/fatlabel rootfs/sbin/
    cd rootfs && ln -s sbin/fatlabel sbin/dosfslabel; cd ..
    cp tmp/sbin/fsck.fat rootfs/sbin/
    cd rootfs && ln -s sbin/fsck.fat sbin/dosfsck; cd ..
    cd rootfs && ln -s sbin/fsck.fat sbin/fsck.msdos; cd ..
    cd rootfs && ln -s sbin/fsck.fat sbin/fsck.vfat; cd ..
    cp tmp/sbin/mkfs.fat rootfs/sbin/
    cd rootfs && ln -s sbin/mkfs.fat sbin/mkdosfs; cd ..
    cd rootfs && ln -s sbin/mkfs.fat sbin/mkfs.msdos; cd ..
    cd rootfs && ln -s sbin/mkfs.fat sbin/mkfs.vfat; cd ..

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
    cd rootfs && ln -s usr/bin/dpkg-divert usr/sbin/dpkg-divert; cd ..
    cd rootfs && ln -s usr/bin/dpkg-statoverride usr/sbin/dpkg-statoverride; cd ..
    cd rootfs && ln -s usr/bin/update-alternatives usr/sbin/update-alternatives; cd ..
    cp tmp/usr/share/dpkg/abitable rootfs/usr/share/dpkg/
    cp tmp/usr/share/dpkg/cputable rootfs/usr/share/dpkg/
    cp tmp/usr/share/dpkg/ostable rootfs/usr/share/dpkg/
    cp tmp/usr/share/dpkg/triplettable rootfs/usr/share/dpkg/
    touch rootfs/var/lib/dpkg/status

    # e2fslibs components
    cp tmp/lib/*/libe2p.so.2.* rootfs/lib/libe2p.so.2
    cp tmp/lib/*/libext2fs.so.2.*  rootfs/lib/libext2fs.so.2

    # e2fsprogs components
    cp tmp/sbin/mkfs.ext4 rootfs/sbin/

    # f2fs-tools components
    cp tmp/sbin/mkfs.f2fs rootfs/sbin/
    cp tmp/lib/*/libf2fs.so.0  rootfs/lib/

    # gpgv components
    cp tmp/usr/bin/gpgv rootfs/usr/bin/

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
    cp tmp/etc/network/if-up.d/ntpdate rootfs/etc/network/if-up.d/
    cp tmp/usr/sbin/ntpdate rootfs/usr/sbin/
    cp tmp/usr/sbin/ntpdate-debian rootfs/usr/sbin/

    # raspberrypi.org GPG key 
    cp packages/raspberrypi.gpg.key rootfs/usr/share/keyrings/

    # raspbian-archive-keyring components
    cp tmp/usr/share/keyrings/raspbian-archive-keyring.gpg rootfs/usr/share/keyrings/

    # tar components
    cp tmp/bin/tar rootfs/bin/
    cp tmp/etc/rmt rootfs/etc/
    cp tmp/usr/lib/mime/packages/tar rootfs/usr/lib/mime/packages/
    cp tmp/usr/sbin/rmt-tar rootfs/usr/sbin/
    cp tmp/usr/sbin/tarcat rootfs/usr/sbin/

    # wpa_supplicant components
    cp tmp/sbin/wpa_supplicant rootfs/sbin/wpa_supplicant
    cp -r tmp/etc/wpa_supplicant rootfs/etc/wpa_supplicant

    # libacl1 components
    cp tmp/lib/*/libacl.so.1.* rootfs/lib/libacl.so.1

    # libattr1 components
    cp tmp/lib/*/libattr.so.1.* rootfs/lib/libattr.so.1

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
    cp tmp/sbin/ldconfig.real rootfs/sbin/
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
    cp tmp/lib/*/libanl-*.so rootfs/lib/libanl.so.1
    cp tmp/lib/*/libBrokenLocale-*.so rootfs/lib/libBrokenLocale.so.1
    cp tmp/lib/*/libc-*.so rootfs/lib/libc.so.6
    cp tmp/lib/*/libcidn-*.so rootfs/lib/libcidn.so.1
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
    cp tmp/lib/*/libpcprofile.so rootfs/lib/
    cp tmp/lib/*/libpthread-*.so rootfs/lib/libpthread.so.0
    cp tmp/lib/*/libresolv-*.so rootfs/lib/libresolv.so.2
    cp tmp/lib/*/librt-*.so rootfs/lib/librt.so.1
    cp tmp/lib/*/libSegFault.so rootfs/lib/
    cp tmp/lib/*/libthread_db-*.so rootfs/lib/libthread_db.so.1
    cp tmp/lib/*/libutil-*.so rootfs/lib/libutil.so.1

    # libcap2 components
    cp tmp/lib/*/libcap.so.2.* rootfs/lib/libcap.so.2

    # libcomerr2 components
    cp tmp/lib/*/libcom_err.so.2.* rootfs/lib/libcom_err.so.2

    # libdbus-1-3 components
    cp tmp/lib/*/libdbus-1.so.3 rootfs/lib/libdbus-1.so.3
    cp tmp/lib/*/libdl.so.2 rootfs/lib/libdl.so.2

    # libgcc1 components
    cp tmp/lib/*/libgcc_s.so.1 rootfs/lib/
    cp tmp/lib/*/librt.so.1 rootfs/lib/

    # liblzma5 components
    cp tmp/lib/*/liblzma.so.5.* rootfs/lib/liblzma.so.5

    # liblzo2-2 components
    cp tmp/lib/*/liblzo2.so.2 rootfs/lib/

    # libmount1 components
    cp tmp/lib/*/libmount.so.1.* rootfs/lib/libmount.so.1

    # libncurses5 components
    cp tmp/lib/*/libncurses.so.5.* rootfs/lib/libncurses.so.5
    cp tmp/usr/lib/*/libform.so.5.* rootfs/usr/lib/libform.so.5
    cp tmp/usr/lib/*/libmenu.so.5.* rootfs/usr/lib/libmenu.so.5
    cp tmp/usr/lib/*/libpanel.so.5.* rootfs/usr/lib/libpanel.so.5

    # libnl-3-200 components
    cp tmp/lib/*/libnl-3.so.200 rootfs/lib/libnl-3.so.200

    # libnl-genl-3-200 components
    cp tmp/lib/*/libnl-genl-3.so.200 rootfs/lib/libnl-genl-3.so.200

    # libpam0g components
    cp tmp/lib/*/libpam.so.0.* rootfs/lib/libpam.so.0
    cp tmp/lib/*/libpam_misc.so.0.* rootfs/lib/libpam_misc.so.0
    cp tmp/lib/*/libpamc.so.0.* rootfs/lib/libpamc.so.0

    # libpcre3 components
    cp tmp/lib/*/libpcre.so.3.* rootfs/lib/libpcre.so.3
    cp tmp/usr/lib/*/libpcreposix.so.3.* rootfs/usr/lib/libpcreposix.so.3

    # libpcsclite components
    cp tmp/usr/lib/*/libpcsclite.so.1 rootfs/lib/libpcsclite.so.1

    # libselinux1 components
    cp tmp/lib/*/libselinux.so.1 rootfs/lib/

    # libslang2 components
    cp tmp/lib/*/libslang.so.2.* rootfs/lib/libslang.so.2

    # libsmartcols1 components
    cp tmp/lib/*/libsmartcols.so.1.* rootfs/lib/libsmartcols.so.1

    # libssl1.0.0 components
    cp tmp/usr/lib/*/libcrypto.so.1.0.0 rootfs/usr/lib/
    cp tmp/usr/lib/*/libssl.so.1.0.0 rootfs/usr/lib/
    cp tmp/usr/lib/*/openssl-1.0.0/engines/lib4758cca.so rootfs/usr/lib/openssl-1.0.0/engines/
    cp tmp/usr/lib/*/openssl-1.0.0/engines/libaep.so rootfs/usr/lib/openssl-1.0.0/engines/
    cp tmp/usr/lib/*/openssl-1.0.0/engines/libatalla.so rootfs/usr/lib/openssl-1.0.0/engines/
    cp tmp/usr/lib/*/openssl-1.0.0/engines/libcapi.so rootfs/usr/lib/openssl-1.0.0/engines/
    cp tmp/usr/lib/*/openssl-1.0.0/engines/libchil.so rootfs/usr/lib/openssl-1.0.0/engines/
    cp tmp/usr/lib/*/openssl-1.0.0/engines/libcswift.so rootfs/usr/lib/openssl-1.0.0/engines/
    cp tmp/usr/lib/*/openssl-1.0.0/engines/libgmp.so rootfs/usr/lib/openssl-1.0.0/engines/
    cp tmp/usr/lib/*/openssl-1.0.0/engines/libgost.so rootfs/usr/lib/openssl-1.0.0/engines/
    cp tmp/usr/lib/*/openssl-1.0.0/engines/libnuron.so rootfs/usr/lib/openssl-1.0.0/engines/
    cp tmp/usr/lib/*/openssl-1.0.0/engines/libpadlock.so rootfs/usr/lib/openssl-1.0.0/engines/
    cp tmp/usr/lib/*/openssl-1.0.0/engines/libsureware.so rootfs/usr/lib/openssl-1.0.0/engines/
    cp tmp/usr/lib/*/openssl-1.0.0/engines/libubsec.so rootfs/usr/lib/openssl-1.0.0/engines/

    # libtinfo5 components
    cp tmp/lib/*/libtinfo.so.5.* rootfs/lib/libtinfo.so.5
    cp tmp/usr/lib/*/libtic.so.5.* rootfs/usr/lib/libtinfo.so.5

    # libuuid1 components
    cp tmp/lib/*/libuuid.so.1.* rootfs/lib/libuuid.so.1

    # zlib1g components
    cp tmp/lib/*/libz.so.1  rootfs/lib/

    # drivers
    mkdir -p rootfs/lib/modules/$KERNEL_VERSION/kernel/drivers/net
    cp -r tmp/lib/modules/$KERNEL_VERSION/kernel/drivers/net/wireless rootfs/lib/modules/$KERNEL_VERSION/kernel/drivers/net/

    INITRAMFS="../installer-${target_system}.cpio.gz"
    (cd rootfs && find . | cpio -H newc -ov | gzip --best > $INITRAMFS)

    rm -rf rootfs

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

create_cpio "rpi1"
cp installer-rpi1.cpio.gz bootfs/
echo "[pi1]" >> bootfs/config.txt
echo "kernel=kernel-rpi1_install.img" >> bootfs/config.txt
echo "initramfs installer-rpi1.cpio.gz" >> bootfs/config.txt
echo "device_tree=" >> bootfs/config.txt

create_cpio "rpi2"
cp installer-rpi2.cpio.gz bootfs/
echo "[pi2]" >> bootfs/config.txt
echo "kernel=kernel-rpi2_install.img" >> bootfs/config.txt
echo "initramfs installer-rpi2.cpio.gz" >> bootfs/config.txt

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

ZIPFILE=raspbian-ua-netinst-`date +%Y%m%d`-git`git rev-parse --short @{0}`.zip
rm -f $ZIPFILE

cd bootfs && zip -r -9 ../$ZIPFILE *; cd ..
