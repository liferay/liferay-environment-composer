#!/bin/bash

_debug() {
	if [[ "${DEBUG}" -gt 0 ]]; then
		echo "    # ${*}" >&3
	fi
}
_lec() {
	"${WORKSPACE_DIR}/scripts/cli/lec.sh" "${@}"
}
_timestamp() {
	date +%s
}
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
	_debug "TEARDOWN FILE ${BATS_TEST_NAME}"

	WORKSPACE_DIR="$(git rev-parse --show-toplevel)"
	export WORKSPACE_DIR

	BATS_TEST_NAME_PREFIX="Test initial startup "
	export BATS_TEST_NAME_PREFIX

	LIFERAY_ENVIRONMENT_COMPOSER_HOME="${WORKSPACE_DIR}"
	export LIFERAY_ENVIRONMENT_COMPOSER_HOME

	LIFERAY_ENVIRONMENT_COMPOSER_WORKSPACES_DIR="${BATS_SUITE_TMPDIR}"
	export LIFERAY_ENVIRONMENT_COMPOSER_WORKSPACES_DIR
}
setup() {
	_debug "SETUP ${BATS_TEST_NAME}"

	local name
	name="test-initial-startup-$(_timestamp)"

	_lec init "${name}" dxp-2025.q4.12

	TEST_WORKSPACE_DIR="${LIFERAY_ENVIRONMENT_COMPOSER_WORKSPACES_DIR}/lec-${name}"
	export TEST_WORKSPACE_DIR

	cd "${TEST_WORKSPACE_DIR}" || exit 1
}
teardown() {
	_debug "TEARDOWN ${BATS_TEST_NAME}"

	docker compose down -v

	_lec fn _clean "${TEST_WORKSPACE_DIR}"
	_lec fn _removeWorktree "${TEST_WORKSPACE_DIR}"
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