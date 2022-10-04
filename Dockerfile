FROM alpine:3.16.0

RUN apk add --no-cache \
    pdns \
    pdns-recursor \
    pdns-backend-sqlite3 \
    sqlite \
    pdns-doc \
    py3-pip \
    bash \
    python3

RUN pip3 install --no-cache-dir 'Jinja2<3.1' envtpl

ENV VERSION=4.6 \
  PDNS_guardian=yes \
  PDNS_api=yes \
  PDNS_setuid=pdns \
  PDNS_setgid=pdns \
  PDNS_launch=gsqlite3 \
  PDNS_gsqlite3_database=/data/powerdns.sqlite3 \
  PDNS_local_port=5300 \
  PDNS_local_address=127.0.0.1 \
  PDNS_webserver=yes \
  PDNS_webserver_address=0.0.0.0 \
  PDNS_webserver_allow_from=10.0.0.0/8 \
  RECURSOR_setuid=recursor \
  RECURSOR_setgid=recursor \
  RECURSOR_daemon=no \
  RECURSOR_local_port=53 \
  RECURSOR_local_address=0.0.0.0

EXPOSE 53 53/udp 8081 5300 5300/udp

COPY pdns.conf.tpl /
COPY recursor.conf.tpl /
COPY entrypoint.sh /


RUN mkdir -p /data \
  && chown -R pdns:pdns /data \
  && mkdir -p /etc/pdns/api.d \
  && chown -R recursor:recursor /etc/pdns/api.d \
  && chmod 755 /entrypoint.sh \
  && mkdir -p /var/run/pdns-recursor \
  && chown -R recursor:recursor /var/run/pdns-recursor \
  && mkdir -p /var/run/pdns \
  && chown -R pdns:pdns /var/run/pdns

CMD [ "/entrypoint.sh" ]

