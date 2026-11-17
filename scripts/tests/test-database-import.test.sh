#!/bin/bash

load helpers/setup

_download_database_dump() {
	local filePath="${1}"
	local baseUrl="https://storage.googleapis.com/liferay-devtools/liferay-environment-composer/test-resources/database-support-tests"

	curl \
		--create-dirs \
		-o "${TEST_RESOURCES_DIR}/${filePath}" \
		"${baseUrl}/${filePath}"
}

_generate_postgres_liferay_schema_dumps() {
	local generatedDir="${TEST_RESOURCES_DIR}/generated/postgres"

	if [[ -f "${generatedDir}/lportal_psql_two_binary_dumps.tar.gz" ]]; then
		return
	fi

	if [[ ! -f "${TEST_RESOURCES_DIR}/raw/postgres/lportal_psql.sql" ]]; then
		_download_database_dump raw/postgres/lportal_psql.sql
	fi

	mkdir -p "${generatedDir}"

	{
		echo "CREATE SCHEMA liferay;"

		sed "s/public\./liferay./g" "${TEST_RESOURCES_DIR}/raw/postgres/lportal_psql.sql"
	} > "${generatedDir}/lportal_psql_liferay_schema.sql"

	local containerName="lec-test-postgres-liferay-schema-${BATS_ROOT_PID}"

	local postgresVersion
	postgresVersion="$(_readProperty "lr.docker.environment.service.version[postgres]" "${WORKSPACE_DIR}/gradle.properties")"

	docker run \
		--detach \
		--env POSTGRES_DB=lportal \
		--env POSTGRES_PASSWORD=liferay \
		--env POSTGRES_USER=liferay \
		--name "${containerName}" \
		--volume "${generatedDir}/lportal_psql_liferay_schema.sql:/docker-entrypoint-initdb.d/lportal.sql:ro" \
		"postgres:${postgresVersion}"

	until docker logs "${containerName}" 2>&1 | grep --quiet "PostgreSQL init process complete"; do
		if [[ "$(docker inspect --format "{{.State.Running}}" "${containerName}")" != "true" ]]; then
			docker rm --force "${containerName}"

			return 1
		fi

		sleep 2
	done

	local attempt
	for attempt in {1..60}; do
		if docker exec "${containerName}" pg_isready --dbname=lportal --username=liferay; then
			break
		fi

		if [[ "${attempt}" -eq 60 ]]; then
			docker rm --force "${containerName}"

			return 2
		fi

		sleep 1
	done

	docker exec "${containerName}" pg_dump --dbname=lportal --format=custom --username=liferay > "${generatedDir}/lportal_psql_liferay_schema.dump"

	docker rm --force "${containerName}"

	cp "${generatedDir}/lportal_psql_liferay_schema.dump" "${generatedDir}/lportal_psql_binary_named_sql.sql"

	tar \
		--create \
		--directory "${generatedDir}" \
		--file "${generatedDir}/lportal_psql_two_binary_dumps.tar.gz" \
		--gzip \
		lportal_psql_binary_named_sql.sql \
		lportal_psql_liferay_schema.dump
}

_test_import_dump() {
	local databaseType=${1}
	local inputFilePath=${2}

	_debug "RUNNING ${BATS_TEST_NAME}"

	if [[ ! -f "${TEST_RESOURCES_DIR}/${inputFilePath}" ]]; then
		_debug "Downloading missing file ${inputFilePath}"
		_download_database_dump "${inputFilePath}"
	fi

	cp "${TEST_RESOURCES_DIR}/${inputFilePath}" "./dumps/${inputFilePath//*\//}"

	_writeProperty "lr.docker.environment.lxc.backup.password" "12345"
	_writeProperty "lr.docker.environment.service.enabled[${databaseType}]" "true"
	_writeProperty "lr.docker.environment.service.enabled[liferay]" "false"

	run ./gradlew clean importDatabaseDumps

	assert_success

	_assertSqlQueryOutputContains "select urlTitle from JournalArticle;" "test-web-content-title"
}

setup_file() {
	BATS_TEST_NAME_PREFIX="Test import: "
	export BATS_TEST_NAME_PREFIX

	common_setup_file

	TESTS_DIR="${WORKSPACE_DIR}/scripts/tests"
	export TESTS_DIR

	TEST_RESOURCES_DIR="${TESTS_DIR}/resources/test-database-import"
	if [[ ! -d "${TEST_RESOURCES_DIR}" ]]; then
		mkdir -p "${TEST_RESOURCES_DIR}"
	fi
	export TEST_RESOURCES_DIR
}
setup() {
	common_setup
}
teardown() {
	common_teardown
}

# General archive tests

