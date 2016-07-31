FROM openshift/origin:v1.2.1

ENV LETSENCRYPT_SH_VERSION=0.2.0 \
    LETSENCRYPT_DATADIR=/var/lib/letsencrypt-container \
    LETSENCRYPT_LIBEXECDIR=/usr/libexec/letsencrypt-container \
    LETSENCRYPT_SHAREDIR=/usr/share/letsencrypt-container

USER 0

RUN curl -sSL https://github.com/lukas2511/letsencrypt.sh/archive/v${LETSENCRYPT_SH_VERSION}.tar.gz \
    | tar xzC /usr/share \
 && ln -s /usr/share/letsencrypt.sh-${LETSENCRYPT_SH_VERSION}/letsencrypt.sh /usr/bin \
 && yum install -y openssl curl nss_wrapper python

USER 1001

ADD libexec/ $LETSENCRYPT_LIBEXECDIR
ADD share/ $LETSENCRYPT_SHAREDIR

ENTRYPOINT ["$LETSENCRYPT_LIBEXECDIR/entrypoint.sh"]
CMD ["usage"]
