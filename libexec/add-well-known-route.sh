#!/bin/bash -e
. /usr/share/letsencrypt-container/common.sh

export LETSENCRYPT_HOSTNAME="$1"
export LETSENCRYPT_TEMP_ROUTE_NAME="letsencrypt-$LETSENCRYPT_HOSTNAME"

envsubst '$LETSENCRYPT_HOSTNAME:$LETSENCRYPT_SERVICE_NAME:$LETSENCRYPT_TEMP_ROUTE_NAME' \
         < /usr/share/letsencrypt-container/new-route.yaml.tmpl \
    | oc create -f - 1>&2

echo "$LETSENCRYPT_TEMP_ROUTE_NAME"
