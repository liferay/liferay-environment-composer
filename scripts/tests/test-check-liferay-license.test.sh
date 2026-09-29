#!/bin/bash

load helpers/setup

_test_check_for_liferay_license() {
	local liferayWorkspaceProduct=${1}
	local liferayLicenseCheckImagesProperty=${2}

	_debug "RUNNING ${BATS_TEST_NAME}"

	_writeProperty "liferay.workspace.product" "${liferayWorkspaceProduct}"

	rm -f configs/common/osgi/modules/*.xml

	run ./gradlew checkForLiferayLicense "${liferayLicenseCheckImagesProperty}"

	assert_success
}

_assert_attempt_copy_license_from_image() {
	local tags=("${@}")

	for tag in "${tags[@]}"; do
		assert_line "Attempting to copy trial license from liferay/dxp:${tag}"
	done
}

_build_stale_latest_image() {
	ORIGINAL_LATEST_IMAGE_ID="$(docker image inspect --format '{{ .Id }}' liferay/dxp:latest 2>/dev/null)"

	docker build --quiet --tag liferay/dxp:latest - >/dev/null <<-'EOF'
	FROM alpine
	RUN mkdir -p /opt/liferay/deploy && echo '<?xml version="1.0"?><license><license-type>developer</license-type><expiration-date>Monday, January 1, 2024 12:00:00 AM GMT</expiration-date></license>' > /opt/liferay/deploy/trial-dxp-license-stale.xml
	EOF

	STALE_LATEST_IMAGE_ID="$(docker image inspect --format '{{ .Id }}' liferay/dxp:latest)"
}

_restore_latest_image() {
	if [[ -z "${STALE_LATEST_IMAGE_ID}" ]]; then
		return
	fi

	local latest_image_id
	latest_image_id="$(docker image inspect --format '{{ .Id }}' liferay/dxp:latest 2>/dev/null)"

	if [[ "${latest_image_id}" == "${STALE_LATEST_IMAGE_ID}" ]] && [[ -n "${ORIGINAL_LATEST_IMAGE_ID}" ]]; then
		docker tag "${ORIGINAL_LATEST_IMAGE_ID}" liferay/dxp:latest
	fi

	docker rmi "${STALE_LATEST_IMAGE_ID}" &>/dev/null
}

_getLatestTargetPlatformVersion() {
	local year

	year="$(date +%Y)"

	_lec fn _showReleasesJsonFile | jq --arg year "$year" -r '.[] | select(.productGroupVersion | startswith($year)) | .targetPlatformVersion' | sort -V | tail -n 1
}

setup_file() {
	BATS_TEST_NAME_PREFIX="Check Liferay license for DXP version: "
	export BATS_TEST_NAME_PREFIX

	common_setup_file
}

setup() {
	common_setup

	_writeProperty "lr.docker.environment.service.enabled[liferay]" "true"
}

teardown() {
	_restore_latest_image

	common_teardown
}

@test "2026.Q1.6 LTS" {
	local targetPlatformVersion="2026.q1.6-lts"

	_test_check_for_liferay_license "dxp-2026.q1.6-lts" "-Pliferay.license.check.images=liferay/dxp:${targetPlatformVersion},liferay/dxp:latest"

	_assert_attempt_copy_license_from_image "${targetPlatformVersion}" "latest"
}

@test "Latest Quarterly Release" {
	local latestTargetPlatformVersion
	latestTargetPlatformVersion="$(_getLatestTargetPlatformVersion)"

	local latestReleaseKey
	latestReleaseKey="$(_lec fn _listReleases | grep "${latestTargetPlatformVersion}")"

	_test_check_for_liferay_license "${latestReleaseKey}" "-Pliferay.license.check.images=liferay/dxp:${latestTargetPlatformVersion}"

	_assert_attempt_copy_license_from_image "${latestTargetPlatformVersion}"

	refute_line "Attempting to copy trial license from liferay/dxp:latest"
}

@test "Stale local latest image" {
	_build_stale_latest_image

	_test_check_for_liferay_license "dxp-2026.q1.6-lts" "-Pliferay.license.check.images=liferay/dxp:latest"

	assert_line --partial "trial-dxp-license-stale.xml expired on"
	assert_line "Checking image liferay/dxp:latest for a valid license file to copy, retrieving via docker pull (this may take awhile)"
}