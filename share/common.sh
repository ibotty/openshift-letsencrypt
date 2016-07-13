#!/bin/bash

export LETSENCRYPT_SERVICE_NAME=${LETSENCRYPT_SERVICE_NAME-letsencrypt}
export LETSENCRYPT_ACME_SECRET_NAME="${LETSENCRYPT_ACME_SECRET_NAME-letsencrypt-creds}"
export LETSENCRYPT_ALL_NAMESPACES=${LETSENCRYPT_ALL_NAMESPACES-no}
export LETSENCRYPT_DEFAULT_INSECURE_EDGE_TERMINATION_POLICY="${LETSENCRYPT_DEFAULT_INSECURE_EDGE_TERMINATION_POLICY-edge}"
export LETSENCRYPT_ROUTE_SELECTOR="${LETSENCRYPT_ROUTE_SELECTOR-butter.sh/letsencrypt-managed=yes}"

oc_get_routes() {
    local routes_params=()
    case $LETSENCRYPT_ALL_NAMESPACES in
        yes|y|true|t)
            routes_params+=("--all-namespaces")
            ;;
        *)
            ;;
    esac
    if [ -n "$LETSENCRYPT_ROUTE_SELECTOR" ]; then
        routes_params+=("-l" "$LETSENCRYPT_ROUTE_SELECTOR")
    fi

    oc get routes "${routes_params[@]}" "${@-}"
}

err() {
    echo "${@-}" >&2
}

patch_route() {
    oc patch -n "$1" "route/$2" -p "$3" > /dev/null
}

json_escape() {
    python -c 'import json,sys; print json.dumps(sys.stdin.read())'
}

crt_enddate() {
    userfriendly_date "$(crt_enddate "$1")"
}

crt_enddate_secs() {
    date_in_secs "$(openssl x509 -noout -enddate -in "$1" | cut -d= -f2)"
}

crt_valid_long_enough() {
    [ -f "$1" ] && [ "$(min_valid_enddate_secs)" -lt "$(crt_enddate_secs "$1")" ]
}

userfriendly_date() {
    date -Iseconds -u -d "$1"
}

date_in_secs() {
    datespec=""
    if [ -$# -eq 1 ]; then
        datespec="-d $1"
    fi
    date -u "$datespec" +%s
}

min_valid_enddate_secs() {
    echo $(( $(date -u +%s) + 60*60*24*LETSENCRYPT_RENEW_BEFORE_DAYS))
}

valid_secrets_selector() {
    DOMAINNAME="$1"
    if [ $# -eq 2 ]; then
        min_valid_secs="$2"
    else
        min_valid_secs="$(min_valid_enddate_secs)"
    fi

    xargs <<EOF
butter.sh/letsencrypt-crt-enddate-secs > $min_valid_secs,
butter.sh/letsencrypt-domainname = $DOMAINNAME
EOF
}

hpkp_sha256() {
    case $LETSENCRYPT_KEYTYPE in
        rsa)
            openssl rsa -in "$1" -outform der -pubout 2>/dev/null \
                | openssl dgst -sha256 -binary | openssl enc -base64
            ;;
        *)
            # every other key type is an elliptic curve
            openssl ec -in "$1" -outform der -pubout 2>/dev/null \
                | openssl dgst -sha256 -binary | openssl enc -base64
            ;;
    esac
}

add_well_known_route() {
    export DOMAINNAME="$1"
    export TEMP_ROUTE_NAME="letsencrypt-$LETSENCRYPT_HOSTNAME"

    #shellcheck disable=SC2016
    envsubst '$DOMAINNAME:$LETSENCRYPT_SERVICE_NAME:$TEMP_ROUTE_NAME' \
        < "$LETSENCRYPT_SHAREDIR/new-well-known-route.yaml.tmpl" \
        | oc create -f - 1>&2

    echo "$TEMP_ROUTE_NAME"
}

add_certificate_to_route() {
    local DOMAINNAME="$1"
    local NAMESPACE="$2"
    local ROUTE_NAME="$3"

    if [ $# -eq 4 ] && [ -n "$4" ]; then
        local INSECURE_EDGE_TERMINATION_POLICY="$4"
    else
        local INSECURE_EDGE_TERMINATION_POLICY=$LETSENCRYPT_DEFAULT_INSECURE_EDGE_TERMINATION_POLICY
    fi

    local DOMAINDIR="$LETSENCRYPT_DATADIR/$DOMAINNAME"

    local keyfile="$DOMAINDIR/privkey.pem"
    #local crtfile="$DOMAINDIR/cert.pem"
    local fullchainfile="$DOMAINDIR/fullchain.pem"
    local key_sha256
    key_sha256="$(hpkp_sha256 "$keyfile")"

    patch_route "$NAMESPACE" "$ROUTE_NAME" '
        { "metadata": {
            "labels": {
              "butter.sh/letsencrypt-key-sha256": "'"$key_sha256"'",
            },
            "annotations": {
              "butter.sh"
            }
          },
          "spec": { "tls": {
            "key": "'"$(json_escape < "$keyfile")"'",
            "certificate": "'"$(json_escape < "$fullchainfile")"'",
            "insecureEdgeTerminationPolicy": "'"$INSECURE_EDGE_TERMINATION_POLICY"'",
            "termination": "edge"
          } }
        }'
}

mount_secret() {
    local SECRET_NAME="$1"
    local MOUNT_PATH="$2"

    pushd "$MOUNT_PATH"
    # shellcheck disable=SC2016
    local tmpl='{{range $key,$val := .data}}{{$key}}:{{$val}}
{{end}}'
    oc get secret "$SECRET_NAME" --template="$tmpl" \
        | while IFS=: read -r k v;
            do echo "$v" | base64 -d > "$k"
        done
    popd
}
