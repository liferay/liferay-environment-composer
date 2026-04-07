#!/bin/bash

load helpers/setup

_test_initial_startup() {
	local databaseType=${1}

	_debug "RUNNING ${BATS_TEST_NAME}"

	_writeProperty "lr.docker.environment.service.enabled[${databaseType}]" "true"

	_assertStartup

	_assertSqlQueryOutputContains "select emailAddress from User_ where screenName = 'test';" "test@liferay.com"

	local liferayPort
	liferayPort="$(_getServicePort "liferay" "8080")"

	_assertValidHttpStatusRange "http://localhost:${liferayPort}"
}

setup_file() {
	BATS_TEST_NAME_PREFIX="Initial startup with Liferay: "
	export BATS_TEST_NAME_PREFIX

	common_setup_file
}

setup() {
	common_setup

	_writeProperty "lr.docker.environment.service.enabled[liferay]" "true"
}

teardown() {
	common_teardown
}

@test "DB2" {
	_test_initial_startup db2
}
@test "MariaDB" {
	_test_initial_startup mariadb
}
@test "MySQL" {
	_test_initial_startup mysql
}
@test "PostgreSQL" {
	_test_initial_startup postgres
}
@test "SQLServer" {
	_test_initial_startup sqlserver
}