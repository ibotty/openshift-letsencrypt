#!/bin/bash -e
. $LETSENCRYPT_SHAREDIR/common.sh

DOMAINNAME="$1"
DOMAINDIR="$LETSENCRYPT_DATADIR/$DOMAINNAME"
keyfile="$DOMAINDIR/privkey.pem"
crtfile="$DOMAINDIR/cert.pem"
fullchainfile="$DOMAINDIR/fullchain.pem"

newest_secret_to_be_used() {
    oc get secret -l "$(valid_secrets_selector $DOMAINNAME $(now_secs))" \
        --sort-by='{.metadata.labels."butter.sh/letsencrypt-crt-enddate-secs"}'
}

get_old_certificate() {
    if ! [ -f "$keyfile" ]; then
        mount_secret "$secretname" 
    fi
}

