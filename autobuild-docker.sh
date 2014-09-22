#!/bin/bash

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
. "$DIR"/autobuild.fn.sh

CMD docker build -t raspbian-netinst .

MSG 'This will take a few minutes: (stdout+err will be in the tar)'
# --privileged is needed for /dev/loop* interactions, see http://stackoverflow.com/a/22052896/1034080
CMD_STR 'docker run --privileged --rm raspbian-netinst /bin/bash /build/autobuild-docker.inner.sh > raspbian-ua-netinst-output.tar'

MSG
MSG 'Build successful. Next, you might want to:'
MSG '  tar -xf raspbian-ua-netinst-output.tar'
MSG '  less -R raspbian-ua-netinst-output/build.log'
