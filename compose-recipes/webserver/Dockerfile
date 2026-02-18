ARG WEBSERVER_MODSECURITY_ENABLED=false

FROM alpine/openssl AS builder

ARG PROTOCOL
ARG WEBSERVER_HOSTNAMES

WORKDIR /build

RUN mkdir -p ssl && \
    if [ "$PROTOCOL" = "https" ]; then \
      CN=$(echo $WEBSERVER_HOSTNAMES | awk '{print $1}') && \
      SAN=$(echo $WEBSERVER_HOSTNAMES | sed 's/ /,DNS:/g' | sed 's/^/DNS:/') && \
      openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
        -keyout ssl/server.key -out ssl/server.crt \
        -subj "/CN=$CN" \
        -addext "subjectAltName=$SAN"; \
    fi

FROM nginx:1.26.3 AS nginx_modsecurity_enabled_false

COPY templates/config/base.conf.template /etc/nginx/templates/default.conf.template
COPY templates/config/*.conf.template /etc/nginx/templates/partials/
COPY --from=builder /build/ssl/* /etc/nginx/certs/

FROM owasp/modsecurity-crs:nginx AS nginx_modsecurity_enabled_true

COPY templates/config/base.conf.template /etc/nginx/templates/conf.d/default.conf.template
COPY templates/config/*.conf.template /etc/nginx/templates/conf.d/partials/
COPY --from=builder --chown=nginx:nginx /build/ssl/* /etc/nginx/certs/

FROM nginx_modsecurity_enabled_${WEBSERVER_MODSECURITY_ENABLED} AS nginx

HEALTHCHECK --interval=10s --timeout=5s --start-period=5s --retries=3 \
    CMD if [ "$PROTOCOL" = "https" ]; then \
        curl -fk https://localhost:8443/healthz; \
    else \
        curl -f http://localhost:8080/healthz; \
    fi

FROM nginx