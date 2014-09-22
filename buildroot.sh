#!/bin/bash

set -e

IMG=raspbian-ua-netinst-`date +%Y%m%d`-git`git rev-parse --short @{0}`.img

rm -f $IMG
rm -f $IMG.xz

dd if=/dev/zero of=$IMG bs=1M count=32

fdisk $IMG <<EOF
n
p
1


t
b
w
EOF

losetup_lt_2_22=false

if ! losetup --version &> /dev/null ; then
  losetup_lt_2_22=true
elif [ $(echo $(losetup --version | rev|cut -f1 -d' '|rev|cut -d'.' -f-2)'<'2.22 | bc -l) -ne 0 ]; then
  losetup_lt_2_22=true
fi

if $losetup_lt_2_22 ; then
  kpartx -as $IMG
  mkfs.vfat /dev/mapper/loop0p1
  mount /dev/mapper/loop0p1 /mnt
  cp bootfs/* /mnt/
  umount /mnt
  kpartx -d $IMG || true
else
  losetup -D

  losetup -P /dev/loop0 $IMG
  mkfs.vfat /dev/loop0p1
  mount /dev/loop0p1 /mnt
  cp bootfs/* /mnt/
  umount /mnt
  losetup -D || true
fi

{
  cat $IMG | xz -9 > $IMG.xz
} || {
  echo "WARNING: Could not create '$IMG.xz' variant." >&2
}
# As a courtesy to OS X users :)
cat $IMG | bzip2 -9 > $IMG.bz2
