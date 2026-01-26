ARG SQLSERVER_VERSION=2022-CU21-ubuntu-22.04

FROM mcr.microsoft.com/mssql/server:${SQLSERVER_VERSION}

USER root

RUN apt update && apt install -y unzip wget && \
    mkdir -p /home/mssql && \
    chown -R mssql:mssql /home/mssql && \
    mkdir -p /var/opt/mssql/backups /var/opt/mssql/data && \
    chown -R mssql:mssql /var/opt/mssql/ && \
    touch /startup_log.txt && \
    chown mssql:mssql /startup_log.txt && \
    mkdir /init && \
    chown -R mssql:mssql /init

USER mssql

RUN cd /home/mssql && \
    mkdir sqlpackage && \
    wget -O sqlpackage.zip https://aka.ms/sqlpackage-linux --no-check-certificate && \
    unzip sqlpackage.zip -d sqlpackage && \
    chmod a+x sqlpackage/sqlpackage && \
    rm -rf sqlpackage.zip

ENV PATH="${PATH}:/home/mssql/sqlpackage"

COPY --chown=mssql:mssql --chmod=a+x entrypoint.sh /init/
COPY --chown=mssql:mssql init.sql /init/
COPY --chown=mssql:mssql reinit.sql /init
COPY --chown=mssql:mssql restore.sql /init

ENTRYPOINT ["/bin/bash", "/init/entrypoint.sh"]