FROM owasp/modsecurity-crs:nginx AS modsec_source

# --- Stage 1: Builder (SSL Only) ---

FROM alpine/openssl AS builder

ARG PROTOCOL
ARG WEBSERVER_HOSTNAMES

WORKDIR /build

RUN if [ "$PROTOCOL" = "https" ]; then \
      mkdir -p ssl && \
      CN=$(echo $WEBSERVER_HOSTNAMES | awk '{print $1}') && \
      SAN=$(echo $WEBSERVER_HOSTNAMES | sed 's/ /,DNS:/g' | sed 's/^/DNS:/') && \
      openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
        -keyout ssl/server.key -out ssl/server.crt \
        -subj "/CN=$CN" \
        -addext "subjectAltName=$SAN"; \
    fi

# Stage 2: Final Nginx Image

FROM nginx:1.26.3

# 1. Direct Template Deployment 🏗️

COPY templates/config/base.conf.template /etc/nginx/templates/default.conf.template
COPY templates/config/*.conf.template /etc/nginx/templates/partials/

# 2. Explicit SSL & ModSecurity Deployment 🛡️

COPY --from=builder /build/ssl/server.crt /etc/nginx/certs/
COPY --from=builder /build/ssl/server.key /etc/nginx/certs/
COPY --from=modsec_source /etc/modsecurity.d/owasp-crs/crs-setup.conf* /etc/nginx/modsec/
COPY --from=modsec_source /etc/modsecurity.d/owasp-crs/rules/ /etc/nginx/modsec/rules/