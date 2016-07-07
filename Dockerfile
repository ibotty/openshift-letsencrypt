FROM openshift/origin:v1.2.0

ENV LETSENCRYPT_SH_VERSION 0.2.0

USER 0

RUN curl -sSL https://github.com/lukas2511/letsencrypt.sh/archive/v${LETSENCRYPT_SH_VERSION}.tar.gz \
    | tar xzC /usr/share \
 && ln -s /usr/share/letsencrypt.sh-${LETSENCRYPT_SH_VERSION}/letsencrypt.sh /usr/bin \
 && yum install -y openssl nss_wrapper

USER 1001

ADD libexec/ /usr/libexec/letsencrypt-container
ADD share/ /usr/share/letsencrypt-container

ENTRYPOINT /usr/libexec/letsencrypt-container/entrypoint.sh
CMD [usage]
