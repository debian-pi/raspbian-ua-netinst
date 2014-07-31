#!/bin/bash

KERNEL_VERSION=3.10-3-rpi

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
cp tmp/boot/* bootfs/
rm bootfs/System*
rm bootfs/config-*
mv bootfs/vmlinuz* bootfs/kernel_install.img

# initialize rootfs
rm -rf rootfs
mkdir -p rootfs/bin/
mkdir -p rootfs/lib/
mkdir -p rootfs/lib/modules/${KERNEL_VERSION}/kernel/fs
cp -a tmp/lib/modules/${KERNEL_VERSION}/kernel/fs/f2fs rootfs/lib/modules/${KERNEL_VERSION}/kernel/fs/f2fs
cp -a tmp/lib/modules/${KERNEL_VERSION}/kernel/fs/btrfs rootfs/lib/modules/${KERNEL_VERSION}/kernel/fs/btrfs
mkdir -p rootfs/lib/modules/${KERNEL_VERSION}/kernel/lib
cp -a tmp/lib/modules/${KERNEL_VERSION}/kernel/lib/libcrc32c.ko rootfs/lib/modules/${KERNEL_VERSION}/kernel/lib
cp -a tmp/lib/modules/${KERNEL_VERSION}/kernel/lib/crc-t10dif.ko rootfs/lib/modules/${KERNEL_VERSION}/kernel/lib
cp -a tmp/lib/modules/${KERNEL_VERSION}/kernel/lib/raid6 rootfs/lib/modules/${KERNEL_VERSION}/kernel/lib/raid6
cp -a tmp/lib/modules/${KERNEL_VERSION}/kernel/lib/zlib_deflate rootfs/lib/modules/${KERNEL_VERSION}/kernel/lib/zlib_deflate
mkdir -p rootfs/lib/modules/${KERNEL_VERSION}/kernel/crypto
cp -a tmp/lib/modules/${KERNEL_VERSION}/kernel/crypto/xor.ko rootfs/lib/modules/${KERNEL_VERSION}/kernel/crypto
mkdir -p rootfs/lib/modules/${KERNEL_VERSION}/kernel/drivers/usb/storage
cp -a tmp/lib/modules/${KERNEL_VERSION}/kernel/drivers/usb/storage/usb-storage.ko rootfs/lib/modules/${KERNEL_VERSION}/kernel/drivers/usb/storage
mkdir -p rootfs/lib/modules/${KERNEL_VERSION}/kernel/drivers/scsi
cp -a tmp/lib/modules/${KERNEL_VERSION}/kernel/drivers/scsi/sg.ko rootfs/lib/modules/${KERNEL_VERSION}/kernel/drivers/scsi
cp -a tmp/lib/modules/${KERNEL_VERSION}/kernel/drivers/scsi/sd_mod.ko rootfs/lib/modules/${KERNEL_VERSION}/kernel/drivers/scsi
cp -a tmp/lib/modules/${KERNEL_VERSION}/kernel/drivers/scsi/scsi_mod.ko rootfs/lib/modules/${KERNEL_VERSION}/kernel/drivers/scsi
/sbin/depmod -a -b rootfs ${KERNEL_VERSION}

# install scripts
cp -r scripts/* rootfs/

# update version
sed -i "s/__VERSION__/git~`git rev-parse --short @{0}`/" rootfs/etc/init.d/rcS
sed -i "s/__DATE__/`date`/" rootfs/etc/init.d/rcS

# install busybox
cp tmp/bin/busybox rootfs/bin
cd rootfs && ln -s bin/busybox init; cd ..

# install libc6 (for DNS and filesystem utils)
cp tmp/lib/*/ld-*.so rootfs/lib/ld-linux-armhf.so.3
cp tmp/lib/*/libc-*.so rootfs/lib/libc.so.6
cp tmp/lib/*/libresolv-*.so rootfs/lib/libresolv.so.2
cp tmp/lib/*/libnss_dns-*.so rootfs/lib/libnss_dns.so.2
cp tmp/lib/*/libpthread-*.so rootfs/lib/libpthread.so.0

# install cdebootstrap
mkdir -p rootfs/usr/share/
mkdir -p rootfs/usr/bin/
cp -r tmp/usr/share/cdebootstrap-static rootfs/usr/share/
cp tmp/usr/bin/cdebootstrap-static rootfs/usr/bin/

# install raspbian-archive-keyring (for cdebootstrap)
mkdir -p rootfs/usr/share/keyrings/
cp tmp/usr/share/keyrings/raspbian-archive-keyring.gpg rootfs/usr/share/keyrings/

# install gpgv (for cdebootstrap)
cp tmp/usr/bin/gpgv rootfs/usr/bin/

# install raspberrypi.org GPG key (for apt-key add)
cp packages/raspberrypi.gpg.key rootfs/usr/share/keyrings/

# install libbz2-1.0 (for gpgv)
cp tmp/lib/*/libbz2.so.1.0.* rootfs/lib/libbz2.so.1.0

# libs for mkfs
cp tmp/lib/*/libcom_err.so.2.1 rootfs/lib/libcom_err.so.2
cp tmp/lib/*/libe2p.so.2.3 rootfs/lib/libe2p.so.2
cp tmp/lib/*/libuuid.so.1.3.0 rootfs/lib/libuuid.so.1
cp tmp/lib/*/libblkid.so.1.1.0 rootfs/lib/libblkid.so.1
cp tmp/lib/*/libgcc_s.so.1 rootfs/lib/

# filesystem utils
mkdir -p rootfs/sbin/
cp tmp/sbin/mkfs.vfat rootfs/sbin/
cp tmp/sbin/mkfs.ext4 rootfs/sbin/
cp tmp/sbin/mkfs.f2fs rootfs/sbin/
cp tmp/sbin/mkfs.btrfs rootfs/sbin/
cp tmp/lib/*/libext2fs.so.2.4  rootfs/lib/libext2fs.so.2
cp tmp/lib/*/libf2fs.so.0  rootfs/lib/libf2fs.so.0
cp tmp/usr/lib/*/libbtrfs.so.0  rootfs/lib/libbtrfs.so.0
cp tmp/lib/*/libm.so.6  rootfs/lib/libm.so.6
cp tmp/lib/*/libz.so.1  rootfs/lib/libz.so.1
cp tmp/lib/*/liblzo2.so.2 rootfs/lib/liblzo2.so.2

cd rootfs && find . | cpio -H newc -ov > ../installer.cpio
cd ..

rm -rf tmp
rm -rf rootfs

cp installer.cpio bootfs/

echo "kernel=kernel_install.img" > bootfs/config.txt
echo "initramfs installer.cpio" >> bootfs/config.txt
echo "consoleblank=0 console=ttyAMA0,115200 kgdboc=ttyAMA0,115200" > bootfs/cmdline.txt

if [ -f installer-config.txt ]; then
    cp installer-config.txt bootfs/installer-config.txt
fi

if [ -f post-install.txt ]; then
    cp post-install.txt bootfs/post-install.txt
fi

ZIPFILE=raspbian-ua-netinst-`date +%Y%m%d`-git`git rev-parse --short @{0}`.zip
rm -f $ZIPFILE

cd bootfs && zip -9 ../$ZIPFILE *; cd ..
