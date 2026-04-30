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

		if [[ -n "${old_schema}" && "${old_schema}" != "${DB2INSTANCE^^}" ]]; then
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

		db2 -x "SELECT RTRIM(SCHEMANAME) FROM SYSCAT.SCHEMATA WHERE SCHEMANAME NOT LIKE 'SYS%' AND SCHEMANAME NOT IN ('NULLID','SQLJ','${DB2INSTANCE^^}') FETCH FIRST 1 ROW ONLY" > /tmp/restored_schema.out

		local restored_schema
		restored_schema=$(xargs < /tmp/restored_schema.out)
		rm -f /tmp/restored_schema.out

		if [[ "${restored_schema}" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]]; then
			echo "[prepare-database.sh] Redirecting default schema to ${restored_schema}"

			db2 "CREATE OR REPLACE PROCEDURE ${DB2INSTANCE^^}.LEC_SET_SCHEMA() LANGUAGE SQL SET CURRENT SCHEMA = '${restored_schema}'"
			db2 "GRANT EXECUTE ON PROCEDURE ${DB2INSTANCE^^}.LEC_SET_SCHEMA TO PUBLIC"
			db2 "UPDATE DB CFG FOR ${COMPOSER_DATABASE_NAME} USING CONNECT_PROC ${DB2INSTANCE^^}.LEC_SET_SCHEMA"
		fi

		db2 -x "SELECT RTRIM(GRANTEE) FROM SYSCAT.DBAUTH WHERE SECURITYADMAUTH='Y' AND GRANTEETYPE='U' AND GRANTEE <> '${DB2INSTANCE^^}' FETCH FIRST 1 ROW ONLY" > /tmp/secadm_user.out

		db2 terminate
	fi
}

_grant_authorities_to_instance_owner() {
	. /database/config/${DB2INSTANCE}/sqllib/db2profile

	db2 connect to ${COMPOSER_DATABASE_NAME} user "${1}" using "${1}" > /dev/null

	db2 "GRANT DBADM, DATAACCESS, ACCESSCTRL ON DATABASE TO USER ${DB2INSTANCE^^}"

	db2 terminate > /dev/null
}

echo ${DB2INST1_PASSWORD} | su ${DB2INSTANCE} -c "$(declare -f _prepare_database); _prepare_database"

if [[ -s /tmp/secadm_user.out ]]; then
	secadm_user=$(xargs < /tmp/secadm_user.out)
	rm -f /tmp/secadm_user.out

	if [[ "${secadm_user}" =~ ^[A-Za-z_][A-Za-z0-9_-]*$ ]]; then
		secadm_user="${secadm_user,,}"

		if ! id "${secadm_user}" &>/dev/null; then
			echo "[prepare-database.sh] Creating OS user ${secadm_user} to recover dump's SECADM authority..."

			useradd -m -s /bin/bash "${secadm_user}"

			echo "${secadm_user}:${secadm_user}" | chpasswd
		fi

		echo "[prepare-database.sh] Granting DBADM to ${DB2INSTANCE^^} via ${secadm_user}..."

		echo "${DB2INST1_PASSWORD}" | su "${DB2INSTANCE}" -c "$(declare -f _grant_authorities_to_instance_owner); _grant_authorities_to_instance_owner '${secadm_user}'"
	fi
fi

echo "STARTING_UP" > /startup_log.txt