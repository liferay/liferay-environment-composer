#!/bin/bash

load helpers/setup

setup_file() {
	BATS_TEST_NAME_PREFIX="Elasticsearch 7: "
	export BATS_TEST_NAME_PREFIX

	common_setup_file
}

setup() {
	common_setup

	_writeProperty "liferay.workspace.product" "dxp-2024.q3.8"
	_writeProperty "lr.docker.environment.service.enabled[mysql]" "true"
	_writeProperty "lr.docker.environment.service.enabled[elasticsearch]" "true"
	_writeProperty "lr.docker.environment.service.version[elasticsearch]" "7.17.9"
}

teardown() {
	common_teardown
}

@test "Start Liferay with ES7" {
	_debug "RUNNING ${BATS_TEST_NAME}"

	_startup

	local esPort
	esPort="$(_getServicePort "elasticsearch" "9200")"

	run curl -s "http://localhost:${esPort}/"
	assert_success
	assert_output --regexp '"number" *: *"7\.17\.9"'

	run curl -s "http://localhost:${esPort}/_nodes/_local/settings?flat_settings=true"
	assert_success
	assert_output --partial '"xpack.monitoring.enabled":"false"'
	assert_output --partial '"xpack.sql.enabled":"false"'

	local liferayPort
	liferayPort="$(_getServicePort "liferay" "8080")"

	_assertHttpStatus "http://localhost:${liferayPort}"

	run curl -s "http://localhost:${esPort}/_cat/indices?h=index"
	assert_success
	assert_output --regexp 'liferay-[0-9]+'

	run docker compose logs liferay
	assert_success
	refute_line --regexp 'ERROR.*[Ee]lastic'
	refute_line --regexp 'ERROR.*[Ss]earch'
}