FROM alpine:latest

LABEL org.opencontainers.image.source https://github.com/feshchenkod/docker-nginx-ssl-proxy

ARG S6_OVERLAY_VERSION=v3.1.5.0
ENV S6_GLOBAL_PATH=/command:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

RUN apk add --no-cache wget curl certbot pwgen brotli nginx nginx-mod-http-brotli bash openssl

# ---> INSTALLING s6-overlay
RUN set -ex; \
    curl \
      --proto '=https' --tlsv1.2 -sSLf \
      "https://github.com/just-containers/s6-overlay/releases/download/${S6_OVERLAY_VERSION}/s6-overlay-noarch.tar.xz" \
      | tar -JxpC /; \
    curl \
      --proto '=https' --tlsv1.2 -sSLf \
      "https://github.com/just-containers/s6-overlay/releases/download/${S6_OVERLAY_VERSION}/s6-overlay-x86_64.tar.xz" \
      | tar -JxpC /;

# ---> INSTALLING envplate
RUN curl -sLo /usr/local/bin/ep https://github.com/kreuzwerker/envplate/releases/download/1.0.0-RC1/ep-linux && chmod +x /usr/local/bin/ep

# ---> CREATING CloudFlare Config Snippet (not included in config by default)
RUN echo '#Cloudflare' > /etc/nginx/cloudflare.conf \
    && wget https://www.cloudflare.com/ips-v4 \
    && sort ips-v4 > ips-v4.sorted \
    && cat ips-v4 | sed -e 's/^/set_real_ip_from /' -e 's/$/;/' >> /etc/nginx/cloudflare.conf \
    && wget https://www.cloudflare.com/ips-v6 \
    && sort ips-v6 > ips-v6.sorted \
    && cat ips-v6 | sed -e 's/^/set_real_ip_from /' -e 's/$/;/' >> /etc/nginx/cloudflare.conf \
    && rm ips-v6 ips-v4 ips-v6.sorted ips-v4.sorted

# ---> Creating directories
RUN mkdir -p /etc/services.d/nginx /etc/services.d/certbot \
    && touch /etc/nginx/auth_part1.conf \
             /etc/nginx/auth_part2.conf \
             /etc/nginx/request_size.conf \
             /etc/nginx/main_location.conf \
             /etc/nginx/trusted_proxies.conf \
             /tmp/htpasswd

COPY services.d/nginx/* /etc/services.d/nginx/
COPY services.d/certbot/* /etc/services.d/certbot/
COPY nginx.conf security_headers.conf hsts.conf /etc/nginx/
COPY proxy.conf /etc/nginx/conf.d/default.conf
COPY auth_part*.conf /root/
COPY dhparams.pem /etc/nginx/
COPY temp-setup-cert.pem /etc/nginx/temp-server-cert.pem
COPY temp-setup-key.pem /etc/nginx/temp-server-key.pem

VOLUME "/etc/letsencrypt"

ENTRYPOINT ["/init"]
CMD []
