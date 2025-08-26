FROM mcr.microsoft.com/mssql/server:2022-CU20-GDR1-ubuntu-22.04

ARG DATA_DIRECTORY=data

USER root

RUN mkdir -p /var/opt/mssql/backups /var/opt/mssql/data
RUN chown -R mssql:mssql /var/opt/mssql/
RUN touch /startup_log.txt
RUN chown mssql:mssql /startup_log.txt

COPY entrypoint.sh /init/
COPY init.sql /init/
COPY reinit.sql /init

RUN chown -R mssql:mssql /init && \
    chmod a+x /init/entrypoint.sh

COPY --chown=mssql:mssql ${DATA_DIRECTORY}/database* /var/opt/mssql/data

USER mssql

ENTRYPOINT ["/bin/bash", "/init/entrypoint.sh"]