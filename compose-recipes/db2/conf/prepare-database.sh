_prepare_database() {
	. /database/config/${DB2INSTANCE}/sqllib/db2profile

	if [[ ! -d /database/data/${DB2INSTANCE}/NODE0000/${COMPOSER_DATABASE_NAME^^} ]]; then
		echo "[prepare-database.sh] Could not find database ${COMPOSER_DATABASE_NAME^^}. Creating database..."

		db2 create db ${COMPOSER_DATABASE_NAME} pagesize 32768 temporary tablespace managed by automatic storage
	fi

	if [[ -f "$(find /database/data/${DB2INSTANCE}/backups -iname 'db2move.lst')" ]]; then
		echo "[prepare-database.sh] Found db2move.lst file. Importing database..."

		cd /database/data/${DB2INSTANCE}/backups

		db2move ${COMPOSER_DATABASE_NAME} import

	elif [[ -f "$(find /database/data/${DB2INSTANCE}/backups -type f | tail -n 1)" ]]; then
		echo "[prepare-database.sh] Found dump file. Restoring database..."

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
	fi
}

echo ${DB2INST1_PASSWORD} | su ${DB2INSTANCE} -c "$(declare -f _prepare_database); _prepare_database"

echo "STARTING_UP" > /startup_log.txt