FROM icr.io/db2_community/db2:11.5.9.0

RUN mkdir /var/custom
RUN mkdir -p /database/data/db2admin/NODE0000/lportal/backup
RUN touch /startup_log.txt
RUN sed -i -E 's,(^.*)(while :),\1echo "STARTING_UP" > /startup_log.txt\n\1\2,' /var/db2_setup/lib/setup_db2_instance.sh

COPY var_custom/* /var/custom
COPY backups/* /database/data/db2admin/NODE0000/lportal/backup

RUN chmod -R a+x /var/custom/