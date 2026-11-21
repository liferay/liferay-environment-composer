#!/bin/bash

load helpers/setup

setup_file() {
	BATS_TEST_NAME_PREFIX="k3s Client Extensions: "
	export BATS_TEST_NAME_PREFIX

	common_setup_file
}

setup() {
	common_setup

	_writeProperty "lr.docker.environment.service.enabled[k3s]" "true"

	# Stage one fixture client extension per type into the workspace. They carry
	# an LCP.json, a Dockerfile (whose base image tells the type) and a client
	# extension configuration, so renderClientExtensions can compute their chart
	# values without a cluster, Docker, a DXP image or a license.

	mkdir -p "${TEST_WORKSPACE_DIR}/client-extensions"

	cp -r "${WORKSPACE_DIR}/scripts/tests/fixtures/k3s/." \
		"${TEST_WORKSPACE_DIR}/client-extensions/"
}

teardown() {
	common_teardown
}

@test "renderClientExtensions maps each client extension to its chart values" {
	_debug "RUNNING ${BATS_TEST_NAME}"

	run ./gradlew renderClientExtensions --quiet --console=plain

	assert_success

	# The type comes from the archive's base image, the kind from LCP.json.

	assert_output --partial '"type": "frontend"'
	assert_output --partial '"type": "batch"'
	assert_output --partial '"type": "service"'
	assert_output --partial '"kind": "Deployment"'
	assert_output --partial '"kind": "Job"'
	assert_output --partial '"kind": "CronJob"'
	assert_output --partial '"schedule": "0 */6 * * *"'

	# Composer names the objects, serves the client extension on its ingress
	# host, labels it for the log tailer and turns off the Gateway API route.

	assert_output --partial '"fullnameOverride": "cxserving"'
	assert_output --partial '"domain": "cxserving.default.localtest.me"'
	assert_output --partial '"lxc.liferay.com/managed": "true"'
	assert_output --partial '"virtualInstanceId": "liferay.com"'

	# Endpoints of a serving client extension resolve to its ingress URL.

	assert_output --partial '"baseURL": "http://cxserving.default.localtest.me"'
	assert_output --partial '"homePageURL": "http://cxoauthaction.default.localtest.me"'
}

@test "renderClientExtensions discovers a packaged (*.zip) client extension like a source directory" {
	_debug "RUNNING ${BATS_TEST_NAME}"

	command -v zip > /dev/null || skip "zip not available"

	local ce="${TEST_WORKSPACE_DIR}/client-extensions"

	(cd "${ce}/cx-serving" && zip -qr "${ce}/cx-serving.zip" .)

	rm -rf "${ce}/cx-serving"

	run ./gradlew renderClientExtensions --quiet --console=plain

	assert_success

	assert_output --partial '"fullnameOverride": "cxserving"'
	assert_output --partial 'ingress=http://cxserving.default.localtest.me'
}

@test "renderClientExtensions honors a virtual-instance override" {
	_debug "RUNNING ${BATS_TEST_NAME}"

	run ./gradlew renderClientExtensions --quiet --console=plain \
		-PvirtualInstanceId=acme

	assert_success

	# The resolved instance flows into the ingress host, the chart's virtual
	# instance and the configuration's own virtualInstanceId.

	assert_output --partial '.acme.localtest.me'
	assert_output --partial '"virtualInstanceId": "acme"'
	assert_output --partial '"dxp.lxc.liferay.com.virtualInstanceId": "acme"'
	refute_output --partial '.default.localtest.me'
}

@test "renderClientExtensions orders client extensions by LCP.json dependencies" {
	_debug "RUNNING ${BATS_TEST_NAME}"

	local lcp="${TEST_WORKSPACE_DIR}/client-extensions/cx-serving/LCP.json"

	python3 - "${lcp}" <<-'PY'
		import json, sys
		p = sys.argv[1]
		d = json.load(open(p))
		d["dependencies"] = ["cxjob"]
		json.dump(d, open(p, "w"), indent="\t")
	PY

	run ./gradlew renderClientExtensions --quiet --console=plain

	assert_success

	local job_line serving_line

	job_line="$(printf '%s\n' "${output}" | grep -n '^# =====' | grep 'cxjob' | head -1 | cut -d: -f1)"
	serving_line="$(printf '%s\n' "${output}" | grep -n '^# =====' | grep 'cxserving' | head -1 | cut -d: -f1)"

	assert [ -n "${job_line}" ]
	assert [ -n "${serving_line}" ]
	assert [ "${job_line}" -lt "${serving_line}" ]
}

@test "renderClientExtensions honors a baked-in virtual instance and names objects by sid and vid" {
	_debug "RUNNING ${BATS_TEST_NAME}"

	run ./gradlew renderClientExtensions --quiet --console=plain

	assert_success

	# The cx-vi-variant fixture bakes virtualInstanceId=acme.local into its
	# configuration. Its objects get a DNS-safe sid+vid name, and it registers in
	# that instance, so the operator mounts that instance's metadata.

	assert_output --partial '"fullnameOverride": "cxvivariant-acme-local"'
	assert_output --partial '"domain": "cxvivariant.acme.local.localtest.me"'
	assert_output --partial '"virtualInstanceId": "acme.local"'
}

@test "renderClientExtensions applies liferay.yaml as Liferay Cloud Native does" {
	_debug "RUNNING ${BATS_TEST_NAME}"

	cat > "${TEST_WORKSPACE_DIR}/client-extensions/liferay.yaml" <<-'YAML'
		clientExtensionDefaults:
			values:
				workload:
					env:
						FROM_DEFAULTS: "true"
		clientExtensions:
			cx-cron:
				values:
					workload:
						schedule: "*/5 * * * *"
			cx-job:
				enabled: false
			cxserving:
				values:
					clientExtension:
						domain: cx.example.com
					workload:
						replicas: 2
	YAML

	run ./gradlew renderClientExtensions --quiet --console=plain

	assert_success

	# An entry matches by directory name (cx-cron) or service ID (cxserving), and
	# its values override LCP.json.

	assert_output --partial '"schedule": "*/5 * * * *"'
	assert_output --partial '"replicas": 2'

	# Composer keeps the domain the ingress serves.

	assert_output --partial '"domain": "cxserving.default.localtest.me"'
	refute_output --partial 'cx.example.com'

	# An entry's values replace the defaults' top-level keys, so the defaults'
	# env only reaches client extensions whose entry sets no workload.

	assert_output --partial '"FROM_DEFAULTS": "true"'

	# enabled: false leaves the client extension out.

	assert_output --partial 'cxjob skipped (enabled: false)'
}