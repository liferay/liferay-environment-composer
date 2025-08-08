echo "${DB2INST1_PASSWORD}" | su ${DB2INSTANCE} <<EOSU
. /database/config/${DB2INSTANCE}/sqllib/db2profile
[ "$(ls /database/data/${DB2INSTANCE}/backups)" ] && \
db2 connect to ${COMPOSER_DATABASE_NAME} && \
db2 force application all && \
db2 terminate && \
db2stop force && \
ipclean -a && \
db2set -null DB2COMM && \
db2start admin mode restricted access && \
db2 RESTORE DATABASE ${COMPOSER_DATABASE_NAME} FROM /database/data/${DB2INSTANCE}/backups INTO ${COMPOSER_DATABASE_NAME} REPLACE EXISTING WITHOUT ROLLING FORWARD && \
db2stop force && \
ipclean -a && \
db2set DB2COMM=TCPIP && \
db2start && \
db2 activate db ${COMPOSER_DATABASE_NAME} || \
echo "Skipping database restore as no dump was found"
EOSU