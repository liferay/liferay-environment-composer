#!/bin/bash

load helpers/setup

_assertPortEquals() {
	local key="${1}"
	local expected="${2}"

	local actual
	actual="$(_getEnvPort "${key}")"

	if [[ "${actual}" != "${expected}" ]]; then
		_debug "[FAILED] ${key}: expected ${expected}, got ${actual}"
		return 1
	fi
}

_assertPortResolved() {
	local key="${1}"

	local value
	value="$(_getEnvPort "${key}")"

	if [[ "${value}" =~ - ]]; then
		_debug "[FAILED] ${key} is still a range: ${value}"
		return 1
	fi
}

_getEnvPort() {
	local key="${1}"

	grep "^${key}=" .env | cut -d= -f2
}

_resolvePorts() {
	# Port resolution runs during Gradle's configuration phase, so any task triggers it
	./gradlew help
}

_setPortRange() {
	local key="${1}"
	local value="${2}"

	sed -i.bak "s/^${key}=.*/${key}=${value}/" ports.env
	rm -f ports.env.bak
}

_setTestPortRanges() {
	_setPortRange "LIFERAY_PORT" "48080-48089"
	_setPortRange "LIFERAY_GOGO_SHELL_PORT" "48311-48319"
	_setPortRange "LIFERAY_DEBUG_PORT" "48400-48409"
	_setPortRange "LIFERAY_YOURKIT_PORT" "48500-48509"
	_setPortRange "DATABASE_PORT" "48321-48330"
	_setPortRange "ELASTICSEARCH_HTTP_PORT" "48200-48209"
	_setPortRange "ELASTICSEARCH_TRANSPORT_PORT" "48300-48309"
}

setup_file() {
	BATS_TEST_NAME_PREFIX="Port resolution: "
	export BATS_TEST_NAME_PREFIX

	common_setup_file
}

setup() {
	common_setup

	_setTestPortRanges
}

teardown() {
	if [[ -n "${BLOCKER_WORKSPACE_DIR}" ]] && [[ -d "${BLOCKER_WORKSPACE_DIR}" ]]; then
		_debug "Cleaning up blocker project"

		cd "${BLOCKER_WORKSPACE_DIR}" && docker compose down -v
		_lec fn _clean "${BLOCKER_WORKSPACE_DIR}"
		_lec fn _removeWorktree "${BLOCKER_WORKSPACE_DIR}"

		cd "${TEST_WORKSPACE_DIR}" || true
	fi

	common_teardown
}

@test "Ranges resolve to specific ports" {
	_debug "RUNNING ${BATS_TEST_NAME}"

	_resolvePorts

	_assertPortResolved "LIFERAY_PORT"
	_assertPortResolved "DATABASE_PORT"
	_assertPortResolved "ELASTICSEARCH_HTTP_PORT"
}

@test "Resolves to lowest port when all are free" {
	_debug "RUNNING ${BATS_TEST_NAME}"

	_resolvePorts

	_assertPortEquals "LIFERAY_PORT" "48080"
	_assertPortEquals "DATABASE_PORT" "48321"
}

@test "Skips port occupied by another project" {
	_debug "RUNNING ${BATS_TEST_NAME}"

	# Start a blocker project that occupies the lowest port in the DATABASE_PORT range
	local blocker_name
	blocker_name="blocker-$(_timestamp)"

	_lec init "${blocker_name}" dxp-2025.q4.12

	BLOCKER_WORKSPACE_DIR="${LIFERAY_ENVIRONMENT_COMPOSER_WORKSPACES_DIR}/lec-${blocker_name}"
	export BLOCKER_WORKSPACE_DIR

	cd "${BLOCKER_WORKSPACE_DIR}"

	_setTestPortRanges
	_writeProperty "lr.docker.environment.service.enabled[liferay]" "false"
	_writeProperty "lr.docker.environment.service.enabled[mysql]" "true"

	if ! ./gradlew clean start; then
		_debug "[FAILED] blocker project could not start"
		return 1
	fi

	local blocker_db_port
	blocker_db_port="$(_getEnvPort "DATABASE_PORT")"

	_debug "Blocker project DATABASE_PORT: ${blocker_db_port}"

	# Switch back to the test project
	cd "${TEST_WORKSPACE_DIR}"

	_writeProperty "lr.docker.environment.service.enabled[liferay]" "false"
	_writeProperty "lr.docker.environment.service.enabled[mysql]" "true"

	_resolvePorts

	_assertPortEquals "DATABASE_PORT" "48322"
}

@test "Ports are stable when project is running" {
	_debug "RUNNING ${BATS_TEST_NAME}"

	_writeProperty "lr.docker.environment.service.enabled[liferay]" "false"
	_writeProperty "lr.docker.environment.service.enabled[mysql]" "true"

	if ! ./gradlew clean start; then
		_debug "[FAILED] could not start"
		_debug "$(cat .env)"
		return 1
	fi

	local ports_before
	ports_before="$(grep "PORT=" .env | sort)"

	_resolvePorts

	local ports_after
	ports_after="$(grep "PORT=" .env | sort)"

	if [[ "${ports_before}" != "${ports_after}" ]]; then
		_debug "[FAILED] Ports changed between runs"
		_debug "Before: ${ports_before}"
		_debug "After: ${ports_after}"
		return 2
	fi
}

@test "Reuses project port even when lower port frees up" {
	_debug "RUNNING ${BATS_TEST_NAME}"

	# Start a blocker project to occupy the lowest DATABASE_PORT
	local blocker_name
	blocker_name="blocker-$(_timestamp)"

	_lec init "${blocker_name}" dxp-2025.q4.12

	BLOCKER_WORKSPACE_DIR="${LIFERAY_ENVIRONMENT_COMPOSER_WORKSPACES_DIR}/lec-${blocker_name}"
	export BLOCKER_WORKSPACE_DIR

	cd "${BLOCKER_WORKSPACE_DIR}"

	_setTestPortRanges
	_writeProperty "lr.docker.environment.service.enabled[liferay]" "false"
	_writeProperty "lr.docker.environment.service.enabled[mysql]" "true"

	if ! ./gradlew clean start; then
		_debug "[FAILED] blocker project could not start"
		return 1
	fi

	# Switch to our test project and start it — should get 48322 since blocker has 48321
	cd "${TEST_WORKSPACE_DIR}"

	_writeProperty "lr.docker.environment.service.enabled[liferay]" "false"
	_writeProperty "lr.docker.environment.service.enabled[mysql]" "true"

	if ! ./gradlew clean start; then
		_debug "[FAILED] test project could not start"
		_debug "$(cat .env)"
		return 2
	fi

	_assertPortEquals "DATABASE_PORT" "48322"

	# Stop the blocker project, freeing port 48321
	cd "${BLOCKER_WORKSPACE_DIR}"

	docker compose down -v
	_lec fn _clean "${BLOCKER_WORKSPACE_DIR}"
	_lec fn _removeWorktree "${BLOCKER_WORKSPACE_DIR}"

	BLOCKER_WORKSPACE_DIR=""

	# Re-run gradle on our project — should reuse 48322, not drop to 48321
	cd "${TEST_WORKSPACE_DIR}"

	_resolvePorts

	_assertPortEquals "DATABASE_PORT" "48322"
}