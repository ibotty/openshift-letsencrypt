FROM openshift/base-centos7

ENV LETSENCRYPT_SH_COMMIT=d81eb58536e3ae1170de3eda305688ae28d0575b \
    LETSENCRYPT_DATADIR=/var/lib/letsencrypt-container \
    LETSENCRYPT_LIBEXECDIR=/usr/libexec/letsencrypt-container \
    LETSENCRYPT_SHAREDIR=/usr/share/letsencrypt-container


USER 0

RUN curl -sSL https://github.com/lukas2511/dehydrated/raw/$LETSENCRYPT_SH_COMMIT/dehydrated \
         -o /usr/bin/dehydrated \
 && chmod +x /usr/bin/dehydrated \
 && yum install -y openssl curl nss_wrapper jq \
 && yum clean all

USER 1001

ADD libexec/ $LETSENCRYPT_LIBEXECDIR
ADD share/ $LETSENCRYPT_SHAREDIR

ENTRYPOINT ["/usr/libexec/letsencrypt-container/entrypoint"]
CMD ["usage"]
