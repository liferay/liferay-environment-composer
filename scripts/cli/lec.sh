#!/bin/bash

LEC_REPO_ROOT="${LIFERAY_ENVIRONMENT_COMPOSER_HOME:?The LIFERAY_ENVIRONMENT_COMPOSER_HOME environment variable must be set}"

LEC_WORKSPACES_DIR="${LIFERAY_ENVIRONMENT_COMPOSER_WORKSPACES_DIR}"
if [[ -z "${LEC_WORKSPACES_DIR}" ]]; then
	LEC_WORKSPACES_DIR="${LEC_REPO_ROOT}/../lec-workspaces"
fi

#
# Base util functions
#

_bold() {
	# escape format: \e[{codes}m
	# reset = 0
	# bold = 1
	printf "\e[1m%s\e[0m" "${*}"
}
_cancelIfEmpty() {
	if [[ -z "${1}" ]]; then
		echo "Canceled"
		exit 0
	fi
}
_errorExit() {
	echo "Error: ${*}"
	exit 1
}
_git() {
	git -C "${LEC_REPO_ROOT}" "${@}"
}
_prompt() {
	printf "%s" "${1:?Provide prompt text}"
	read -r "${2:?Need a variable to write response to}"
}

_printHelpAndExit() {
	cat <<- EOF
	$(_bold Liferay Environment Composer CLI)

	$(_bold USAGE:)
	  lec <command>

	$(_bold COMMANDS:)
	  init [ticket] [version] Create a new Composer project
	  start Start a Composer project
	  stop Stop a Composer project
	  clean Stop a Composer project and remove Docker volumes

	$(_bold JUMP TO A PROJECT:)
	  lecd [project name]

	EOF

	exit 0
}

#
# The Git dir of where the current working directory, if any
#

CWD_REPO_ROOT="$(git -C "$(pwd)" rev-parse --show-toplevel 2> /dev/null)"

#
# Check to see if the script is called from a Composer project
#

_checkCWDRepo() {
	if [[ -z "${CWD_REPO_ROOT}" ]]; then
		_errorExit "Not inside of a Git repository"
	fi

	if [[ ! -d "${CWD_REPO_ROOT}/compose-recipes" ]]; then
		_errorExit "Not inside of a Liferay Environment Composer project"
	fi
}

#
# Download releases.json file if it is missing or out of date
#

RELEASES_JSON_FILE="$HOME/.liferay/workspace/releases.json"
_checkReleasesJsonFile() {
	local releases_json_etag_file="$HOME/.liferay/workspace/releases-json.etag"
	local releases_json_url="https://releases-cdn.liferay.com/releases.json"

	local curl_cmd
	curl_cmd=(curl --silent --output "${RELEASES_JSON_FILE}" --etag-save "${releases_json_etag_file}" "${releases_json_url}")

	if [[ ! -f "${RELEASES_JSON_FILE}" ]]; then
		"${curl_cmd[@]}"
		return
	fi

	local ETAG_STATUS_CODE
	ETAG_STATUS_CODE="$(curl --silent --etag-compare "${releases_json_etag_file}" -w "%{http_code}" "${releases_json_url}")"

	if [[ "${ETAG_STATUS_CODE}" != 304 ]]; then
		"${curl_cmd[@]}"
		return
	fi
}

#
# Helper functions to list information
#

_listReleases() {
	_checkReleasesJsonFile

	jq '.[].releaseKey' -r "${RELEASES_JSON_FILE}"
}
_listWorktrees() {
	_git worktree list --porcelain | grep worktree | awk '{print $2}'
}

#
# General helper functions
#

_getComposeProjectName() {
	_checkCWDRepo

	echo "${CWD_REPO_ROOT##*/}" | tr "[:upper:]" "[:lower:]"
}
_getWorktreeDir() {
	local worktree_name="${1}"

	_listWorktrees | grep "/${worktree_name}$"
}
_selectLiferayRelease() {
	_listReleases | fzf --height=50% --reverse
}
_verifyLiferayVersion() {
	local liferay_version="${1}"

	if ! _listReleases | grep -q "${liferay_version}" ; then
		_errorExit "'${liferay_version}' is not a valid Liferay version"
	fi
}
_writeLiferayVersion() {
	local worktree_dir="${1}"
	local liferay_version="${2}"

	(
		cd "${worktree_dir}" || exit

		sed -E -i.bak "s/^liferay.workspace.product=.*$/liferay.workspace.product=${liferay_version}/g" gradle.properties
		rm gradle.properties.bak

		echo "Liferay version set to ${liferay_version} in gradle.properties"
	)
}

_printCommands() {
	compgen -c | grep "^cmd_" | sed "s/^cmd_//g"
}

#
# COMMAND DEFINITIONS
#

cmd_clean() {
	_checkCWDRepo

	(
		cd "${CWD_REPO_ROOT}" || exit

		./gradlew stop

		echo ""
		echo "Deleting volumes..."
		echo ""
		docker volume prune --all --filter="label=com.docker.compose.project=$(_getComposeProjectName)"
	)
}
cmd_commands() {
	_printCommands
}
cmd_init() {
	local ticket="${1}"
	local liferay_version="${2}"

	if [[ -z "${ticket}" ]]; then
		_prompt "LPP ticket number: " ticket
	fi
	_cancelIfEmpty "${ticket}"

	local worktree_name="lec-${ticket}"

	local existing_worktree
	existing_worktree="$(_getWorktreeDir "${worktree_name}")"
	if [[ "${existing_worktree}" ]]; then
		_errorExit "Worktree $worktree_name already exists at: ${existing_worktree}"
	fi

	if [[ -z "${liferay_version}" ]]; then
		liferay_version="$(_selectLiferayRelease)"
	fi
	_cancelIfEmpty "${liferay_version}"
	_verifyLiferayVersion "${liferay_version}"

	echo ""
	if ! _git worktree add -b "${worktree_name}" "${LEC_WORKSPACES_DIR}/${worktree_name}" master; then
		exit 1
	fi

	local worktree_dir
	worktree_dir="$(_getWorktreeDir "${worktree_name}")"

	echo ""
	echo "Created new Liferay Environment Composer project at ${worktree_dir}"

	_writeLiferayVersion "${worktree_dir}" "${liferay_version}"
}
cmd_list() {
	_listWorktrees
}
cmd_gw() {
	_checkCWDRepo

	(
		cd "${CWD_REPO_ROOT}" || exit

		./gradlew "${@}"
	)
}
cmd_setVersion() {
	_checkCWDRepo

	local liferay_version
	liferay_version="$(_selectLiferayRelease)"
	_cancelIfEmpty "${liferay_version}"

	_writeLiferayVersion "${CWD_REPO_ROOT}" "${liferay_version}"
}
cmd_start() {
	_checkCWDRepo

	(
		cd "${CWD_REPO_ROOT}" || exit

		./gradlew start && docker compose logs -f
	)
}
cmd_stop() {
	_checkCWDRepo

	(
		cd "${CWD_REPO_ROOT}" || exit

		./gradlew stop
	)
}

#
# GO
#
COMMAND="${1}"
if [[ -z "${COMMAND}" ]]; then
	_printHelpAndExit
fi
if ! _printCommands | grep -q "${COMMAND}"; then
	echo "Invalid command: ${COMMAND}"
	_printHelpAndExit
fi

"cmd_${COMMAND}" "${@:2}"