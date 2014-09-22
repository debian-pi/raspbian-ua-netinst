#!/bin/bash

set -e
export IN_DOCKER=yes

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$DIR"

outdir=/raspbian-ua-netinst-output

mkdir -p "$outdir" &> /dev/null

./autobuild.sh &> "$outdir/build.log"  # hint - view using: less -R build.log
mv *.zip *.img.xz *.img.bz2 "$outdir" &> /dev/null
tar -c "$outdir" 2> /dev/null  # archive goes to stdout
