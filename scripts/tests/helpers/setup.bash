#!/bin/bash

_debug() {
	if [[ "${DEBUG}" -gt 0 ]]; then
		echo "    # ${*}" >&3
	fi
}

_startup() {
	run ./gradlew clean start

	assert_success
}

_assertHttpStatus() {
	local url="${1}"

	local httpCode

	httpCode="$(_getHttpCode "${url}")"

	assert [ "${httpCode}" -ge 200 ]
	assert [ "${httpCode}" -lt 400 ]
}

_assertSqlQueryOutputContains() {
	local sqlQuery="${1}"
	local expectedOutput="${2}"

	run ./gradlew executeSQLQuery -q -PsqlQuery="${sqlQuery}"

	assert_output --partial "${expectedOutput}"
}

_getHttpCode() {
	local url="${1}"

	curl -s -o /dev/null -w "%{http_code}" "${url}"
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
	tr -d '[:punct:]' |
	tr '[:blank:]' '_'
}

_readProperty() {
	local key="${1}"
	local file="${2:-gradle.properties}"
	local escapedKey="${key//[/\\[}"

	escapedKey="${escapedKey//]/\\]}"

	sed -nE "s,^${escapedKey}=(.*)$,\1,p" "${file}"
}

_writeProperty() {
	local key="${1}"
	local value="${2}"
	local file="${3:-gradle.properties}"
	local escapedKey="${key//[/\\[}"

	escapedKey="${escapedKey//]/\\]}"

	sed -E -i.bak "s,^#?${escapedKey}=.*$,${key}=${value//,/\,},g" "${file}"
	rm "${file}.bak"
}

_getEnvVar() {
	local key="${1}"

	grep "^${key}=" .env | cut -d= -f2-
}

_runGradleConfig() {
	# Gradle's configuration phase generates .env, so any task triggers it.
	./gradlew help
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

	local liferay_version
	liferay_version="$(_readProperty "liferay.workspace.product" "${WORKSPACE_DIR}/gradle.properties")"

	_lec init "${name}" "${liferay_version}"

	TEST_WORKSPACE_DIR="${LIFERAY_ENVIRONMENT_COMPOSER_WORKSPACES_DIR}/lec-${name}"
	export TEST_WORKSPACE_DIR

	load "${WORKSPACE_DIR}/scripts/vendor/bats-support/load"
	load "${WORKSPACE_DIR}/scripts/vendor/bats-assert/load"

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
