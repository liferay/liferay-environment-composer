FROM busybox:latest

COPY ./data /data/container-data

RUN mkdir -p /data/container-data/liferay
RUN mkdir -p /data/container-data/mysql

COPY ./dumps /data/dumps

RUN mkdir -p /data/dumps/mysql