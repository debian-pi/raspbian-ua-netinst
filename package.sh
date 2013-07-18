#!/bin/sh

if [ ! -d bootfs ]; then
    mkdir -p bootfs
    cd bootfs
    wget \
        https://github.com/raspberrypi/firmware/raw/master/boot/bootcode.bin \
        https://github.com/raspberrypi/firmware/raw/master/boot/fixup.dat\
        https://github.com/raspberrypi/firmware/raw/master/boot/fixup_cd.dat \
        https://github.com/raspberrypi/firmware/raw/master/boot/fixup_x.dat \
        https://github.com/raspberrypi/firmware/raw/master/boot/kernel.img \
        https://github.com/raspberrypi/firmware/raw/master/boot/kernel_emergency.img \
        https://github.com/raspberrypi/firmware/raw/master/boot/start.elf \
        https://github.com/raspberrypi/firmware/raw/master/boot/start_cd.elf \
        https://github.com/raspberrypi/firmware/raw/master/boot/start_x.elf

    echo "kernel=kernel_emergency.img" > config.txt
    echo "initramfs installer.cpio.gz" >> config.txt

    cd ..
fi

cp installer.cpio.gz bootfs/
