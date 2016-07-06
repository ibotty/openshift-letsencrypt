#!/bin/bash -e
. /usr/share/letsencrypt-container/common.sh

OC_ROUTES_OPTIONS="-o go-template-file=/usr/share/letsencrypt-container/process-route.yaml"

watch_routes() {
    $OC_GET_ROUTES $OC_ROUTES_OPTIONS | sh
}

while true
do
    if ! watch_routes
        err "Failure to watch routes; exiting."
        exit 1
    fi
done
