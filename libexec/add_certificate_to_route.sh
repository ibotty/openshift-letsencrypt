#!/bin/bash -e

DOMAINNAME="$1"
DOMAINDIR="$LETSENCRYPT_DATADIR/$DOMAINNAME"
NAMESPACE="$2"
ROUTE_NAME="$3"
if [ $# -eq 4 -a -n $4 ]; then
    INSECURE_EDGE_TERMINATION_POLICY="$4"
else
    INSECURE_EDGE_TERMINATION_POLICY=$LETSENCRYPT_DEFAULT_INSECURE_EDGE_TERMINATION_POLICY
fi

keyfile="$DOMAINDIR/privkey.pem"
crtfile="$DOMAINDIR/cert.pem"
fullchainfile="$DOMAINDIR/fullchain.pem"
key_sha256="$(hpkp_sha256 $keyfile)"

patch_route "$NAMESPACE" "$ROUTE_NAME" '
{ "metadata": {
    "labels": {
      "butter.sh/letsencrypt-key-sha256": "'$key_sha256'",
  },
  "spec": { "tls": {
    "key": "'$(json_escape < $keyfile)'",
    "certificate": "'$(json_escape < $crtfile)'",
    "insecureEdgeTerminationPolicy": "'$INSECURE_EDGE_TERMINATION_POLICY'",
    "termination": "edge"
  } }
}
'
