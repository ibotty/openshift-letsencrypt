#!/bin/sh -e

if [ $# -le 1 ]; then
    # default command is usage
    set usage
fi

executable="/usr/libexec/letsencrypt-container/$1.sh"
if [ -x "$executable" ]; then
    shift
    exec "$executable" $@
else
    exec $@
fi