@test "archives/mysql/lportal_mysql.gz" {
	_test_import_dump mysql archives/mysql/lportal_mysql.gz
}
@test "archives/mysql/lportal_mysql.sql.7z" {
	_test_import_dump mysql archives/mysql/lportal_mysql.sql.7z
}
@test "archives/mysql/lportal_mysql.sql.bz2" {
	_test_import_dump mysql archives/mysql/lportal_mysql.sql.bz2
}
@test "archives/mysql/lportal_mysql.sql.gz" {
	_test_import_dump mysql archives/mysql/lportal_mysql.sql.gz
}
@test "archives/mysql/lportal_mysql.sql.tar.bz2" {
	_test_import_dump mysql archives/mysql/lportal_mysql.sql.tar.bz2
}
@test "archives/mysql/lportal_mysql.sql.tar.gz" {
	_test_import_dump mysql archives/mysql/lportal_mysql.sql.tar.gz
}
@test "archives/mysql/lportal_mysql.sql.tbz" {
	_test_import_dump mysql archives/mysql/lportal_mysql.sql.tbz
}
@test "archives/mysql/lportal_mysql.sql.tgz" {
	_test_import_dump mysql archives/mysql/lportal_mysql.sql.tgz
}
@test "archives/mysql/lportal_mysql.sql.zip" {
	_test_import_dump mysql archives/mysql/lportal_mysql.sql.zip
}
@test "archives/mysql/lportal_mysql_encrypted.sql.7z" {
	_test_import_dump mysql archives/mysql/lportal_mysql_encrypted.sql.7z
}
@test "archives/mysql/lportal_mysql_encrypted.sql.zip" {
	_test_import_dump mysql archives/mysql/lportal_mysql_encrypted.sql.zip
}

# Database specific tests

@test "archives/db2/db2move_lst.tar.gz" {
	_test_import_dump db2 archives/db2/db2move_lst.tar.gz
}
@test "archives/db2/LPORTAL.0.db2admin.DBPART000.20260130234412.001.7z" {
	_test_import_dump db2 archives/db2/LPORTAL.0.db2admin.DBPART000.20260130234412.001.7z
}
@test "raw/mariadb/lportal_mariadb.sql" {
	_test_import_dump mariadb raw/mariadb/lportal_mariadb.sql
}
@test "raw/mysql/lportal_mysql.sql" {
	_test_import_dump mysql raw/mysql/lportal_mysql.sql
}
@test "raw/postgres/lportal_psql.dump" {
	_test_import_dump postgres raw/postgres/lportal_psql.dump
}
@test "raw/postgres/lportal_psql.bak" {
	_test_import_dump postgres raw/postgres/lportal_psql.bak
}
@test "raw/postgres/lportal_psql.pg" {
	_test_import_dump postgres raw/postgres/lportal_psql.pg
}
@test "raw/postgres/lportal_psql_foreign_owner.dump" {
	_test_import_dump postgres raw/postgres/lportal_psql_foreign_owner.dump
}
@test "raw/postgres/lportal_psql.sql" {
	_test_import_dump postgres raw/postgres/lportal_psql.sql
}
@test "generated/postgres/lportal_psql_liferay_schema.sql" {
	_generate_postgres_liferay_schema_dumps

	_test_import_dump postgres generated/postgres/lportal_psql_liferay_schema.sql
}
@test "generated/postgres/lportal_psql_liferay_schema.dump" {
	_generate_postgres_liferay_schema_dumps

	_test_import_dump postgres generated/postgres/lportal_psql_liferay_schema.dump
}
@test "generated/postgres/lportal_psql_binary_named_sql.sql" {
	_generate_postgres_liferay_schema_dumps

	_test_import_dump postgres generated/postgres/lportal_psql_binary_named_sql.sql
}
@test "generated/postgres/lportal_psql_two_binary_dumps.tar.gz fails before importing" {
	_debug "RUNNING ${BATS_TEST_NAME}"

	_generate_postgres_liferay_schema_dumps

	cp "${TEST_RESOURCES_DIR}/generated/postgres/lportal_psql_two_binary_dumps.tar.gz" ./dumps/

	_writeProperty "lr.docker.environment.service.enabled[liferay]" "false"
	_writeProperty "lr.docker.environment.service.enabled[postgres]" "true"

	run ./gradlew clean importDatabaseDumps

	assert_failure
	assert_output --partial "Aborting because multiple binary dump files were found"
	refute_output --partial "Restoring /dumps/"
}
@test "archives/sqlserver/lportal.bak.gz" {
	_test_import_dump sqlserver archives/sqlserver/lportal.bak.gz
}
@test "raw/sqlserver/lportal.bacpac" {
	_test_import_dump sqlserver raw/sqlserver/lportal.bacpac
}