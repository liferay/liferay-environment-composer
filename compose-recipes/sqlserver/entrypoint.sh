#!/bin/bash

_sqlcmd="/opt/mssql-tools18/bin/sqlcmd -C -S localhost -U sa -P ${MSSQL_SA_PASSWORD}"

_is_database_present() {
	local database_name=${1}

	if	[[ $(ls /var/opt/mssql/data/ | grep ${database_name}) ]] || \
		[[ $(${_sqlcmd} -Q "select name from sys.databases" | grep "${database_name}") ]]; then

		echo true
	fi
}

create_database() {
	local database_name=${1}

	if [[ ! $(_is_database_present ${database_name}) ]]; then
		echo "Could not find database ${database_name}; creating database..."

		sed -i "s,%DATABASE_NAME%,${database_name},g" /init/init.sql

		${_sqlcmd} -i /init/init.sql

		return
	else
		echo "Database ${database_name} is present; skipping database creation"

		return
	fi
}

main() {
	until ${_sqlcmd} -Q "SELECT 1"; do
		sleep 1
		echo "[entrypoint] Waiting for SQL Server to be available..."
	done

	create_database ${COMPOSER_DATABASE_NAME}
}

main & /opt/mssql/bin/sqlservr

wait