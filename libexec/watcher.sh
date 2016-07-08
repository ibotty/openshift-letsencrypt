#!/bin/bash -e
. $LETSENCRYPT_SHAREDIR/common.sh

OC_ROUTES_OPTIONS="-o go-template-file=$LETSENCRYPT_SHAREDIR/process-route.yaml"

watch_routes() {
    $OC_GET_ROUTES $OC_ROUTES_OPTIONS | sh
}

while true
do
    if ! watch_routes; then
        err "Failure to watch routes; exiting."
        exit 1
    fi
done
