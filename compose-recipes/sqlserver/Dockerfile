FROM mcr.microsoft.com/mssql/server:2022-CU20-GDR1-ubuntu-22.04

USER root

RUN mkdir -p /var/opt/mssql/backups /var/opt/mssql/data
RUN chown -R mssql:mssql /var/opt/mssql/backups
RUN chown -R mssql:mssql /var/opt/mssql/data
RUN touch /startup_log.txt
RUN chown mssql:mssql /startup_log.txt

COPY entrypoint.sh /init/
COPY init.sql /init/

RUN chown -R mssql:mssql /init && \
    chmod a+x /init/entrypoint.sh

USER mssql

ENTRYPOINT ["/bin/bash", "/init/entrypoint.sh"]