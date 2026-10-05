# Tiny image for the cx-logs tailer with stern baked in, so the k3s recipe
# carries no vendored binary. The release is pinned for reproducibility; bump
# STERN_VERSION to upgrade. stern is a statically-linked Go binary, so it runs
# fine on Alpine (musl).

FROM alpine:3.20

ARG STERN_VERSION=1.34.0
ARG TARGETARCH=amd64

RUN apk add --no-cache ca-certificates \
	&& wget -qO- "https://github.com/stern/stern/releases/download/v${STERN_VERSION}/stern_${STERN_VERSION}_linux_${TARGETARCH}.tar.gz" \
		| tar -xz -C /usr/local/bin stern \
	&& stern --version

ENTRYPOINT ["stern"]