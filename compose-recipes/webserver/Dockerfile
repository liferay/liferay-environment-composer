ARG PROTOCOL

FROM nginx:latest

COPY build/config/default.conf /etc/nginx/conf.d

RUN ([ "${PROTOCOL}" -eq "https" ] && mkdir -p /etc/nginx/certs) || echo

COPY build*/ssl*/server.crt* /etc/nginx/certs
COPY build*/ssl*/server.key* /etc/nginx/certs