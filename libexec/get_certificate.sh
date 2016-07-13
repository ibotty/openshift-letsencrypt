#!/bin/bash -eu
set -o pipefail

# shellcheck source=share/common.sh
. $LETSENCRYPT_SHAREDIR/common.sh

DOMAINNAME="$1"
DOMAINDIR="$LETSENCRYPT_DATADIR/$DOMAINNAME"
keyfile="$DOMAINDIR/privkey.pem"
crtfile="$DOMAINDIR/cert.pem"
fullchainfile="$DOMAINDIR/fullchain.pem"

newest_secret_to_be_used() {
    # TODO: check order!
    oc get secret -l "$(valid_secrets_selector "$1" "$(date_in_secs)")" \
        --sort-by='{.metadata.labels."butter.sh/letsencrypt-crt-enddate-secs"}' \
        --template='{{range .items}}{{.metadata.name}} {{end}}' \
        | cut -d\  -f1
}

get_old_certificate() {
    local secretname
    if ! [ -f "$crtfile" ] || ! [ -f "$keyfile" ]; then
        secretname="$(newest_secret_to_be_used "$DOMAINNAME")"
        mount_secret "$secretname" "$DOMAINDIR"
    fi
}

setup_api_key() {
    mount_secret "$LETSENCRYPT_ACME_SECRET_NAME" "$LETSENCRYPT_DATADIR/$CAHASH"
}

get_new_certificate() {
    setup_api_key
    letsencrypt.sh \
        --domain "$DOMAINNAME" \
        --challenge http-01
        --algo "$LETSENCRYPT_KEYTYPE"
        --out "$DOMAINDIR"
        --privkey "$LETSENCRYPT_DATADIR/account-key.pem"
        --hook "$LETSENCRYPT_LIBEXECDIR/letsencrypt_sh-hook.sh"
        --cron
}

get_old_certificate
if ! crt_valid_long_enough "$crtfile"; then
    get_new_certificate "$DOMAINNAME"
fi
