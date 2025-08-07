echo ${DB2INST1_PASSWORD} | su ${DB2INSTANCE} <<EOSU
. /database/config/${DB2INSTANCE}/sqllib/db2profile
[ ! -d /database/data/${DB2INSTANCE}/NODE0000/${COMPOSER_DATABASE_NAME^^} ] && db2 create db ${COMPOSER_DATABASE_NAME} pagesize 32768 temporary tablespace managed by automatic storage || echo
EOSU