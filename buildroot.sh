#!/usr/bin/env bash

set -e

IMG=raspbian-ua-netinst-$(date +%Y%m%d)-git$(git rev-parse --short "@{0}").img

rm -f "$IMG"
rm -f "$IMG".bz2
rm -f "$IMG".xz

dd if=/dev/zero of="$IMG" bs=1M count=64

fdisk "$IMG" <<EOF
n
p
1


t
b
w
EOF

if ! losetup --version &> /dev/null ; then
  losetup_lt_2_22=true
elif [ "$(echo "$(losetup --version | rev|cut -f1 -d' '|rev|cut -d'.' -f-2)"'<'2.22 | bc -l)" -ne 0 ]; then
  losetup_lt_2_22=true
else
  losetup_lt_2_22=false
fi

if [ "$losetup_lt_2_22" = "true" ] ; then

  kpartx -as "$IMG"
  mkfs.vfat /dev/mapper/loop0p1
  mount /dev/mapper/loop0p1 /mnt
  cp -r bootfs/* /mnt/
  umount /mnt
  kpartx -d "$IMG" || true

else

  losetup --find --partscan "$IMG"
  LOOP_DEV="$(losetup --associated "$IMG" | cut -f1 -d':')"
  mkfs.vfat "${LOOP_DEV}"p1
  mount "${LOOP_DEV}"p1 /mnt
  cp -r bootfs/* /mnt/
  umount /mnt
  losetup --detach "${LOOP_DEV}"

fi

if ! xz -9 --keep "$IMG" ; then
  # This happens e.g. on Raspberry Pi because xz runs out of memory.
  echo "WARNING: Could not create '$IMG.xz' variant." >&2
fi

bzip2 -k -9 "$IMG"
