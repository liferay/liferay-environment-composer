FROM busybox:latest

COPY --chown=1000:1000 ./data /data/container-data

RUN mkdir -p /data/container-data/elasticsearch
RUN mkdir -p /data/container-data/liferay
RUN mkdir -p /data/container-data/mysql

COPY --chown=1000:1000 ./dumps /data/dumps

RUN mkdir -p /data/dumps