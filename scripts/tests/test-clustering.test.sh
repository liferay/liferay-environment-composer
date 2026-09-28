#!/bin/bash

load helpers/setup

_assertClusterViewSize() {
	local serviceName="${1}"
	local size="${2}"
	local since="${3}"

	local logsArgs=()

	if [[ -n "${since}" ]]; then
		logsArgs+=(--since "${since}")
	fi

	local count
	count="$(docker compose logs "${logsArgs[@]}" "${serviceName}" | grep -c -E "Accepted view (MergeView::)?\[[^]]+\] \(${size}\) ")"

	# One view for each channel: control and transport
	assert [ "${count}" -ge 2 ]
}

_getIpAddress() {
	local containerId="${1}"

	docker inspect --format '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' "${containerId}"
}

_getStartedAt() {
	local containerId="${1}"

	docker inspect --format '{{.State.StartedAt}}' "${containerId}"
}

_refuteTrialLicenseError() {
	run docker compose logs liferay liferay-cluster-node

	refute_output --partial "Developer licenses do not allow for clustering"
}

_waitUntilHealthy() {
	local containerId="${1}"

	local deadline
	deadline=$(($(date +%s) + 900))

	until [[ "$(docker inspect --format '{{.State.Health.Status}}' "${containerId}")" == "healthy" ]]; do
		if [[ "$(date +%s)" -gt "${deadline}" ]]; then
			return 1
		fi

		sleep 5
	done
}

setup_file() {
	BATS_TEST_NAME_PREFIX="Clustering: "
	export BATS_TEST_NAME_PREFIX

	common_setup_file
}

setup() {
	if [[ ! -f "${LEC_CLUSTER_LICENSE_FILE}" ]]; then
		skip "Set LEC_CLUSTER_LICENSE_FILE to a license file that allows clustering"
	fi

	common_setup

	cp "${LEC_CLUSTER_LICENSE_FILE}" configs/common/osgi/modules/

	_writeProperty "lr.docker.environment.cluster.nodes" "1"
	_writeProperty "lr.docker.environment.service.enabled[mysql]" "true"

	IP_HOLDER_CONTAINER="$(basename "${TEST_WORKSPACE_DIR}")-ip-holder"
	export IP_HOLDER_CONTAINER
}

teardown() {
	if [[ -n "${IP_HOLDER_CONTAINER}" ]]; then
		docker rm --force "${IP_HOLDER_CONTAINER}" > /dev/null 2>&1
	fi

	common_teardown
}

@test "Nodes form a cluster over UDP multicast" {
	_debug "RUNNING ${BATS_TEST_NAME}"

	_startup

	run docker compose logs liferay
	assert_output --partial "properties: UDP("

	run docker compose logs liferay-cluster-node
	assert_output --partial "Lock acquired by"

	_assertClusterViewSize "liferay" 2
	_assertClusterViewSize "liferay-cluster-node" 2
	_refuteTrialLicenseError
}

@test "Nodes form a cluster over TCP unicast" {
	_debug "RUNNING ${BATS_TEST_NAME}"

	_writeProperty "lr.docker.environment.cluster.unicast.enabled" "true"

	_startup

	run docker compose logs liferay
	assert_output --partial "properties: TCP("
	assert_output --partial "TCPPING("
	assert_output --partial "JGroups TCPPING hosts: liferay[7800]"

	run docker compose logs liferay-cluster-node
	assert_output --partial "JGroups TCPPING hosts: liferay-cluster-node[7800],liferay[7800]"
	assert_output --partial "Lock acquired by"

	_assertClusterViewSize "liferay" 2
	_assertClusterViewSize "liferay-cluster-node" 2
	_refuteTrialLicenseError
}

@test "Nodes rejoin the TCP unicast cluster after restarting while other nodes are down" {
	_debug "RUNNING ${BATS_TEST_NAME}"

	_writeProperty "lr.docker.environment.cluster.unicast.enabled" "true"

	_startup

	local liferayContainer
	liferayContainer="$(docker compose ps --quiet liferay)"

	local clusterNodeContainer
	clusterNodeContainer="$(docker compose ps --quiet liferay-cluster-node)"

	local oldIpAddress
	oldIpAddress="$(_getIpAddress "${liferayContainer}")"

	local network
	network="$(docker inspect --format '{{range $name, $settings := .NetworkSettings.Networks}}{{$name}}{{end}}' "${liferayContainer}")"

	docker compose stop liferay

	# Take the main node's IP address so that it gets a different one when it starts again
	docker run --detach --name "${IP_HOLDER_CONTAINER}" --network "${network}" busybox:latest sleep 3600

	assert_equal "$(_getIpAddress "${IP_HOLDER_CONTAINER}")" "${oldIpAddress}"

	docker compose restart liferay-cluster-node

	_waitUntilHealthy "${clusterNodeContainer}"

	run docker compose logs --since "$(_getStartedAt "${clusterNodeContainer}")" liferay-cluster-node
	assert_output --partial "Leaving liferay[7800] out of the JGroups TCPPING hosts"
	refute_output --partial "UnknownHostException"

	_assertClusterViewSize "liferay-cluster-node" 1 "$(_getStartedAt "${clusterNodeContainer}")"

	docker compose start liferay

	_waitUntilHealthy "${liferayContainer}"

	refute [ "$(_getIpAddress "${liferayContainer}")" == "${oldIpAddress}" ]

	run docker compose logs --since "$(_getStartedAt "${liferayContainer}")" liferay
	assert_output --partial "JGroups TCPPING hosts: liferay[7800],liferay-cluster-node[7800]"

	_assertClusterViewSize "liferay" 2 "$(_getStartedAt "${liferayContainer}")"
}