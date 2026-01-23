ARG SQLSERVER_VERSION=2022-CU21-ubuntu-22.04

FROM mcr.microsoft.com/mssql/server:${SQLSERVER_VERSION}

USER root

RUN apt update && apt install -y unzip wget && \
    mkdir -p /home/mssql && \
    chown -R mssql:mssql /home/mssql

USER mssql

RUN cd /home/mssql && \
    mkdir sqlpackage && \
    wget -O sqlpackage.zip https://aka.ms/sqlpackage-linux --no-check-certificate && \
    unzip sqlpackage.zip -d sqlpackage && \
    chmod a+x sqlpackage/sqlpackage && \
    rm -rf sqlpackage.zip

ENV PATH="${PATH}:/home/mssql/sqlpackage"

USER root

RUN mkdir -p /var/opt/mssql/backups /var/opt/mssql/data
RUN chown -R mssql:mssql /var/opt/mssql/
RUN touch /startup_log.txt
RUN chown mssql:mssql /startup_log.txt

COPY entrypoint.sh /init/
COPY init.sql /init/
COPY reinit.sql /init
COPY restore.sql /init

RUN chown -R mssql:mssql /init && \
    chmod a+x /init/entrypoint.sh

USER mssql

ENTRYPOINT ["/bin/bash", "/init/entrypoint.sh"]