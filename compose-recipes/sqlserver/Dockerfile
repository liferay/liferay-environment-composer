ARG SQLSERVER_VERSION=2022-CU21-ubuntu-22.04

FROM mcr.microsoft.com/mssql/server:${SQLSERVER_VERSION}

USER root

RUN apt update && apt install -y unzip && \
    mkdir -p /home/mssql && \
    chown -R mssql:mssql /home/mssql && \
    mkdir -p /var/opt/mssql/backups /var/opt/mssql/data && \
    chown -R mssql:mssql /var/opt/mssql/ && \
    mkdir /init && \
    chown -R mssql:mssql /init

ADD --chown=mssql https://aka.ms/sqlpackage-linux /home/mssql/sqlpackage.zip

USER mssql

RUN unzip /home/mssql/sqlpackage.zip -d /home/mssql/sqlpackage && \
    chmod a+x /home/mssql/sqlpackage/sqlpackage && \
    rm -rf /home/mssql/sqlpackage.zip

ENV PATH="${PATH}:/home/mssql/sqlpackage"

COPY --chown=mssql:mssql --chmod=a+x conf/entrypoint.sh /init/
COPY --chown=mssql:mssql conf/*.sql /init/

ENTRYPOINT ["/bin/bash", "/init/entrypoint.sh"]