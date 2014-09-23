FROM debian:jessie

RUN apt-get update

# Dependencies not mentioned in BUILD.md and not included in the base image:
RUN DEBIAN_FRONTEND=noninteractive apt-get install -y build-essential cpio module-init-tools

RUN DEBIAN_FRONTEND=noninteractive apt-get install -y \
      git        \
      curl       \
      bzip2      \
      zip        \
      xz-utils   \
      gnupg      \
      kpartx     \
      dosfstools \
      ;

ADD . /build
