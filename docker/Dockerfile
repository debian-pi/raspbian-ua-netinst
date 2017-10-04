FROM ubuntu:16.04

LABEL \
	Version="1" \
	Description="Docker image for building the Raspbian (minimal) unattended netinstaller SD card image" \
	Vendor="Raspbian (minimal) unattended netinstaller"

WORKDIR /raspbian-ua-netinst

RUN apt-get update && apt-get install -y \
	cpio \
	kmod \
	git \
	curl \
	bzip2 \
	zip \
	xz-utils \
	gnupg \
	kpartx \
	dosfstools \
	binutils \
	bc && \
	rm -r /var/lib/apt/lists/*

ENTRYPOINT ["docker/buildroot.sh", "IN_DOCKER"]
