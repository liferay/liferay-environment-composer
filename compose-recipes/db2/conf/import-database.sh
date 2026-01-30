echo ${DB2INST1_PASSWORD} | su ${DB2INSTANCE} <<EOSU

. /database/config/${DB2INSTANCE}/sqllib/db2profile

if [[ $(find /database/data/${DB2INSTANCE}/backups -iname 'db2move.lst') ]]; then
	cd /database/data/${DB2INSTANCE}/backups

	db2move ${COMPOSER_DATABASE_NAME} import

	rm -rf /database/data/${DB2INSTANCE}/backups/*
else
	echo "Skipping database import as no dump was found"
fi

EOSU