#!/bin/bash

load helpers/setup

_test_initial_startup() {
	local databaseType=${1}

	_debug "RUNNING ${BATS_TEST_NAME}"

	_writeProperty "lr.docker.environment.service.enabled[${databaseType}]" "true"
	_writeProperty "lr.docker.environment.service.enabled[liferay]" "true"

	./gradlew clean start

	local status=$?

	if [[ ${status} != 0 ]]; then
		echo "[FAILED] could not start up:"

		return 1
	fi

	local sqlQueryOutput

	sqlQueryOutput=$(./gradlew executeSQLQuery -PsqlQuery="select emailAddress from User_ where screenName = 'test';")

	if [[ ! ${sqlQueryOutput} =~ test@liferay.com ]]; then
		echo "[FAILED] expected data not found"

		return 2
	fi

	local liferay_port

	liferay_port="$(_getServicePort "liferay" "8080")"

	local http_response_code

	http_response_code=$(curl -s -o /dev/null -w '%{http_code}' "http://localhost:${liferay_port}")

	if [[ ${http_response_code} != "200" ]]; then
		echo "[FAILED] expected response code not found"

		return 3
	fi
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