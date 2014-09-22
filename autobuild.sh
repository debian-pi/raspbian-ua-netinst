#!/bin/bash

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
. "$DIR"/autobuild.fn.sh

if [ "$(uname -s)" != Linux ] ; then
    MSG "ERROR: Needs to run on Debian or Ubuntu Linux (you have '$(uname -s)')."
    exit 1
fi

if ! hash sudo &> /dev/null ; then
    # This is e.g. for Docker
    function sudo {
        "$@"
    }
fi

CMD sudo apt-get install -y \
        git        \
        curl       \
        bzip2      \
        zip        \
        xz-utils   \
        gnupg      \
        kpartx     \
        dosfstools \
        ;

# Check buildroot.sh assumption - BUILD.md: "[buildroot.sh] makes some assumptions like not having any other loop devices in use"

if [ "$(sudo losetup -f)" != '/dev/loop0' ] ; then
    MSG "ERROR: Assumed 'sudo losetup -f' to return '/dev/loop0'."
    MSG "       Got '$(sudo losetup -f)' instead."
    exit 1
fi

CMD "$DIR"/build.sh  # calls update.sh if needed

CMD sudo "$DIR"/buildroot.sh

MSG
MSG "Build successful. To remove ALL built files, run:"
MSG "  '$DIR'/clean.sh"
