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

	./gradlew clean importDatabaseDumps

	local status=$?

	if [[ ${status} != 0 ]]; then
		echo "[FAILED] could not start up:"

		return 1
	fi

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
@test "raw/postgres/lportal_psql.sql" {
	_test_import_dump postgres raw/postgres/lportal_psql.sql
}
@test "archives/sqlserver/lportal.bak.gz" {
	_test_import_dump sqlserver archives/sqlserver/lportal.bak.gz
}
@test "raw/sqlserver/lportal.bacpac" {
	_test_import_dump sqlserver raw/sqlserver/lportal.bacpac
}