#!/bin/bash

load helpers/setup

_test_initial_startup() {
	local databaseType=${1}

	_debug "RUNNING ${BATS_TEST_NAME}"

	_writeProperty "lr.docker.environment.service.enabled[${databaseType}]" "true"
	_writeProperty "lr.docker.environment.service.enabled[liferay]" "true"

	_assertComposerStartup

	_assertSqlQueryOutputContains "select emailAddress from User_ where screenName = 'test';" "test@liferay.com"

	_assertLiferayStartup
}

setup_file() {
	BATS_TEST_NAME_PREFIX="Initial startup: "
	export BATS_TEST_NAME_PREFIX

	common_setup_file
}

setup() {
	common_setup
}

teardown() {
	common_teardown
}

@test "Start Liferay with DB2" {
	_test_initial_startup db2
}
@test "Start Liferay with MariaDB" {
	_test_initial_startup mariadb
}
@test "Start Liferay with MySQL" {
	_test_initial_startup mysql
}
@test "Start Liferay with PostgreSQL" {
	_test_initial_startup postgres
}
@test "Start Liferay with SQLServer" {
	_test_initial_startup sqlserver
}