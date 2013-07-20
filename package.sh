#!/bin/sh

if [ ! -d bootfs ]; then
    mkdir -p bootfs
    cd bootfs
    wget \
        https://raw.github.com/raspberrypi/firmware/master/boot/bootcode.bin \
        https://raw.github.com/raspberrypi/firmware/master/boot/fixup.dat\
        https://raw.github.com/raspberrypi/firmware/master/boot/fixup_cd.dat \
        https://raw.github.com/raspberrypi/firmware/master/boot/fixup_x.dat \
        https://raw.github.com/raspberrypi/firmware/master/boot/kernel.img \
        https://raw.github.com/raspberrypi/firmware/master/boot/kernel_emergency.img \
        https://raw.github.com/raspberrypi/firmware/master/boot/start.elf \
        https://raw.github.com/raspberrypi/firmware/master/boot/start_cd.elf \
        https://raw.github.com/raspberrypi/firmware/master/boot/start_x.elf

    echo "kernel=kernel_emergency.img" > config.txt
    echo "initramfs installer.cpio.gz" >> config.txt

    cd ..
fi

cp installer.cpio.gz bootfs/

cd bootfs && zip -9 ../raspbian-ua-netinst-`date +%Y%m%d`-git`git rev-parse --short @{0}`.zip *; cd ..
