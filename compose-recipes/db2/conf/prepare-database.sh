echo ${DB2INST1_PASSWORD} | su ${DB2INSTANCE} <<EOSU
. /database/config/${DB2INSTANCE}/sqllib/db2profile

if [[ ! -d /database/data/${DB2INSTANCE}/NODE0000/${COMPOSER_DATABASE_NAME^^} ]]; then
	db2 create db ${COMPOSER_DATABASE_NAME} pagesize 32768 temporary tablespace managed by automatic storage
else
	echo "Skipping database creation as database ${COMPOSER_DATABASE_NAME^^} is already present"
fi

if [[ -f "$(find /database/data/${DB2INSTANCE}/backups -iname 'db2move.lst')" ]]; then
	cd /database/data/${DB2INSTANCE}/backups

	db2move ${COMPOSER_DATABASE_NAME} import

	rm -rf /database/data/${DB2INSTANCE}/backups/*
else
	echo "Skipping database import as no dump was found"
fi

if [[ -f "$(find /database/data/${DB2INSTANCE}/backups -type f | tail -n 1)" ]]; then
	db2 connect to ${COMPOSER_DATABASE_NAME}

	db2 force application all

	db2 terminate

	db2stop force

	ipclean -a

	db2set -null DB2COMM

	db2start admin mode restricted access

	db2 RESTORE DATABASE ${COMPOSER_DATABASE_NAME} FROM /database/data/${DB2INSTANCE}/backups INTO ${COMPOSER_DATABASE_NAME} REPLACE EXISTING WITHOUT ROLLING FORWARD

	db2stop force

	ipclean -a

	db2set DB2COMM=TCPIP

	db2start

	db2 activate db ${COMPOSER_DATABASE_NAME}
else
	echo "Skipping database restore as no dump was found"
fi

EOSU