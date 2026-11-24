#!/bin/bash

load helpers/setup

_smokeTestHotfix() {
	local container="${1}"
	shift

	if docker container inspect "${container}" &>/dev/null; then
		skip "Container ${container} already exists"
	fi

	TEST_HOTFIX_CONTAINER="${container}"

	run _lec hotfix --smoke-test "${@}"
}

setup_file() {
	BATS_TEST_NAME_PREFIX="Test hotfix: "
	export BATS_TEST_NAME_PREFIX

	common_setup_file
}

setup() {
	common_setup

	export LEC_COLORS_DISABLED=1
}

teardown() {
	if [[ -n "${TEST_HOTFIX_CONTAINER}" ]]; then
		docker rm -f "${TEST_HOTFIX_CONTAINER}" &>/dev/null
	fi

	common_teardown
}

@test "Pass for a quarterly hotfix given by name" {
	_debug "RUNNING ${BATS_TEST_NAME}"

	_smokeTestHotfix lec-hotfix-24-on-2026.q2.6 liferay-dxp-2026.q2.6-hotfix-24.zip

	assert_success
	assert_output --partial "Stop it with: lec hotfix --smoke-test stop lec-hotfix-24-on-2026.q2.6"
	assert_output --partial "[OK] Hotfix installed: hotfix-24"
	assert_output --partial "[OK] ds:unsatisfied is empty"
	assert_output --partial "[OK] upgrade:check is empty"
	assert_output --partial "VERDICT: OK"
}

@test "Fail for a hotfix of a different version" {
	_debug "RUNNING ${BATS_TEST_NAME}"

	_smokeTestHotfix lec-hotfix-24-on-2026.q2.5 2026.q2.5 liferay-dxp-2026.q2.6-hotfix-24.zip

	assert_failure
	assert_output --partial "[KO] hotfix-24 is not in the installed patches"
	assert_output --partial "VERDICT: KO"
}

@test "Stop removes only hotfix smoke test containers" {
	_debug "RUNNING ${BATS_TEST_NAME}"

	local container
	container="lec-hotfix-bats-${BATS_TEST_NUMBER}-$(_timestamp)"

	local other_container="${container}-other"

	docker create --label lec.hotfix.smoke-test=true --name "${container}" busybox:latest >/dev/null
	docker create --name "${other_container}" busybox:latest >/dev/null

	run _lec hotfix --smoke-test stop "${other_container}"

	assert_failure
	assert_output --partial "${other_container} is not a hotfix smoke test container"

	run _lec hotfix --smoke-test stop "${container}"

	assert_success

	local remaining
	remaining="$(docker ps -a --filter "name=^${container}" --format "{{.Names}}")"

	docker rm -f "${other_container}" &>/dev/null

	if [[ "${remaining}" != "${other_container}" ]]; then
		_debug "[FAILED] unexpected containers left: ${remaining}"
		return 1
	fi
}

@test "Fail for a hotfix name without a version" {
	_debug "RUNNING ${BATS_TEST_NAME}"

	run _lec hotfix --smoke-test liferay-hotfix-7552-7413.zip

	assert_failure
	assert_output --partial "Usage: lec hotfix --smoke-test"
}