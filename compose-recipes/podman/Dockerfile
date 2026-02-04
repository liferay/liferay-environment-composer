# Start from the Podman stable image

FROM quay.io/podman/stable

ENV KUBECONFIG=/src/kubeconfig
ENV S6_KEEP_ENV=1

# 1. Install System Dependencies (Python, Unzip)

RUN dnf install -y python3 pip3 ps && \
    dnf clean all
RUN python3 -m venv /opt/venv

ENV PATH="/opt/venv/bin:$PATH"

RUN pip3 install kopf kubernetes

# 2. Install kubectl
# We download the latest stable release

RUN curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl" && \
    install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl && \
    rm kubectl

# 3. Configure Podman to trust Docker Hub for short names
# This fixes the "short-name resolution" error

RUN echo '[registries.search]' > /etc/containers/registries.conf && \
    echo 'registries = ["docker.io"]' >> /etc/containers/registries.conf

# 4. traefik

ARG TRAEFIK_VERSION=v2.10.7

ADD https://github.com/traefik/traefik/releases/download/${TRAEFIK_VERSION}/traefik_${TRAEFIK_VERSION}_linux_amd64.tar.gz /tmp/traefik.tar.gz

RUN tar xzvf /tmp/traefik.tar.gz -C /usr/local/bin traefik \
    && rm /tmp/traefik.tar.gz \
    && chmod +x /usr/local/bin/traefik

# 5. S6 Overlay to manage different init processes

ARG S6_VER=3.1.6.2

ADD https://github.com/just-containers/s6-overlay/releases/download/v${S6_VER}/s6-overlay-noarch.tar.xz /tmp
ADD https://github.com/just-containers/s6-overlay/releases/download/v${S6_VER}/s6-overlay-x86_64.tar.xz /tmp

RUN tar -C / -Jxpf /tmp/s6-overlay-noarch.tar.xz && tar -C / -Jxpf /tmp/s6-overlay-x86_64.tar.xz

COPY src /src
COPY s6-rc.d /etc/s6-overlay/s6-rc.d/

RUN find /etc/s6-overlay/s6-rc.d -name "run" -o -name "up" | xargs chmod +x

ENTRYPOINT ["/init"]

EXPOSE 80 8092