#!/bin/bash

# Usage:
#   DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
#   . "$DIR"/autobuild.fn.sh

set -e

bold='\033[1m'
normal='\033[0m'

function CMD_STR {
  echo -ne "$bold" >&2
  echo "$@" >&2
  echo -ne "$normal" >&2
  eval "$@"
}

function CMD {
  CMD_STR "$(printf "%q " "$@")"
}

function MSG {
  echo -ne "$bold" >&2
  echo "# $@" >&2
  echo -ne "$normal" >&2
}

. "$DIR/curl.fn.sh"
