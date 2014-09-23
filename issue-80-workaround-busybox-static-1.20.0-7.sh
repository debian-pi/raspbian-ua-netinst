#!/bin/bash

# This is a workaround for https://github.com/debian-pi/raspbian-ua-netinst/issues/80.

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
. "$DIR"/autobuild.fn.sh

cd "$DIR"/packages
rm ./busybox-static*
CURL -O https://archive.raspbian.org/raspbian/pool/main/b/busybox/busybox-static_1.20.0-7_armhf.deb
