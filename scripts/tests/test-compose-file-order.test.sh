#!/bin/bash

load helpers/setup

_assertComposeFileIncluded() {
	local composeFile="${1}"
	shift

	if ! _indexOf "${composeFile}" "${@}" > /dev/null; then
		fail "Compose file ${composeFile} is not included: ${*}"
	fi
}

_readComposeFiles() {
	local variableName="${1}"

	IFS=':' read -r -a "${variableName:?}" <<< "$(_getEnvVar "COMPOSE_FILE")"
}

setup_file() {
	BATS_TEST_NAME_PREFIX="Compose file order: "
	export BATS_TEST_NAME_PREFIX

	common_setup_file
}

setup() {
	common_setup
}

teardown() {
	common_teardown
}

@test "Base service files load before every overlay" {
	_debug "RUNNING ${BATS_TEST_NAME}"

	_writeProperty "lr.docker.environment.cluster.nodes" "2"
	_writeProperty "lr.docker.environment.glowroot.enabled" "true"
	_writeProperty "lr.docker.environment.service.enabled[mysql]" "true"
	_writeProperty "lr.docker.environment.service.enabled[webserver]" "true"

	_runGradleConfig

	local composeFiles

	_readComposeFiles composeFiles

	assert_equal "${composeFiles[0]}" "docker-compose.yaml"

	# One file from each naming group

	_assertComposeFileIncluded "compose-recipes/liferay/service.liferay.yaml" "${composeFiles[@]}"
	_assertComposeFileIncluded "compose-recipes/mysql/service.mysql.yaml" "${composeFiles[@]}"
	_assertComposeFileIncluded "compose-recipes/webserver/service.webserver.yaml" "${composeFiles[@]}"
	_assertComposeFileIncluded "compose-recipes/webserver/liferay.webserver.yaml" "${composeFiles[@]}"
	_assertComposeFileIncluded "compose-recipes/webserver/clustering.webserver.yaml" "${composeFiles[@]}"
	_assertComposeFileIncluded "compose-recipes/liferay/glowroot.liferay.yaml" "${composeFiles[@]}"

	local lastBaseIndex=-1
	local firstOverlayIndex=-1

	local i

	for i in "${!composeFiles[@]}"; do
		if [[ "${composeFiles[${i}]}" != compose-recipes/* ]]; then
			continue
		fi

		if [[ "$(basename "${composeFiles[${i}]}")" == service.* ]]; then
			lastBaseIndex="${i}"
		elif [[ "${firstOverlayIndex}" -eq -1 ]]; then
			firstOverlayIndex="${i}"
		fi
	done

	assert [ "${lastBaseIndex}" -lt "${firstOverlayIndex}" ]
}

@test "Additional compose files load after every service file" {
	_debug "RUNNING ${BATS_TEST_NAME}"

	printf 'services:\n    liferay:\n        environment:\n            -   LEC_TEST_OVERRIDE=true\n' > additional.yaml

	_writeProperty "lr.docker.environment.compose.files" "additional.yaml"
	_writeProperty "lr.docker.environment.service.enabled[mysql]" "true"
	_writeProperty "lr.docker.environment.service.enabled[webserver]" "true"

	_runGradleConfig

	local composeFiles

	_readComposeFiles composeFiles

	assert_equal "${composeFiles[@]: -1}" "additional.yaml"
}