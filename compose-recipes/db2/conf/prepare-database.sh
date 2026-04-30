_prepare_database() {
	. /database/config/${DB2INSTANCE}/sqllib/db2profile

	if [[ ! -d /database/data/${DB2INSTANCE}/NODE0000/${COMPOSER_DATABASE_NAME^^} ]]; then
		echo "[prepare-database.sh] Could not find database ${COMPOSER_DATABASE_NAME^^}. Creating database..."

		db2 create db ${COMPOSER_DATABASE_NAME} pagesize 32768 temporary tablespace managed by automatic storage
	fi

	if [[ -f "$(find /database/data/${DB2INSTANCE}/backups -iname 'db2move.lst')" ]]; then
		echo "[prepare-database.sh] Found db2move.lst file. Importing database..."

		cd /database/data/${DB2INSTANCE}/backups

		local old_schema
		old_schema=$(sed -n '1s@^!"\(.*\)"\..*@\1@p' db2move.lst)

		if [[ -n "${old_schema}" ]] && [[ "${old_schema}" != "${DB2INSTANCE^^}" ]]; then
			echo "[prepare-database.sh] Rewriting schema ${old_schema} to ${DB2INSTANCE^^} in db2move.lst..."

			sed -i "s/${old_schema}/${DB2INSTANCE^^}/g" db2move.lst
		fi

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

		db2 connect to ${COMPOSER_DATABASE_NAME}

		local restored_schema
		restored_schema=$(db2 -x "SELECT RTRIM(SCHEMANAME) FROM SYSCAT.SCHEMATA WHERE SCHEMANAME NOT LIKE 'SYS%' AND SCHEMANAME NOT IN ('NULLID','SQLJ','SYSTOOLS','SYSPROC','SYSIBMADM','${DB2INSTANCE^^}') FETCH FIRST 1 ROW ONLY" | xargs)

		if [[ "${restored_schema}" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]]; then
			echo "[prepare-database.sh] Redirecting default schema to ${restored_schema}"

			db2 "CREATE OR REPLACE PROCEDURE ${DB2INSTANCE^^}.LEC_SET_SCHEMA() LANGUAGE SQL SET CURRENT SCHEMA = '${restored_schema}'"
			db2 "GRANT EXECUTE ON PROCEDURE ${DB2INSTANCE^^}.LEC_SET_SCHEMA TO PUBLIC"
			db2 "UPDATE DB CFG FOR ${COMPOSER_DATABASE_NAME} USING CONNECT_PROC ${DB2INSTANCE^^}.LEC_SET_SCHEMA"
		fi

		db2 terminate
	fi
}

echo ${DB2INST1_PASSWORD} | su ${DB2INSTANCE} -c "$(declare -f _prepare_database); _prepare_database"

echo "STARTING_UP" > /startup_log.txt