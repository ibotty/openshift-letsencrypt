#!/bin/sh -eu
set -o pipefail

echo "calling entrypoint with $@"

if [ $# -eq 0 ]; then
    # default command is usage
    set usage
fi

executable="$LETSENCRYPT_LIBEXECDIR/$1.sh"
if [ -x "$executable" ]; then
    shift
    echo exec "$executable" "$@"
    exec "$executable" "$@"
else
    echo exec "$@"
    exec "$@"
fi
