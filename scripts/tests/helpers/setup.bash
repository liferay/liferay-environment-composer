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

_writeProperty() {
	local key="${1}"
	local value="${2}"
	local escapedKey="${key//[/\\[}"

	escapedKey="${escapedKey//]/\\]}"

	sed -E -i.bak "s,^#?${escapedKey}=.*$,${key}=${value//,/\,},g" gradle.properties
	rm gradle.properties.bak
}

common_setup_file() {
	WORKSPACE_DIR="$(git rev-parse --show-toplevel)"
	export WORKSPACE_DIR

	LIFERAY_ENVIRONMENT_COMPOSER_HOME="${WORKSPACE_DIR}"
	export LIFERAY_ENVIRONMENT_COMPOSER_HOME

	LIFERAY_ENVIRONMENT_COMPOSER_WORKSPACES_DIR="${BATS_SUITE_TMPDIR}"
	export LIFERAY_ENVIRONMENT_COMPOSER_WORKSPACES_DIR
}

common_setup() {
	_debug "SETUP ${BATS_TEST_NAME}"

	local name
	name="${LEC_TEST_NAME_PREFIX}-$(_timestamp)"

	_lec init "${name}" dxp-2025.q4.12

	TEST_WORKSPACE_DIR="${LIFERAY_ENVIRONMENT_COMPOSER_WORKSPACES_DIR}/lec-${name}"
	export TEST_WORKSPACE_DIR

	cd "${TEST_WORKSPACE_DIR}" || exit 1
}

common_teardown() {
	_debug "TEARDOWN ${BATS_TEST_NAME}"

	docker compose down -v

	_lec fn _clean "${TEST_WORKSPACE_DIR}"
	_lec fn _removeWorktree "${TEST_WORKSPACE_DIR}"
}
