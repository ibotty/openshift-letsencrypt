#!/bin/bash
# shellcheck disable=SC2120,SC2119

export LETSENCRYPT_SERVICE_NAME=${LETSENCRYPT_SERVICE_NAME-letsencrypt}
export LETSENCRYPT_ACME_SECRET_NAME="${LETSENCRYPT_ACME_SECRET_NAME-letsencrypt-creds}"
export LETSENCRYPT_DEFAULT_INSECURE_EDGE_TERMINATION_POLICY="${LETSENCRYPT_DEFAULT_INSECURE_EDGE_TERMINATION_POLICY-Redirect}"
export LETSENCRYPT_ROUTE_SELECTOR="${LETSENCRYPT_ROUTE_SELECTOR-butter.sh/letsencrypt-managed=yes}"
export LETSENCRYPT_KEYTYPE="${LETSENCRYPT_KEYTYPE-rsa}"
export LETSENCRYPT_RENEW_BEFORE_DAYS=${LETSENCRYPT_RENEW_BEFORE_DAYS-30}
export LETSENCRYPT_VERBOSE="${LETSENCRYPT_VERBOSE-yes}"
export LETSENCRYPT_CA="${LETSENCRYPT_CA-https://acme-v01.api.letsencrypt.org/directory}"
export LETSENCRYPT_KEYTYPE="${LETSENCRYPT_KEYTYPE-rsa}"
export LETSENCRYPT_KEYSIZE="${LETSENCRYPT_KEYSIZE-4096}"

PATH=${LETSENCRYPT_LIBEXECDIR}:$PATH

OPENSHIFT_API_HOST=openshift.default
SA_TOKEN="$(</run/secrets/kubernetes.io/serviceaccount/token)"
OWN_NAMESPACE="$(</run/secrets/kubernetes.io/serviceaccount/namespace)"
CA_CRT_FILE=/run/secrets/kubernetes.io/serviceaccount/ca.crt

keyfile() {
    echo "$LETSENCRYPT_DATADIR/$1/key"
}

certfile() {
    echo "$LETSENCRYPT_DATADIR/$1/crt"
}

fullchainfile() {
    echo "$LETSENCRYPT_DATADIR/$1/fullchain"
}

err() {
    echo "${@-}" >&2
}

log() {
    is_true "$LETSENCRYPT_VERBOSE" && echo "$@"
}

is_true() {
    case "$1" in
        y|yes|1|t|true)
            true
            ;;
        *)
            false
            ;;
    esac
}
api_call() {
    local uri="${1##/}"; shift
    curl --fail -sSH "Authorization: Bearer $SA_TOKEN" \
         --cacert "$CA_CRT_FILE" \
	     "https://$OPENSHIFT_API_HOST/$uri" \
	     "$@" 2> /dev/null
    if ! [ "$?" -eq 0 ]; then
        curl -sSH "Authorization: Bearer $SA_TOKEN" \
            --cacert "$CA_CRT_FILE" \
            "https://$OPENSHIFT_API_HOST/$uri" "$@"
        false
    fi
}

watch_routes() {
    local routes_uri
    routes_uri="$(route_uri)"
    if [ -n "$LETSENCRYPT_ROUTE_SELECTOR" ]; then
        routes_uri="$routes_uri?labelSelector=$LETSENCRYPT_ROUTE_SELECTOR&watch"
    fi
    api_call "$routes_uri" -N
}

get_routes() {
    local routes_uri
    routes_uri="$(route_uri)"
    if [ -n "$LETSENCRYPT_ROUTE_SELECTOR" ]; then
        routes_uri="$routes_uri?labelSelector=$LETSENCRYPT_ROUTE_SELECTOR"
    fi
    api_call "$routes_uri"
}
		
		
route_uri() {
    local name="${1-}"
    local namespace="${2-$OWN_NAMESPACE}"
    echo "/oapi/v1/namespaces/$namespace/routes/$name"
}

route_exists() {
    api_call "$(route_uri "$@")" > /dev/null 2>&1
}

route_is_valid() {
    local domain="$1"
    local magic="openshift-letsencrypt"

    echo "$magic" > /var/www/acme-challenge/.owner
    test "$(curl -fs "$1/.well-known/acme-challenge/.owner")" = "$magic"
}

patch_route() {
    api_call "$1" --request PATCH --data "$2" \
        -H 'Content-Type: application/merge-patch+json' \
        > /dev/null
}

get_certs_from_route() {
    local domain="$1" selflink="$2"
    local keytmpl='.spec.tls.key'
    local certtmpl='.spec.tls.certificate'

    route_json="$(api_call "$selflink")"
    mkdir -p "$LETSENCRYPT_DATADIR/$domain"
    echo "$route_json" | jq -er "$certtmpl" > "$(fullchainfile "$domain")"
    echo "$route_json" | jq -er "$keytmpl" > "$(keyfile "$domain")"
    # don't bother with a split out cert
    cp "$(fullchainfile "$domain")" "$(certfile "$domain")"
}

