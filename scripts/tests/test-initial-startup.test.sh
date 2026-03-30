#!/bin/bash

load helpers/setup

_test_initial_startup() {
	local databaseType=${1}

	_debug "RUNNING ${BATS_TEST_NAME}"

	./gradlew clean start \
		-Plr.docker.environment.service.enabled["${databaseType}"]=true \
		-Plr.docker.environment.service.enabled[liferay]=true

	local status=$?

	if [[ ${status} != 0 ]]; then
		echo "[FAILED] could not start up:"

		return 1
	fi
}

setup_file() {
	BATS_TEST_NAME_PREFIX="Test initial startup "
	export BATS_TEST_NAME_PREFIX

	common_setup_file
}

setup() {
	common_setup
}

teardown() {
	common_teardown
}

@test "db2 initial startup" {
	_test_initial_startup db2
}
@test "mariadb initial startup" {
	_test_initial_startup mariadb
}
@test "mysql initial startup" {
	_test_initial_startup mysql
}
@test "postgres initial startup" {
	_test_initial_startup postgres
}
@test "sqlserver initial startup" {
	_test_initial_startup sqlserver
}