FROM rancher/k3s:v1.35.0-k3s1

ARG S6_VER=3.1.6.2

ADD https://github.com/just-containers/s6-overlay/releases/download/v${S6_VER}/s6-overlay-noarch.tar.xz /tmp
ADD https://github.com/just-containers/s6-overlay/releases/download/v${S6_VER}/s6-overlay-x86_64.tar.xz /tmp

RUN tar -C / -Jxpf /tmp/s6-overlay-noarch.tar.xz && tar -C / -Jxpf /tmp/s6-overlay-x86_64.tar.xz

COPY s6-rc.d /etc/s6-overlay/s6-rc.d/

RUN find /etc/s6-overlay/s6-rc.d -name "run" -o -name "up" | xargs chmod +x

ENTRYPOINT ["/init"]

EXPOSE 8001 6443