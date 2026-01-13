ARG MODSECURITY_ENABLED
ARG PROTOCOL

FROM nginx:latest

COPY build/config/default.conf /etc/nginx/conf.d

RUN ([ "${PROTOCOL}" -eq "https" ] && mkdir -p /etc/nginx/certs) || echo

COPY build*/ssl*/server.* /etc/nginx/certs/

RUN ([ "${MODSECURITY_ENABLED}" -eq "true"] && mkdir -p /etc/nginx/modsec) || echo
COPY build*/config*/rules* /etc/nginx/modsec
COPY build*/config*/crs-setup.conf* /etc/nginx/modsec
RUN ([ "${MODSECURITY_ENABLED}" -eq "true"] && echo 'Include /etc/nginx/modsec/rules/*.conf' > /etc/nginx/modsec/owasp-crs-rules.conf) || echo