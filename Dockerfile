ARG BUILD_FROM=alpine:3.21

FROM ${BUILD_FROM} as alpine_builder
COPY .abuild/ /etc/apk/keys/
RUN apk --no-cache add alpine-sdk coreutils cmake sudo bash \
 && adduser -G abuild -g "Alpine Package Builder" -s /bin/bash -D -h /home/builder builder \
 && echo "builder ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers \
 && mkdir /packages \
 && chown builder:abuild /packages \
 && mkdir -p /var/cache/apk \
 && ln -s /var/cache/apk /etc/apk/cache \
 && chown builder /etc/apk/keys/*.rsa \
 && mkdir -p /home/builder/.abuild /home/builder/packages \
 && chown -R builder:abuild /home/builder/packages

#FROM alpine_builder as build_stemmer
##COPY --chown=builder:abuild libstemmer/ /home/builder/package/
#COPY --chown=builder:abuild snowball/ /home/builder/package/
#USER builder
#RUN cd /home/builder/package \
# && export RSA_PRIVATE_KEY_NAME=patrickdk@patrickdk.com-609e9f0e.rsa \
# && export PACKAGER_PRIVKEY=/etc/apk/keys/${RSA_PRIVATE_KEY_NAME} \
# && export REPODEST=/packages \
# && abuild-apk update \
# && abuild -r

FROM alpine_builder as build_zstd
COPY --chown=builder:abuild zstd/ /home/builder/package/
USER builder
RUN  cd /home/builder/package \
 && export RSA_PRIVATE_KEY_NAME=patrickdk@patrickdk.com-609e9f0e.rsa \
 && export PACKAGER_PRIVKEY=/etc/apk/keys/${RSA_PRIVATE_KEY_NAME} \
 && export REPODEST=/packages \
 && abuild-apk update \
 && abuild -r

FROM alpine_builder as build_dovecot
#COPY --from=build_stemmer /packages/builder/*/libstemmer*.apk /tmp/
COPY --from=build_zstd /packages/builder/*/zstd*.apk /tmp/
COPY --chown=builder:abuild dovecot/ /home/builder/package/
RUN cd /tmp/ \
  && apk add --no-cache zstd*.apk
USER builder
RUN  cd /home/builder/package \
 && export RSA_PRIVATE_KEY_NAME=patrickdk@patrickdk.com-609e9f0e.rsa \
 && export PACKAGER_PRIVKEY=/etc/apk/keys/${RSA_PRIVATE_KEY_NAME} \
 && export REPODEST=/packages \
 && abuild-apk update \
 && abuild -r

FROM alpine_builder as build_xapian
#COPY --from=build_stemmer /packages/builder/*/libstemmer*.apk /tmp/
COPY --from=build_zstd /packages/builder/*/zstd*.apk /tmp/
COPY --from=build_dovecot /packages/builder/*/dovecot*.apk /tmp/
COPY --chown=builder:abuild dovecot-fts-xapian/ /home/builder/package/
RUN cd /tmp/ \
 && apk add --no-cache dovecot*.apk dovecot-dev*.apk
USER builder
RUN cd /home/builder/package \
 && export RSA_PRIVATE_KEY_NAME=patrickdk@patrickdk.com-609e9f0e.rsa \
 && export PACKAGER_PRIVKEY=/etc/apk/keys/${RSA_PRIVATE_KEY_NAME} \
 && export REPODEST=/packages \
 && abuild-apk update \
 && abuild -r

FROM alpine_builder as build_flatcurve
#COPY --from=build_stemmer /packages/builder/*/libstemmer*.apk /tmp/
COPY --from=build_zstd /packages/builder/*/zstd*.apk /tmp/
COPY --from=build_dovecot /packages/builder/*/dovecot*.apk /tmp/
COPY --chown=builder:abuild dovecot-fts-flatcurve/ /home/builder/package/
RUN cd /tmp/ \
 && apk add --no-cache dovecot*.apk dovecot-dev*.apk
USER builder
RUN cd /home/builder/package \
 && export RSA_PRIVATE_KEY_NAME=patrickdk@patrickdk.com-609e9f0e.rsa \
 && export PACKAGER_PRIVKEY=/etc/apk/keys/${RSA_PRIVATE_KEY_NAME} \
 && export REPODEST=/packages \
 && abuild-apk update \
 && abuild -r

