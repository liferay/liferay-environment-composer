#!/bin/bash

load helpers/setup

setup_file() {
	BATS_TEST_NAME_PREFIX="End-to-end: "
	export BATS_TEST_NAME_PREFIX

	common_setup_file
}

setup() {
	common_setup

	_writeProperty "lr.docker.environment.service.enabled[liferay]" "true"
	_writeProperty "lr.docker.environment.service.enabled[mysql]" "true"
	_writeProperty "lr.docker.environment.service.enabled[elasticsearch]" "true"
}

teardown() {
	common_teardown
}

@test "Start environment with Liferay, MySQL, and Elasticsearch" {
	_debug "RUNNING ${BATS_TEST_NAME}"

	_assertComposerStartup

	# Verify containers are running (expect liferay, mysql, elasticsearch)
	local running_count
	running_count=$(docker compose ps -q | wc -l)

	if [[ ${running_count} -lt 3 ]]; then
		_debug "[FAILED] expected at least 3 containers, got ${running_count}"
		docker compose ps
		return 2
	fi

	# Get published ports
	local es_host_port
	es_host_port=$(_getServicePort elasticsearch 9200)

	# Verify Elasticsearch is healthy
	local es_health
	es_health=$(curl -s "http://localhost:${es_host_port}/_cluster/health")

	if [[ ! ${es_health} =~ "green" ]]; then
		_debug "[FAILED] Elasticsearch not healthy: ${es_health}"
		return 3
	fi

	# Verify Liferay is reachable
	_assertLiferayStartup
}