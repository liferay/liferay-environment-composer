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

	# Stage one fixture Client Extension per type into the workspace. These carry
	# only LCP.json (+ a client-extension config) so renderClientExtensions can
	# map them to manifests without a cluster, DXP image, or license.
	mkdir -p "${TEST_WORKSPACE_DIR}/client-extensions"

	cp -r "${WORKSPACE_DIR}/scripts/tests/fixtures/k3s/." \
		"${TEST_WORKSPACE_DIR}/client-extensions/"
}

teardown() {
	common_teardown
}

@test "renderClientExtensions maps each CX type to the right k8s workload" {
	_debug "RUNNING ${BATS_TEST_NAME}"

	run ./gradlew renderClientExtensions --quiet --console=plain

	assert_success

	# Serving CX (Deployment with a targetPort) -> Deployment + Service + Ingress.
	assert_output --partial '"kind": "Deployment"'
	assert_output --partial '"kind": "Service"'
	assert_output --partial '"kind": "Ingress"'

	# Batch CX -> Job; cron CX -> CronJob carrying its schedule.
	assert_output --partial '"kind": "Job"'
	assert_output --partial '"kind": "CronJob"'
	assert_output --partial '"schedule": "0 */6 * * *"'

	# OAuth CX -> socat native sidecar (initContainer + restartPolicy: Always).
	assert_output --partial 'alpine/socat'
	assert_output --partial '"restartPolicy": "Always"'

	# Metadata mounts follow cloud's LXCExtensionVolumesContributor: dxp-metadata
	# on every CX; ext-init-metadata ONLY for a CX with an OAuth app. So the OAuth
	# fixture gets an ext-init mount, but the static cx-vi-variant (customElement)
	# does not.
	assert_output --partial '/etc/liferay/lxc/dxp-metadata'
	assert_output --partial 'lxc-ext-init-metadata'
	refute_output --partial 'cxvivariant-liferay.com-lxc-ext-init-metadata'

	# Endpoints resolve to the ingress URL for every CX -- the localhost-proxy
	# socat makes the ingress reachable from Liferay too, so there is no NodePort
	# split. Both baseURL and homePageURL become the ingress host, and no endpoint
	# points at http://k3s:<nodePort>. (Config is rendered as escaped JSON inside
	# the ext-provision ConfigMap, hence the loose match around each key.)
	assert_output --partial '.localtest.me'
	assert_output --regexp 'baseURL[^,]*localtest\.me'
	assert_output --regexp 'homePageURL[^,]*localtest\.me'
	refute_output --partial 'http://k3s:'
}

@test "renderClientExtensions discovers a packaged (*.zip) CX like a source directory" {
	_debug "RUNNING ${BATS_TEST_NAME}"

	command -v zip > /dev/null || skip "zip not available"

	# A CX may be supplied either as a source directory (LCP.json at its root) or
	# as a built *.zip artifact -- the common LEC input form. Repackage the serving
	# fixture as a zip and drop the directory so only the archive remains.
	local ce="${TEST_WORKSPACE_DIR}/client-extensions"

	(cd "${ce}/cx-serving" && zip -qr "${ce}/cx-serving.zip" .)

	rm -rf "${ce}/cx-serving"

	run ./gradlew renderClientExtensions --quiet --console=plain

	assert_success

	# The archive materializes to the same Deployment + Service + Ingress trio.
	assert_output --partial '"kind": "Deployment"'
	assert_output --partial '"kind": "Service"'
	assert_output --partial '"kind": "Ingress"'
	assert_output --partial 'cxserving'
}

@test "renderClientExtensions honors a virtual-instance override (multi-tenant)" {
	_debug "RUNNING ${BATS_TEST_NAME}"

	run ./gradlew renderClientExtensions --quiet --console=plain \
		-PvirtualInstanceId=acme

	assert_success

	# The resolved vid flows into the ingress host, the LXC annotation, and the
	# CX's self-declared virtualInstanceId -- consistently, so a second instance
	# is addressable and registers under the intended tenant.
	assert_output --partial '.acme.localtest.me'
	assert_output --partial '"dxp.lxc.liferay.com/virtualInstanceId": "acme"'
	assert_output --regexp 'dxp.lxc.liferay.com.virtualInstanceId.{2,6}acme'
	refute_output --partial '.default.localtest.me'
}

@test "renderClientExtensions orders CX by LCP.json dependencies (cloud parity)" {
	_debug "RUNNING ${BATS_TEST_NAME}"

	# Declare that the serving CX depends on the job CX -- the same LCP.json field
	# Liferay Cloud uses. The dependency must be rendered/deployed first.
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

	# The per-CX header lines (`# ===== <vid>/<sid> ...`) reflect deploy order.
	# cxjob (the dependency) must appear before cxserving (the dependent).
	local job_line serving_line
	job_line="$(printf '%s\n' "${output}" | grep -n '^# =====' | grep 'cxjob' | head -1 | cut -d: -f1)"
	serving_line="$(printf '%s\n' "${output}" | grep -n '^# =====' | grep 'cxserving' | head -1 | cut -d: -f1)"

	assert [ -n "${job_line}" ]
	assert [ -n "${serving_line}" ]
	assert [ "${job_line}" -lt "${serving_line}" ]
}

@test "renderClientExtensions honors a CX's baked-in vid and names objects by sid+vid" {
	_debug "RUNNING ${BATS_TEST_NAME}"

	run ./gradlew renderClientExtensions --quiet --console=plain

	assert_success

	# The cx-vi-variant fixture bakes virtualInstanceId=acme.local into its config
	# (a per-VI variant artifact). With no external override, that vid is honored,
	# and the k8s objects are named by a DNS-safe sid+vid key so the same CX can
	# coexist across instances (the bare-sid default variant keeps its name).
	assert_output --partial '"name": "cxvivariant-acme-local"'
	assert_output --partial 'cxvivariant-acme-local-ext-provision'
	assert_output --partial 'cxvivariant.acme.local.localtest.me'
}