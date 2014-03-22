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

losetup --version > /dev/null 2>&1

if [ $? -ne 0 ] ; then
  losetup_lt_2_22=true
elif [ $(echo $(losetup --version | rev|cut -f1 -d' '|rev|cut -d'.' -f-2)'<'2.22 | bc -l) -ne 0 ]; then
  losetup_lt_2_22=true
else
  losetup_lt_2_22=false
fi

if [ $losetup_lt_2_22 ] ; then

kpartx -as $IMG || exit
mkfs.vfat /dev/mapper/loop0p1 || exit
mount /dev/mapper/loop0p1 /mnt || exit
cp bootfs/* /mnt/ || exit
umount /mnt || exit
kpartx -d $IMG

else

losetup -D || exit

losetup -P /dev/loop0 $IMG || exit
mkfs.vfat /dev/loop0p1 || exit
mount /dev/loop0p1 /mnt || exit
cp bootfs/* /mnt/ || exit
umount /mnt || exit
losetup -D

fi

xz -9 $IMG
