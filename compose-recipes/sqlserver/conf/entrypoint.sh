#!/bin/bash

_sqlcmd="/opt/mssql-tools18/bin/sqlcmd -C -S localhost -U sa -P ${MSSQL_SA_PASSWORD}"

_is_database_present() {
	local database_name=${1}

	if ${_sqlcmd} -Q "select name from sys.databases" | grep -q "${database_name}"; then

		echo true
	fi
}

create_database() {
	local database_name=${1}

	if [[ $(_is_database_present "${database_name}") ]]; then
		echo "[entrypoint] Database ${database_name} is present; skipping database creation"

		return
	fi

	local backup_file

	backup_file=$(find /var/opt/mssql/backups -iname "*.bak" -or -iname "*.bacpac" | tail -n 1)

	if [[ -f "${backup_file}" ]]; then
		echo "[entrypoint] Database backup found; restoring database ${database_name}..."

		if [[ "${backup_file}" =~ .*\.bak ]]; then
			echo "[entrypoint] Found bak file"

			${_sqlcmd} \
				-v DATABASE_NAME="${database_name}" \
				-v BACKUP_FILE="${backup_file}" \
				-i /init/restore.sql

			return
		else
			echo "[entrypoint] Found bacpac file"

			sqlpackage /a:Import /sf:"${backup_file}" /tdn:"${database_name}" /tp:"${MSSQL_SA_PASSWORD}" /tsn:localhost /ttsc:true /tu:sa

			return
		fi
	fi

	echo "[entrypoint] Could not find database ${database_name}; creating database..."

	${_sqlcmd} \
		-v DATABASE_NAME="${database_name}" \
		-i /init/init.sql
}

create_database_user() {
	local database_name=${1}

	echo "[entrypoint] Ensuring login ${DATABASE_USER} exists with db_owner on ${database_name}..."

	${_sqlcmd} \
		-v DATABASE_USER="${DATABASE_USER}" \
		-v DATABASE_USER_PASSWORD="${DATABASE_USER_PASSWORD}" \
		-v DATABASE_NAME="${database_name}" \
		-i /init/create-user.sql
}

/opt/mssql/bin/sqlservr &
PID=$!

echo "[entrypoint] Waiting for SQL Server to boot..."
until [[ -f /var/opt/mssql/log/errorlog ]]; do
	sleep 1
done

until grep -q "SQL Server is now ready for client connections" /var/opt/mssql/log/errorlog; do
	sleep 1
done

until [[ $(${_sqlcmd} -Q "select 1") ]]; do
	sleep 1
done

echo "[entrypoint] SQLServer is available"

create_database "${COMPOSER_DATABASE_NAME}"

create_database_user "${COMPOSER_DATABASE_NAME}"

touch /tmp/database_exists

wait $PID