FROM ${BUILD_FROM} as build_packages
#COPY --from=build_stemmer /packages/builder/*/libstemmer*.apk /packages/
COPY --from=build_zstd /packages/builder/*/zstd-lib*.apk /packages/
COPY --from=build_dovecot /packages/builder/*/dovecot*.apk /packages/
COPY --from=build_xapian /packages/builder/*/dovecot*.apk /packages/
COPY --from=build_flatcurve /packages/builder/*/dovecot*.apk /packages/
RUN rm -f /packages/*-dev-* /packages/*-doc-* /packages/*-ldap-* /packages/*-solr-* /packages/*-pgsql-* /packages/*-dbg-* \
 && ls -la /packages


FROM ${BUILD_FROM}
#COPY .abuild/patrickdk@patrickdk.com-609e9f0e.rsa.pub /etc/apk/keys/
#COPY bin/ /usr/local/bin/

RUN \
 --mount=type=bind,source=.abuild/patrickdk@patrickdk.com-609e9f0e.rsa.pub,target=/etc/apk/keys/patrickdk@patrickdk.com-609e9f0e.rsa.pub \
 --mount=type=bind,from=build_packages,source=/packages,target=/packages \
 --mount=type=bind,source=bin,target=/tmp/bin \
 --mount=type=bind,source=src,target=/tmp/src \
 cd /packages/ \
 && cp -a /tmp/bin/* /usr/local/bin/ \
 && apk upgrade --no-cache \
 && ls -la /packages/ \
 && apk add --no-cache *.apk \
# && apk add --no-cache dovecot-gssapi*.apk dovecot-mysql*.apk dovecot-pigeonhole-plugin-2*.apk dovecot-sql*.apk \
#    dovecot-2*.apk dovecot-fts*.apk dovecot-lmtpd*.apk dovecot-pop3d*.apk dovecot-submissiond*.apk \
#libstemmer-2*.apk \
# && ln -s /usr/lib/libstemmer.so.2.1.0 /usr/lib/libstemmer.so.2.1 \
# && ln -s /usr/lib/libstemmer.so.2.1.0 /usr/lib/libstemmer.so.2 \
 && apk add --no-cache ca-certificates tzdata bash perl perl-io-socket-inet6 perl-io-socket-ssl \
 && mkdir /run/dovecot \
 && addgroup -g 30000 vmail \
 && adduser -Ds /bin/false -u 30000 -G vmail -h /var/mail vmail \
 && sed -i -e's|^!include|#!include|' /etc/dovecot/conf.d/*.conf \
 && sed -i -e 's|^#!/usr/bin/env bash$|#!/bin/sh|' /usr/libexec/dovecot/health-check.sh \
 && cp -a /tmp/src/* /etc/dovecot/conf.d/

#COPY src /etc/dovecot/conf.d

# dovecot needs root access to bind ports below 1024, but will drop privileges
USER root:root

#   24: LMTP
#  110: POP3 (StartTLS)
#  143: IMAP4 (StartTLS)
#  993: IMAP (SSL, deprecated)
#  995: POP3 (SSL, deprecated)
# 4190: ManageSieve (StartTLS)
EXPOSE 24/tcp 110/tcp 143/tcp 993/tcp 995/tcp 4190/tcp

#VOLUME /var/mail /run/dovecot /tmp /var/lib/dovecot

CMD ["/usr/local/bin/docker-run"]
#CMD ["/usr/sbin/dovecot", "-F"]
#HEALTHCHECK CMD ["sh", "-c", "echo PING | nc 127.0.0.1 5001 | grep -q PONG"]

ARG BUILD_DATE BUILD_REF BUILD_VERSION
LABEL maintainer="Patrick Domack (patrickdk@patrickdk.com)" \
  Description="Lightweight container for Dovecot based on Alpine Linux." \
  org.label-schema.schema-version="1.0" \
  org.label-schema.build-date="${BUILD_DATE}" \
  org.label-schema.name="docker-dovecot" \
  org.label-schema.description="Dovecot alpine base image" \
  org.label-schema.url="https://github.com/patrickdk77/docker-dovecot/" \
  org.label-schema.usage="https://github.com/patrickdk77/docker-dovecot/tree/master/README.md" \
  org.label-schema.vcs-url="https://github.com/patrickdk77/docker-dovecot" \
  org.label-schema.vcs-ref="${BUILD_REF}" \
  org.label-schema.version="${BUILD_VERSION}" \
  org.opencontainers.image.authors="Patrick Domack (patrickdk@patrickdk.com)" \
  org.opencontainers.image.created="${BUILD_DATE}" \
  org.opencontainers.image.title="docker-dovecot" \
  org.opencontainers.image.description="Dovecot ubuntu image" \
  org.opencontainers.image.version="${BUILD_VERSION}" \
  version="${BUILD_VERSION}"
