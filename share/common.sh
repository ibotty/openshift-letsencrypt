export LETSENCRYPT_ALL_NAMESPACES=${LETSENCRYPT_ALL_NAMESPACES-}
export LETSENCRYPT_ROUTE_SELECTOR="${LETSENCRYPT_ROUTE_SELECTOR-butter.sh/letsencrypt-managed=yes}"

export OC_GET_ROUTES="oc get routes"
if [ -n $LETSENCRYPT_ALL_NAMESPACES ]; then
    OC_GET_ROUTES="oc get routes --all-namespaces"
fi
if [ -n "$LETSENCRYPT_ROUTE_SELECTOR" ]; then
    OC_GET_ROUTES="$OC_GET_ROUTES -l $LETSENCRYPT_ROUTE_SELECTOR"
fi

err() {
    echo "$@" >&2
}

patch_route() {
    oc patch -n $1 route/$2 -p "$3" > /dev/null
}

