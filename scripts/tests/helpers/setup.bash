#!/bin/bash

_debug() {
	if [[ "${DEBUG}" -gt 0 ]]; then
		echo "    # ${*}" >&3
	fi
}

_assertSqlQueryOutputContains() {
	local sqlQuery="${1}"
	local expectedOutput="${2}"

	local sqlQueryOutput

	sqlQueryOutput="$(./gradlew executeSQLQuery -PsqlQuery="${sqlQuery}")"

	if [[ ! ${sqlQueryOutput} =~ ${expectedOutput} ]]; then
		echo "[FAILED] expected data not found"

		return 4
	fi
}

_getServicePort() {
	local serviceName="${1}"
	local internalPort="${2}"

	docker compose port "${serviceName}" "${internalPort}" | sed 's,^.*:,,g'
}

_lec() {
	"${WORKSPACE_DIR}/scripts/cli/lec.sh" "${@}"
}

_timestamp() {
	date +%s
}

_normalize() {
	local input="${1}"

	echo "${input}" |
	xargs |
	tr '[:upper:]' '[:lower:]' |
	tr -d '[:punct:][:special:]' |
	tr '[:blank:]' '_'
}

_writeProperty() {
	local key="${1}"
	local value="${2}"
	local escapedKey="${key//[/\\[}"

	escapedKey="${escapedKey//]/\\]}"

	sed -E -i.bak "s,^#?${escapedKey}=.*$,${key}=${value//,/\,},g" gradle.properties
	rm gradle.properties.bak
}

common_setup_file() {
	_debug "SETUP ${BATS_TEST_FILE_NAME}"

	WORKSPACE_DIR="$(git rev-parse --show-toplevel)"
	export WORKSPACE_DIR

	LIFERAY_ENVIRONMENT_COMPOSER_HOME="${WORKSPACE_DIR}"
	export LIFERAY_ENVIRONMENT_COMPOSER_HOME

	LIFERAY_ENVIRONMENT_COMPOSER_WORKSPACES_DIR="${BATS_SUITE_TMPDIR}"
	export LIFERAY_ENVIRONMENT_COMPOSER_WORKSPACES_DIR
}

common_setup() {
	_debug "SETUP ${BATS_TEST_NAME}"

	if [[ -z "${BATS_TEST_NAME_PREFIX}" ]]; then
		echo "[ERROR] The BATS_TEST_NAME_PREFIX env variable must be set"
		exit 1
	fi

	local name
	name="$(_normalize "${BATS_TEST_NAME_PREFIX}")-${BATS_TEST_NUMBER}-$(_timestamp)"

	_lec init "${name}" dxp-2025.q4.12

	TEST_WORKSPACE_DIR="${LIFERAY_ENVIRONMENT_COMPOSER_WORKSPACES_DIR}/lec-${name}"
	export TEST_WORKSPACE_DIR

	cd "${TEST_WORKSPACE_DIR}" || exit 1
}

common_teardown() {
	_debug "TEARDOWN ${BATS_TEST_NAME}"

	if [[ -d "${TEST_WORKSPACE_DIR}" ]]; then
		docker compose down -v

		_lec fn _clean "${TEST_WORKSPACE_DIR}"
		_lec fn _removeWorktree "${TEST_WORKSPACE_DIR}"
	fi
}
