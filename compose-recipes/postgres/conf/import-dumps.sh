#!/bin/bash

# The postgres image's entrypoint runs this script once, on the first start of
# the database container, against a temporary server that only listens on the
# local socket. Import the dump in /dumps.
#
# The dumps are mounted at /dumps rather than in /docker-entrypoint-initdb.d,
# where the entrypoint would run them in name order. An extracted archive can
# contain any file names, so this script runs 100_prepare_database_import.sql
# first instead of relying on its name sorting before the dump.

set -eo pipefail

_import_dumps() {
	local prepare_file=/dumps/100_prepare_database_import.sql

	if [[ -f "${prepare_file}" ]]; then
		echo "[import-dumps.sh] Importing ${prepare_file}..."

		_psql --file "${prepare_file}"
	fi

	local binary_dump_restored=false

	local file
	for file in /dumps/*; do
		case "${file}" in
			"${prepare_file}")
				;;
			*.sql)
				echo "[import-dumps.sh] Importing ${file}..."

				_psql --file "${file}"
				;;
			*.sql.xz)
				echo "[import-dumps.sh] Importing ${file}..."

				xz --decompress --stdout "${file}" | _psql
				;;
			*.sql.zst)
				echo "[import-dumps.sh] Importing ${file}..."

				zstd --decompress --stdout "${file}" | _psql
				;;
			*.bak | *.dmp | *.dump | *.pg)
				if [[ "${binary_dump_restored}" == "true" ]]; then
					echo "[import-dumps.sh] Aborting because multiple binary dump files were found"

					exit 1
				fi

				echo "[import-dumps.sh] Restoring ${file}..."

				PGHOST= PGHOSTADDR= pg_restore \
					--dbname "${POSTGRES_DB}" \
					--no-owner \
					--no-password \
					--no-privileges \
					--username "${POSTGRES_USER}" \
					--verbose \
					"${file}"

				binary_dump_restored=true
				;;
			*)
				echo "[import-dumps.sh] Ignoring ${file}"
				;;
		esac
	done
}

_psql() {
	PGHOST= PGHOSTADDR= psql \
		--dbname "${POSTGRES_DB}" \
		--no-password \
		--no-psqlrc \
		--set ON_ERROR_STOP=1 \
		--username "${POSTGRES_USER}" \
		"${@}"
}

_import_dumps