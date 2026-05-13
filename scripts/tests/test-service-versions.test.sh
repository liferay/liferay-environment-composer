#!/bin/bash

load helpers/setup

setup_file() {
	BATS_TEST_NAME_PREFIX="Service versions: "
	export BATS_TEST_NAME_PREFIX

	common_setup_file
}

setup() {
	common_setup
}

teardown() {
	common_teardown
}

@test "Validation fails when an enabled versioned service has a blank version" {
	_debug "RUNNING ${BATS_TEST_NAME}"

	_writeProperty "lr.docker.environment.service.enabled[elasticsearch]" "true"
	_writeProperty "lr.docker.environment.service.version[elasticsearch]" ""

	run _runGradleConfig

	assert_failure
	assert_output --partial "Missing required property: lr.docker.environment.service.version[elasticsearch]"
}

@test "Validation passes when a disabled versioned service has a blank version" {
	_debug "RUNNING ${BATS_TEST_NAME}"

	_writeProperty "lr.docker.environment.service.version[db2]" ""

	run _runGradleConfig

	assert_success
}

@test "Enabling a non-versioned service requires no version property" {
	_debug "RUNNING ${BATS_TEST_NAME}"

	_writeProperty "lr.docker.environment.service.enabled[mail]" "true"

	run _runGradleConfig

	assert_success
}

@test "Enabled service emits its <SERVICE>_VERSION env var matching gradle.properties" {
	_debug "RUNNING ${BATS_TEST_NAME}"

	_writeProperty "lr.docker.environment.service.enabled[postgres]" "true"

	local expectedVersion
	expectedVersion="$(_readProperty "lr.docker.environment.service.version[postgres]")"

	_runGradleConfig > /dev/null

	assert_equal "$(_getEnvVar "POSTGRES_VERSION")" "${expectedVersion}"
}

@test "Disabled service does not emit its <SERVICE>_VERSION env var" {
	_debug "RUNNING ${BATS_TEST_NAME}"

	_runGradleConfig > /dev/null

	run grep -q "^CLAMAV_VERSION=" .env

	assert_failure
}

@test "Validation fails when elasticsearch major version is not supported" {
	_debug "RUNNING ${BATS_TEST_NAME}"

	_writeProperty "lr.docker.environment.service.enabled[elasticsearch]" "true"
	_writeProperty "lr.docker.environment.service.version[elasticsearch]" "6.8.23"

	run _runGradleConfig

	assert_failure
	assert_output --partial "Unsupported Elasticsearch version: 6.8.23"
}
