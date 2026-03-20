FROM registry.access.redhat.com/ubi9/ubi-minimal AS toolbox

ARG LIFERAY_PORT=8080

COPY conf/* /tmp

RUN microdnf update -y && microdnf install -y jq sed && \
    jq --arg a "$(cat /tmp/server.crt | sed '1d;$d' | sed -z 's/\n//g')" '(.clients[] | select(has("adminUrl"))).attributes."saml.signing.certificate" = $a' /tmp/master-realm.json > /tmp/temp.json && mv /tmp/temp.json /tmp/master-realm.json && \
    jq --arg a "$(cat /tmp/server.crt | sed '1d;$d' | sed -z 's/\n//g')" '(.clients[] | select(has("adminUrl"))).attributes."saml.encryption.certificate" = $a' /tmp/master-realm.json > /tmp/temp.json && mv /tmp/temp.json /tmp/master-realm.json && \
    sed -i "s@<LIFERAY_PORT>@${LIFERAY_PORT}@g" /tmp/master-realm.json

FROM quay.io/keycloak/keycloak:26.5.4-0 AS builder

ENV KC_DB=dev-file
ENV KC_HEALTH_ENABLED=true

WORKDIR /opt/keycloak

RUN /opt/keycloak/bin/kc.sh build

FROM quay.io/keycloak/keycloak:26.5.4-0

COPY --chown=1000:0 --from=builder /opt/keycloak /opt/keycloak
COPY --chown=1000:0 --from=toolbox /tmp/master-realm.json /opt/keycloak/data/import/master-realm.json

RUN mkdir -p /opt/keycloak/data/h2 && \
    chown -R 1000:0 /opt/keycloak/data/h2

ENV KC_HEALTH_ENABLED=true

ENTRYPOINT ["/opt/keycloak/bin/kc.sh", "start", "--optimized", "--import-realm", "--http-enabled=true", "--hostname=${KEYCLOAK_HOSTNAME}", "--http-port=${KEYCLOAK_PORT}"]