#!/bin/sh

IMG=raspbian-ua-netinst-`date +%Y%m%d`-git`git rev-parse --short @{0}`.img

rm -f $IMG
rm -f $IMG.xz

dd if=/dev/zero of=$IMG bs=1M count=32 || exit

fdisk $IMG <<EOF
n
p
1


t
b
w
EOF

losetup -D || exit

losetup -P /dev/loop0 $IMG || exit
mkfs.vfat /dev/loop0p1 || exit
mount /dev/loop0p1 /mnt || exit
cp bootfs/* /mnt/ || exit
umount /mnt || exit
losetup -D

xz -9 $IMG
