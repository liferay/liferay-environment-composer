#!/bin/bash

load helpers/setup

LEC_TEST_NAME_PREFIX="test-basic"

setup_file() {
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

@test "End-to-end: Start environment with Liferay, MySQL, and Elasticsearch" {
	_debug "RUNNING ${BATS_TEST_NAME}"

	if ! ./gradlew clean start; then
		_debug "Dumping .env file:"
		_debug "$(cat .env)"
		return 1
	fi

	# Verify containers are running (expect liferay, mysql, elasticsearch)
	local running_count
	running_count=$(docker compose ps -q | wc -l)

	if [[ ${running_count} -lt 3 ]]; then
		echo "[FAILED] expected at least 3 containers, got ${running_count}"
		docker compose ps
		return 2
	fi

	# Get published ports
	local es_host_port
	es_host_port=$(docker compose port elasticsearch 9200)

	local liferay_host_port
	liferay_host_port=$(docker compose port liferay 8080)

	# Verify Elasticsearch is healthy
	local es_health
	es_health=$(curl -s "http://${es_host_port}/_cluster/health")

	if [[ ! ${es_health} =~ "green" ]]; then
		echo "[FAILED] Elasticsearch not healthy: ${es_health}"
		return 3
	fi

	# Verify Liferay is reachable
	local http_code
	http_code=$(curl -s -o /dev/null -w "%{http_code}" "http://${liferay_host_port}")

	if [[ ${http_code} -lt 200 ]] || [[ ${http_code} -ge 400 ]]; then
		echo "[FAILED] Liferay returned HTTP ${http_code}"
		return 4
	fi
}