#!/bin/sh

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

# install scripts
cp -r scripts/* rootfs/

# update version
sed -i "s/__VERSION__/git~`git rev-parse --short @{0}`/" rootfs/etc/init.d/rcS
sed -i "s/__DATE__/`date`/" rootfs/etc/init.d/rcS

# install busybox
cp tmp/bin/busybox rootfs/bin
cd rootfs && ln -s bin/busybox init; cd ..

# install libc6 (for DNS and filesystem utils)
cp tmp/lib/*/ld-2.17.so rootfs/lib/ld-linux-armhf.so.3
cp tmp/lib/*/libc-2.17.so rootfs/lib/libc.so.6
cp tmp/lib/*/libresolv-2.17.so rootfs/lib/libresolv.so.2
cp tmp/lib/*/libnss_dns-2.17.so rootfs/lib/libnss_dns.so.2
cp tmp/lib/*/libpthread-2.17.so rootfs/lib/libpthread.so.0

# install cdebootstrap
mkdir -p rootfs/usr/share/
mkdir -p rootfs/usr/bin/
cp -r tmp/usr/share/cdebootstrap-static rootfs/usr/share/
cp tmp/usr/bin/cdebootstrap-static rootfs/usr/bin/

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
cp tmp/lib/*/libext2fs.so.2.4  rootfs/lib/libext2fs.so.2

cd rootfs && find . | cpio -H newc -ov > ../installer.cpio
cd ..

rm -rf tmp
rm -rf rootfs

cp installer.cpio bootfs/

echo "kernel=kernel_install.img" > bootfs/config.txt
echo "initramfs installer.cpio" >> bootfs/config.txt
echo "consoleblank=0" > bootfs/cmdline.txt

ZIPFILE=raspbian-ua-netinst-`date +%Y%m%d`-git`git rev-parse --short @{0}`.zip
rm -f $ZIPFILE

cd bootfs && zip -9 ../$ZIPFILE *; cd ..
