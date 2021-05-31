FROM alpine:3.13 as alpine_builder
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

FROM alpine_builder as build_dovecot
COPY --chown=builder:abuild dovecot/ /home/builder/package/

USER builder

RUN cd /home/builder/package \
 && export RSA_PRIVATE_KEY_NAME=patrickdk@patrickdk.com-609e9f0e.rsa \
 && export PACKAGER_PRIVKEY=//etc/apk/keys/${RSA_PRIVATE_KEY_NAME} \
 && export REPODEST=/packages \
 && abuild-apk update \
 && abuild -r

FROM alpine_builder as build_xapian
COPY --from=build_dovecot /packages/builder/x86_64/dovecot*.apk /tmp/

COPY --chown=builder:abuild dovecot-fts-xapian/ /home/builder/package/

RUN cd /tmp/ \
 && apk add --no-cache dovecot-gssapi-2.*.apk dovecot-mysql-2.*.apk dovecot-pigeonhole-plugin-2.*.apk dovecot-sql-2.*.apk \
    dovecot-2.*.apk dovecot-fts-lucene-2.*.apk dovecot-lmtpd-2.*.apk dovecot-pop3d-2.*.apk dovecot-submissiond-2.*.apk \
    dovecot-dev-2.*.apk

USER builder

RUN cd /home/builder/package \
 && export RSA_PRIVATE_KEY_NAME=patrickdk@patrickdk.com-609e9f0e.rsa \
 && export PACKAGER_PRIVKEY=//etc/apk/keys/${RSA_PRIVATE_KEY_NAME} \
 && export REPODEST=/packages \
 && abuild-apk update \
 && abuild -r


FROM alpine:3.13

COPY .abuild/patrickdk@patrickdk.com-609e9f0e.rsa.pub /etc/apk/keys/
COPY --from=build_dovecot /packages/builder/x86_64/dovecot*.apk /root/
COPY --from=build_xapian /packages/builder/x86_64/dovecot*.apk /root/

RUN cd /root/ \
 && apk upgrade --no-cache \
 && ls -la /root/ \
 && apk add --no-cache dovecot-gssapi-2.*.apk dovecot-mysql-2.*.apk dovecot-pigeonhole-plugin-2.*.apk dovecot-sql-2.*.apk \
    dovecot-2.*.apk dovecot-fts-lucene-2.*.apk dovecot-lmtpd-2.*.apk dovecot-pop3d-2.*.apk dovecot-submissiond-2.*.apk \
    dovecot-fts-xapian-1.*.apk \
 && apk add --no-cache ca-certificates tzdata \
 && mkdir /run/dovecot \
 && addgroup -g 30000 vmail \
 && adduser -Ds /bin/false -u 30000 -G vmail -h /var/mail vmail \
 && sed -i -e's|^!include|#!include|' /etc/dovecot/conf.d/*.conf \
 && sed -i -e 's|^#!/usr/bin/env bash$|#!/bin/sh|' /usr/libexec/dovecot/health-check.sh

COPY src /etc/dovecot/conf.d

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

CMD ["/usr/sbin/dovecot", "-F"]
#HEALTHCHECK CMD ["sh", "-c", "echo PING | nc 127.0.0.1 5001 | grep -q PONG"]
