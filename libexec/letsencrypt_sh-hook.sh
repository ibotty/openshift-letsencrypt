#!/bin/bash -eu
set -o pipefail

# shellcheck source=share/common.sh
. $LETSENCRYPT_SHAREDIR/common.sh

deploy_challenge() {
    local DOMAIN="${1}" TOKEN_FILENAME="${2}" TOKEN_VALUE="${3}"
}

clean_challenge() {
    local DOMAIN="${1}" TOKEN_FILENAME="${2}" TOKEN_VALUE="${3}"
}

deploy_cert() {
    local DOMAIN="${1}" KEYFILE="${2}" CERTFILE="${3}"
    local FULLCHAINFILE="${4}" CHAINFILE="${5}" TIMESTAMP="${6}"
}

unchanged_cert() {
    local DOMAIN="${1}" KEYFILE="${2}" CERTFILE="${3}"
    local FULLCHAINFILE="${4}" CHAINFILE="${5}"

    echo "Certificate for $DOMAIN unchanged."
}

HANDLER="$1"; shift; $HANDLER "$@"
