#!/bin/bash

# The postgres image's entrypoint runs this script once, on the first start of
# the database container, against a temporary server that only listens on the
# local socket. Import the dump in /dumps, then rename a non-public Liferay
# schema to public.
#
# A file that pg_restore can read is restored as a binary dump, whatever its
# name, so a binary dump named .sql also works. At most one binary dump is
# allowed, and that is checked before anything is imported.
#
# The dumps are mounted at /dumps rather than in /docker-entrypoint-initdb.d,
# where the entrypoint would run them in name order. An extracted archive can
# contain any file names, so this script runs 100_prepare_database_import.sql
# first instead of relying on its name sorting before the dump.

set -eo pipefail

_import_dumps() {
	local prepare_file=/dumps/100_prepare_database_import.sql

	local binary_dump_files=()
	local sql_dump_files=()

	local file
	for file in /dumps/*; do
		if [[ "${file}" == "${prepare_file}" ]]; then
			continue
		fi

		if pg_restore --list "${file}" > /dev/null 2>&1; then
			binary_dump_files+=("${file}")

			continue
		fi

		case "${file}" in
			*.bak | *.dmp | *.dump | *.pg)
				echo "[import-dumps.sh] Aborting because ${file} is not a valid binary dump:"

				pg_restore --list "${file}" > /dev/null || true

				exit 1
				;;
			*.sql | *.sql.xz | *.sql.zst)
				sql_dump_files+=("${file}")
				;;
			*)
				echo "[import-dumps.sh] Ignoring ${file}"
				;;
		esac
	done

	if [[ "${#binary_dump_files[@]}" -gt 1 ]]; then
		echo "[import-dumps.sh] Aborting because multiple binary dump files were found: ${binary_dump_files[*]}"

		exit 1
	fi

	if [[ -f "${prepare_file}" ]]; then
		echo "[import-dumps.sh] Importing ${prepare_file}..."

		_psql --file "${prepare_file}"
	fi

	for file in "${sql_dump_files[@]}"; do
		echo "[import-dumps.sh] Importing ${file}..."

		case "${file}" in
			*.sql)
				_psql --file "${file}"
				;;
			*.sql.xz)
				xz --decompress --stdout "${file}" | _psql
				;;
			*.sql.zst)
				zstd --decompress --stdout "${file}" | _psql
				;;
		esac
	done

	for file in "${binary_dump_files[@]}"; do
		echo "[import-dumps.sh] Restoring ${file}..."

		PGHOST= PGHOSTADDR= pg_restore \
			--dbname "${POSTGRES_DB}" \
			--no-owner \
			--no-password \
			--no-privileges \
			--username "${POSTGRES_USER}" \
			--verbose \
			"${file}"
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

_query() {
	_psql --command "${1}" --no-align --tuples-only
}

_rename_schema_to_public() {
	if [[ -n "$(_query "select 1 from pg_tables where schemaname = 'public' limit 1")" ]]; then
		return
	fi

	local schema_names
	schema_names="$(_query "select distinct schemaname from pg_tables where tablename = 'company' and schemaname not like 'lpartition\_%'")"

	if [[ -z "${schema_names}" ]]; then
		return
	fi

	if [[ "$(wc --lines <<< "${schema_names}")" -gt 1 ]]; then
		echo "[import-dumps.sh] Not renaming any schema to public because multiple schemas have Liferay tables: ${schema_names//$'\n'/, }"

		return
	fi

	echo "[import-dumps.sh] Renaming schema ${schema_names} to public..."

	_psql --command "drop schema public; alter schema \"${schema_names}\" rename to public"
}

_import_dumps

_rename_schema_to_public