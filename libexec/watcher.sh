#!/bin/bash -eu
# shellcheck source=share/common.sh
. "$LETSENCRYPT_SHAREDIR/common.sh"
set -o pipefail

watch_routes() {
    local domainname namespace name
    oc_get_routes --watch-only \
        --template='{{.spec.host}}:{{.metadata.namespace}}:{{.metadata.name}}
' \
        | while IFS=: read -r domainname namespace name; do
            get_certificate "$domainname"
            add_certificate_to_route "$domainname" "$namespace" "$name"
        done
}

while true
do
    if ! watch_routes; then
        err "Failure to watch routes; exiting."
        exit 1
    fi
done
