#!/bin/bash -eu
set -o pipefail

# shellcheck source=share/common.sh
. $LETSENCRYPT_SHAREDIR/common.sh

WHEN="tomorrow 02:05"

do_cron() {
    echo "TODO: doing things"
}

while true; do
    do_cron
    sleep $(( $(date -d "$WHEN" +%s) - $(date +%s) ))
done
