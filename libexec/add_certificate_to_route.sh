#!/bin/bash -e

DOMAIN_NAME="$1"
NAMESPACE="$2"
ROUTE_NAME="$3"
INSECURE_EDGE_TERMINATION_POLICY="$4"

patch_route "$NAMESPACE" "$ROUTE_NAME" '
{ "metadata": {
  },
  "spec": { "tls": {
    "key": "'$(<$keyfile)'",
    "certificate": "'$(<$crtfile)'",
    "insecureEdgeTerminationPolicy": "'$INSECURE_EDGE_TERMINATION_POLICY'",
    "termination": "edge"
  } }
}
'
