FROM owasp/modsecurity-crs:nginx AS modsec_source

# --- Stage 1: Builder (SSL Only) ---

FROM alpine:latest AS builder

RUN apk add --no-cache openssl gettext

ARG PROTOCOL
ARG WEBSERVER_HOSTNAMES

WORKDIR /build

# Copy the templates folder directly into the builder stage

COPY templates /templates

# Generate SSL certs only if protocol is https

RUN if [ "$PROTOCOL" = "https" ]; \
    then \
      mkdir -p ssl && \
      export hostname=$(echo $WEBSERVER_HOSTNAMES | awk '{print $1}') && \
	I=1; SAN_ENTRIES=""; for host in $WEBSERVER_HOSTNAMES; do SAN_ENTRIES="${SAN_ENTRIES}DNS.$i = $host\n"; i=$((i+1)); done; \
      export sanEntries="$SAN_ENTRIES" && \
      envsubst < /templates/ssl/openssl.cnf.template > ssl/openssl.cnf && \
      openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout ssl/server.key -out ssl/server.crt -config ssl/openssl.cnf -subj "/CN=$hostname"; \
    fi

# --- Stage 2: Final Image ---

FROM nginx:1.26.3

COPY templates /templates

# 1. Deploy Main Template to Nginx's auto-process folder

RUN mkdir -p /etc/nginx/templates && \
    cp /templates/config/base.conf.template /etc/nginx/templates/default.conf.template

# 2. Deploy Partials to the subdirectory (including both upstream versions)

RUN mkdir -p /etc/nginx/templates/partials && \
    cp /templates/config/*.conf.template /etc/nginx/templates/partials/

# 3. Handle SSL and ModSecurity

COPY --from=builder /build/ssl*/server.* /etc/nginx/certs/
COPY --from=modsec_source /etc/modsecurity.d/owasp-crs/crs-setup.conf* /etc/nginx/modsec/
COPY --from=modsec_source /etc/modsecurity.d/owasp-crs/rules* /etc/nginx/modsec/rules/