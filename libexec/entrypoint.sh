#!/bin/sh -eu
set -o pipefail

if [ $# -eq 0 ]; then
    # default command is usage
    set usage
fi

executable="$LETSENCRYPT_LIBEXECDIR/$1.sh"
if [ -x "$executable" ]; then
    shift
    exec "$executable" "$@"
else
    exec "$@"
fi
