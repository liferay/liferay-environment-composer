#!/bin/bash

_sqlcmd="/opt/mssql-tools18/bin/sqlcmd -C -S localhost -U sa -P ${MSSQL_SA_PASSWORD}"

_has_database_files() {
	local database_name=${1}

	if [[ $(find /var/opt/mssql/data -type f -iname "${database_name}.*") ]]; then
		echo true
	fi
}

_is_database_present() {
	local database_name=${1}

	if	[[ $(${_sqlcmd} -Q "select name from sys.databases" | grep "${database_name}") ]]; then

		echo true
	fi
}

create_database() {
	local database_name=${1}

	if [[ $(_is_database_present ${database_name}) ]]; then
		echo "[entrypoint] Database ${database_name} is present; skipping database creation"

		touch /tmp/database_exists

		return
	fi

	local backup_file=$(find /var/opt/mssql/backups -iname "*.bak" -or -iname "*.bacpac" | tail -n 1)

	if [[ -f "${backup_file}" ]]; then
		echo "[entrypoint] Database backup found; restoring database ${database_name}..."

		if [[ "${backup_file}" =~ .*\.bak ]]; then
			echo "[entrypoint] Found bak file"

			sed -i "s,%DATABASE_NAME%,${database_name},g" /init/restore.sql

			sed -i "s,%BACKUP_FILE%,${backup_file},g" /init/restore.sql

			${_sqlcmd} -i /init/restore.sql

			touch /tmp/database_exists

			return
		else
			echo "[entrypoint] Found bacpac file"

			sqlpackage /a:Import /sf:"${backup_file}" /tdn:"${database_name}" /tp:"${MSSQL_SA_PASSWORD}" /tsn:localhost /ttsc:true /tu:sa

			touch /tmp/database_exists

			return
		fi
	fi

	if [[ $(_has_database_files ${database_name}) ]]; then
		echo "Database files found; reattaching database ${database_name}..."

		sed -i "s,%DATABASE_NAME%,${database_name},g" /init/reinit.sql

		${_sqlcmd} -i /init/reinit.sql

		touch /tmp/database_exists

		return
	fi

	echo "[entrypoint] Could not find database ${database_name}; creating database..."

	sed -i "s,%DATABASE_NAME%,${database_name},g" /init/init.sql

	${_sqlcmd} -i /init/init.sql
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

create_database ${COMPOSER_DATABASE_NAME}

wait $PID