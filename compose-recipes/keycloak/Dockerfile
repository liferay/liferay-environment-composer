FROM registry.access.redhat.com/ubi9/ubi-minimal AS toolbox

ARG LIFERAY_PORT=8080

COPY conf/* /tmp

RUN sed -i "s@<CERT>@$(grep -e '-----' -v /tmp/server.crt | sed -z 's:\n::g')@g" /tmp/master-realm.json && \
    sed -i "s@<LIFERAY_PORT>@${LIFERAY_PORT}@g" /tmp/master-realm.json

FROM quay.io/keycloak/keycloak:26.5.4-0 AS builder

ENV KC_DB=dev-file
ENV KC_HEALTH_ENABLED=true

WORKDIR /opt/keycloak

RUN /opt/keycloak/bin/kc.sh build

FROM quay.io/keycloak/keycloak:26.5.4-0

COPY --chown=1000:0 --from=builder /opt/keycloak /opt/keycloak
COPY --chown=1000:0 --from=toolbox /tmp/master-realm.json /opt/keycloak/data/import/master-realm.json
COPY --chown=1000:0 --from=toolbox /usr/bin/curl /usr/bin/curl
COPY --chown=1000:0 --from=toolbox /usr/lib64/libcurl.so.* /usr/lib64/
COPY --chown=1000:0 --from=toolbox /usr/lib64/libnghttp2.so.* /usr/lib64/
COPY --chown=1000:0 --from=toolbox /usr/lib64/libssl.so.* /usr/lib64/
COPY --chown=1000:0 --from=toolbox /usr/lib64/libcrypto.so.* /usr/lib64/
COPY --chown=1000:0 --from=toolbox /usr/lib64/libgssapi_krb5.so.* /usr/lib64/
COPY --chown=1000:0 --from=toolbox /usr/lib64/libkrb5.so.* /usr/lib64/
COPY --chown=1000:0 --from=toolbox /usr/lib64/libk5crypto.so.* /usr/lib64/
COPY --chown=1000:0 --from=toolbox /usr/lib64/libcom_err.so.* /usr/lib64/
COPY --chown=1000:0 --from=toolbox /usr/lib64/libkrb5support.so.* /usr/lib64/
COPY --chown=1000:0 --from=toolbox /usr/lib64/libkeyutils.so.* /usr/lib64/
COPY --chown=1000:0 --from=toolbox /tmp/master-realm.json /opt/

RUN mkdir -p /opt/keycloak/data/h2 && \
    chown -R 1000:0 /opt/keycloak/data/h2

ENV KC_HEALTH_ENABLED=true

ENTRYPOINT ["/opt/keycloak/bin/kc.sh", "start", "--optimized", "--import-realm", "--http-enabled=true", "--hostname=${KEYCLOAK_HOSTNAME}", "--http-port=${KEYCLOAK_PORT}"]