json_escape() {
    jq -eRs .
}

random_chars() {
    local count="${1-5}"
    tr -dc 'a-z0-9' < /dev/urandom | head -c "$count"
}

crt_enddate() {
    userfriendly_date "$(crt_enddate_secs "$1")"
}

crt_enddate_secs() {
    date_in_secs "$(openssl x509 -noout -enddate -in "$1" | cut -d= -f2)"
}

crt_valid_long_enough() {
    [ -f "$1" ] && [ "$(min_valid_enddate_secs)" -lt "$(crt_enddate_secs "$1")" ]
}

userfriendly_date() {
    date -Iseconds -u -d "@$1"
}

date_in_secs() {
    local datespec=("-u" "+%s")
    if [ $# -eq 1 ]; then
        datespec+=("-d" "$1")
    fi
    date "${datespec[@]}"
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

    echo "butter.sh/letsencrypt-crt-enddate-secs>$min_valid_secs,butter.sh/letsencrypt-domainname=$DOMAINNAME"
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

well_known_route_name() {
    local domainname="$1"
    echo "letsencrypt-$domainname"
}

add_well_known_route() {
    export DOMAINNAME="$1"
    export TEMP_ROUTE_NAME; TEMP_ROUTE_NAME="$(well_known_route_name "$DOMAINNAME")"

    envsubst < "$LETSENCRYPT_SHAREDIR/new-well-known-route.json.tmpl" \
	| api_call "$(route_uri)" -X POST -d @- -H 'Content-Type: application/json' \
	> /dev/null

}
delete_well_known_route() {
    local DOMAINNAME="$1"
    local TEMP_ROUTE_NAME; TEMP_ROUTE_NAME="$(well_known_route_name "$DOMAINNAME")"
    api_call "$(route_uri "$TEMP_ROUTE_NAME")" -X DELETE
}

add_certificate_to_route() {
    local DOMAINNAME="$1"
    local SELFLINK="$2"

    if [ $# -eq 4 ] && [ -n "$4" ]; then
        local INSECURE_EDGE_TERMINATION_POLICY="$4"
    else
        local INSECURE_EDGE_TERMINATION_POLICY=$LETSENCRYPT_DEFAULT_INSECURE_EDGE_TERMINATION_POLICY
    fi

    local keyfile_; keyfile_="$(keyfile "$DOMAINNAME")"
    local certfile_; certfile_="$(certfile "$DOMAINNAME")"
    local fullchainfile_; fullchainfile_="$(fullchainfile "$DOMAINNAME")"
    local key_sha256; key_sha256="$(hpkp_sha256 "$keyfile_")"
    local enddate_secs; enddate_secs="$(crt_enddate_secs "$certfile_")"

    local data; data="$(cat <<EOF
        { "metadata": {
            "annotations": {
              "butter.sh/letsencrypt-crt-enddate-secs": "$enddate_secs",
              "butter.sh/letsencrypt-key-sha256": "$key_sha256"
            }
          },
          "spec": { "tls": {
            "key": $(json_escape < "$keyfile_"),
            "certificate": $(json_escape < "$fullchainfile_"),
            "insecureEdgeTerminationPolicy": "$INSECURE_EDGE_TERMINATION_POLICY",
            "termination": "edge"
          } }
        }
EOF
    )"
    patch_route "$SELFLINK" "$data"
}

get_secret() {
    local name="$1"
    api_call "/api/v1/namespaces/$OWN_NAMESPACE/secrets/$name"
}

mount_secret() {
    local MOUNT_PATH="$1"

    mkdir -p "$MOUNT_PATH"
    local tmpl='.data | to_entries | map(.key+":"+.value) | join("\n")'

    jq -er "$tmpl" | while IFS=: read -r k v;
        do echo -n "$v" | base64 -d > "$MOUNT_PATH/$k"
    done
}

new_cert_secret() {
    local domainname="$1" keyfile_="$2" crtfile_="$3" fullchainfile_="$4"
    local secret_name; secret_name="letsencrypt-${domainname}-$(random_chars)"

    local data; data="$(cat <<EOF
{ "apiVersion": "v1",
  "kind": "Secret",
  "metadata": {
    "name": "$secret_name",
    "labels": {
      "butter.sh/letsencrypt-crt-enddate-secs": "$(crt_enddate_secs "$crtfile_")",
      "butter.sh/letsencrypt-domainname": "$domainname"
    },
    "annotations": {
      "butter.sh/letsencrypt-key-sha256": "$(hpkp_sha256 "$keyfile_")"
    }
  },
  "data": {
    "key": $(base64 "$keyfile_" | json_escape),
    "fullchain": $(base64 "$fullchainfile_" | json_escape),
    "crt": $(base64 "$crtfile_" | json_escape)
  }
}
EOF
)"

    api_call "/api/v1/namespaces/$OWN_NAMESPACE/secrets" -X POST -d "$data" \
        -H "Content-Type: application/json" \
        > /dev/null
}
