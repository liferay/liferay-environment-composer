FROM alpine:latest

RUN apk add --no-cache \
    bash \
    bats \
    curl \
    docker-cli \
    fzf \
    git \
    jq \
    ncurses

WORKDIR /app

ENV LIFERAY_ENVIRONMENT_COMPOSER_HOME=/app
ENV LEC_COLORS_DISABLED=1

COPY . /app

CMD ["bats", "/app/scripts/tests/test-remove-command.bats"]
