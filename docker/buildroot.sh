#!/usr/bin/env bash

set -e

docker_image="${1:-goranche/raspbian-ua-netinst}"

if [ "${1}" != "IN_DOCKER" ]; then
	docker run --privileged -ti --rm -v $(pwd):/raspbian-ua-netinst "${docker_image}"
	exit
fi

. update.sh
. build.sh

IMG=raspbian-ua-netinst-`date +%Y%m%d`-git`git rev-parse --short @{0}`.img

rm -f $IMG
rm -f $IMG.bz2
rm -f $IMG.xz

dd if=/dev/zero of=$IMG bs=1M count=64

fdisk $IMG <<EOF
n
p
1


t
b
w
EOF

offset=$(($(partx --show --nr 1 -g -o START $IMG)*512))

# TODO: Create a more robust version, scan for a free loop device
# since this will run in a docker container, it is quite possible
# loop devices will be occupied!
losetup -o ${offset} /dev/loop0 ${IMG}

mkfs.vfat /dev/loop0
mount /dev/loop0 /mnt
cp -r bootfs/* /mnt/
umount /mnt

losetup -d /dev/loop0

xz -9 --keep $IMG
bzip2 -9 --keep $IMG
