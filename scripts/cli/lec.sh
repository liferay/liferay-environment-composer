#!/bin/bash

LEC_REPO_ROOT="${LIFERAY_ENVIRONMENT_COMPOSER_HOME:?The LIFERAY_ENVIRONMENT_COMPOSER_HOME environment variable must be set}"

LEC_WORKSPACES_DIR="${LIFERAY_ENVIRONMENT_COMPOSER_WORKSPACES_DIR}"
if [[ -z "${LEC_WORKSPACES_DIR}" ]]; then
	LEC_WORKSPACES_DIR="${LEC_REPO_ROOT}/../lec-workspaces"
fi

#
# Git helper functions
#

_git() {
	git -C "${LEC_REPO_ROOT}" "${@}"
}

#
# Color and printing functions
#

C_BLUE=""
C_BOLD=""
C_GREEN=""
C_NC=""
C_RED=""
C_RESET=""
C_YELLOW=""

if [[ -z "${LEC_COLORS_DISABLED}" ]] && tput setaf 1 >/dev/null 2>&1; then
	C_BLUE=$(tput setaf 6)
	C_BOLD=$(tput bold)
	C_GREEN=$(tput setaf 2)
	C_NC=$(tput op)
	C_RED=$(tput setaf 1)
	C_RESET=$(tput sgr0)
	C_YELLOW=$(tput setaf 3)
fi

_print() {
	local color="${1}"
	shift

	printf "${C_BOLD}${color}>>>${C_NC} %s${C_RESET}\n" "${*}"
}

_print_error() {
	_print "${C_RED}" "${*}"
}

_print_step() {
	_print "${C_BLUE}" "${*}"
}

_print_success() {
	_print "${C_GREEN}" "${*}"
}

_print_warn() {
	_print "${C_YELLOW}" "${*}"
}

#
# Control flow functions
#

_cancelIfEmpty() {
	if [[ -z "${1}" ]]; then
		echo "Canceled"
		exit 0
	fi
}
_errorExit() {
	_print_error "${*}"
	exit 1
}
_printHelpAndExit() {
	cat <<-EOF
		$(_bold Liferay Environment Composer CLI)

		$(_bold USAGE:)
		  lec <command>

		$(_bold COMMANDS:)
		  init [ticket] [version]          Create a new Composer project
		  start                            Start a Composer project
		  stop                             Stop a Composer project
		  clean                            Stop a Composer project and remove Docker volumes
		  update [--unstable]              Check for updates to Composer and lec. The "--unstable" flag updates to latest master branch.

		  importDLStructure <sourceDir>    Import a Document Library (file structure only, no content) into configs/common/data/document_library

		$(_bold JUMP TO A PROJECT:)
		  lecd [project name]

	EOF

	exit 0
}

#
# Interactivity functions
#
_confirm() {
	local message="${*}"

	printf "${C_BOLD}%s (y/N): ${C_NC}" "${message}"
	read -r -n1

	echo

	if [ "${REPLY}" != "y" ] && [ "${REPLY}" != "Y" ]; then
		return 1
	fi
}
_prompt() {
	printf "${C_BOLD}%s${C_NC}" "${1:?Provide prompt text}"
	read -r "${2:?Need a variable to write response to}"
}

#
# Dependencies
#

_is_program() {
	local program="${1}"

	command -v "${program}" >/dev/null
}

_check_dependency() {
	local dependency="${1}"

	if _is_program "${dependency}"; then
		return
	fi

	if ! _confirm "Do you want to try to install dependency ${dependency}?"; then
		return 1
	fi

	# Mac or Linux if brew is present
	if _is_program brew; then
		brew install "${dependency}"

	# Ubuntu
	elif _is_program apt; then
		sudo apt install "${dependency}"

	elif _is_program apt-get; then
		sudo apt-get install "${dependency}"

	# Fedora
	elif _is_program dnf; then
		sudo dnf install "${dependency}"

	# Arch
	elif _is_program pacman; then
		sudo pacman -S "${dependency}"

	else
		return 1

	fi
}

_check_dependencies() {
	if ! _check_dependency fzf; then
		_print_warn "Dependency \"fzf\" is not installed. Please install it following the instructions here: https://junegunn.github.io/fzf/installation/"
	fi

	if ! _check_dependency jq; then
		_print_warn "Dependency \"jq\" is not installed. Please install it following the instructions here: https://jqlang.org/download/"
	fi
}

#
# The root project dir of where the current working directory, if any
#

_getProjectRoot() {
	local dir="${PWD}"

	while [[ -d "${dir}" ]]; do
		if [[ -d "${dir}/compose-recipes" ]]; then
			(
				cd "${dir}" 2>/dev/null || return 1

				echo "${PWD}"
			)

			return
		fi

		dir="${dir}/.."
	done

	return 1
}

CWD_PROJECT_ROOT="$(_getProjectRoot)"

#
# Check to see if the script is called from a Composer project
#

_checkCWDProject() {
	if [[ ! -d "${CWD_PROJECT_ROOT}" ]]; then
		_errorExit "Not inside of a Liferay Environment Composer project"
	fi
}

#
# Download releases.json file if it is missing or out of date
#

LIFERAY_WORKSPACE_HOME="$HOME/.liferay/workspace"

RELEASES_JSON_FILE="${LIFERAY_WORKSPACE_HOME}/releases.json"

_checkReleasesJsonFile() {
	local curl_cmd
	local etag_status_code
	local releases_json_etag_file="${LIFERAY_WORKSPACE_HOME}/releases-json.etag"
	local releases_json_url="https://releases-cdn.liferay.com/releases.json"

	if [[ ! -d "${LIFERAY_WORKSPACE_HOME}" ]]; then
		mkdir -p "${LIFERAY_WORKSPACE_HOME}"
	fi

	curl_cmd=(curl --silent --output "${RELEASES_JSON_FILE}" --etag-save "${releases_json_etag_file}" "${releases_json_url}")

	if [[ ! -f "${RELEASES_JSON_FILE}" ]]; then
		"${curl_cmd[@]}"
		return
	fi

	etag_status_code="$(curl --silent --etag-compare "${releases_json_etag_file}" -w "%{http_code}" "${releases_json_url}")"

	if [[ "${etag_status_code}" != 304 ]]; then
		"${curl_cmd[@]}"
		return
	fi
}

#
# Helper functions to list information
#

_listFunctions() {
	local prefix="${1}"

	compgen -A function "${prefix}"
}

_listPrefixedFunctions() {
	local prefix="${1:?Prefix required}"

	_listFunctions "${prefix}" | sed "s/^${prefix}//g"
}

_listPrivateCommands() {
	_listPrefixedFunctions "_cmd_"
}
_listPublicCommands() {
	_listPrefixedFunctions "cmd_"
}
_listReleases() {
	_checkReleasesJsonFile

	jq '.[].releaseKey' -r "${RELEASES_JSON_FILE}"
}
_listRunningProjects() {
	docker compose ls --format=json | jq -r '.[] | .ConfigFiles' | sed 's@,@\n@g' | grep compose-recipes | sed 's,/compose-recipes/.*,,g' | sort -u
}
_listWorktrees() {
	_git worktree list --porcelain | grep worktree | awk '{print $2}'
}

#
# Command helper functions
#

_getClosestCommand() {
	local command="${1}"

	_listPublicCommands | fzf --bind="load:accept" --exit-0 --height 30% --reverse --select-1 --query "${command}"
}
_verifyCommand() {
	local command="${1}"

	_listPublicCommands | grep -q "^${command}$"
}

#
# General helper functions
#

_getComposeProjectName() {
	_checkCWDProject

	echo "${CWD_PROJECT_ROOT##*/}" | tr "[:upper:]" "[:lower:]"
}
_getServicePorts() {
	_checkCWDProject

	local serviceName="${1}"
	# shellcheck disable=SC2016
	local template='table NAME\tCONTAINER PORT\tHOST PORT\n{{$name := .Name}}{{range .Publishers}}{{if eq .URL "0.0.0.0"}}{{$name}}\t{{.TargetPort}}\tlocalhost:{{.PublishedPort}}\n{{end}}{{end}}'

	if [[ "${serviceName}" ]]; then
		docker compose ps "${serviceName}" --format "${template}" | tail -n +3
	else
		docker compose ps --format "${template}" | tail -n +3
	fi
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

	if ! _listReleases | grep -q "${liferay_version}"; then
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

#
# PRIVATE COMMAND DEFINITIONS
#

_cmd_commands() {
	echo

	_bold "Public Commands"
	echo
	_listPublicCommands

	echo

	_bold "Private Commands"
	echo
	_listPrivateCommands
}
_cmd_gw() {
	_checkCWDProject

	(
		cd "${CWD_PROJECT_ROOT}" || exit

		./gradlew "${@}"
	)
}
_cmd_fn() {
	"${1}" "${@:2}"
}
_cmd_list() {
	_listWorktrees
}
_cmd_listRunning() {
	_listRunningProjects
}
_cmd_ports() {
	local serviceName="${1}"

	_getServicePorts "${serviceName}"
}
_cmd_setVersion() {
	local liferay_version

	_checkCWDProject

	liferay_version="$(_selectLiferayRelease)"
	_cancelIfEmpty "${liferay_version}"

	_writeLiferayVersion "${CWD_PROJECT_ROOT}" "${liferay_version}"
}

#
# PUBLIC COMMAND DEFINITIONS
#

cmd_clean() {
	_print_step "Removing manually deleted worktrees"
	_git worktree prune

	_checkCWDProject

	(
		cd "${CWD_PROJECT_ROOT}" || exit

		_print_step "Stopping environment"
		./gradlew stop

		_print_step "Deleting volumes..."
		docker volume prune --all --filter="label=com.docker.compose.project=$(_getComposeProjectName)"
	)
}
cmd_importDLStructure() {
	_checkCWDProject

	local sourceDir="${1}"
	local targetDir="${CWD_PROJECT_ROOT}/configs/common/data/document_library"

	if [[ ! -d "${sourceDir}" ]]; then
		_print_error "Need a source directory to copy from"

		_printHelpAndExit
	fi

	if [[ -d "${targetDir}" ]] && _confirm "Remove existing ${targetDir}?"; then
		rm -rf "${targetDir}"
	fi

	_print_step "Copying file structure from ${sourceDir}"

	(
		cd "${CWD_PROJECT_ROOT}" || exit

		if ! ./gradlew importDocumentLibraryStructure -PsourceDir="${sourceDir}" --console=plain --quiet --stacktrace; then
			return 1
		fi

		echo ""
		_print_step "File structure copied to ${targetDir}"
	)

}
cmd_init() {
	local ticket="${1}"
	local liferay_version="${2}"

	local existing_worktree
	local worktree_dir
	local worktree_name

	if [[ -z "${ticket}" ]]; then
		_prompt "Ticket number: " ticket
	fi
	_cancelIfEmpty "${ticket}"

	worktree_name="lec-${ticket}"

	existing_worktree="$(_getWorktreeDir "${worktree_name}")"
	if [[ "${existing_worktree}" ]]; then
		_errorExit "Worktree $worktree_name already exists at: ${existing_worktree}"
	fi

	if [[ -z "${liferay_version}" ]]; then
		liferay_version="$(_selectLiferayRelease)"
	fi
	_cancelIfEmpty "${liferay_version}"
	_verifyLiferayVersion "${liferay_version}"

	_print_step "Creating new worktree"
	if ! _git worktree add -b "${worktree_name}" "${LEC_WORKSPACES_DIR}/${worktree_name}" HEAD; then
		exit 1
	fi

	worktree_dir="$(_getWorktreeDir "${worktree_name}")"

	echo
	echo "Created new Liferay Environment Composer project at ${worktree_dir}"

	_print_step "Writing Liferay version"
	_writeLiferayVersion "${worktree_dir}" "${liferay_version}"
}
cmd_start() {
	_checkCWDProject

	(
		cd "${CWD_PROJECT_ROOT}" || exit

		_print_step "Starting environment"
		if ! ./gradlew start; then
			exit 1
		fi

		_print_step "Printing published ports"
		_getServicePorts

		_print_step "Tailing logs"
		docker compose logs -f
	)
}
cmd_stop() {
	_checkCWDProject

	(
		cd "${CWD_PROJECT_ROOT}" || exit

		_print_step "Stopping environment"
		./gradlew stop
	)
}
cmd_update() {
	local current_tag
	local latest_tag
	local remote
	local tag_branch
	local upstream_repo_owner=liferay
	local unstable_flag="${1}"

	remote="$(_git remote -v | grep "\b${upstream_repo_owner}/liferay-environment-composer\b" | grep -F '(fetch)' | awk '{print $1}' | head -n1)"
	if [[ -z "${remote}" ]]; then
		_print_warn "No valid remote repository was found to update from."
		if _confirm "Do you want to add ${upstream_repo_owner}/liferay-environment-composer as a remote?"; then
			_git remote add upstream git@github.com:${upstream_repo_owner}/liferay-environment-composer.git

			remote=upstream
		fi
	fi
	if [[ -z "${remote}" ]]; then
		_print_error "No valid remote found"

		cat <<-EOF
			Please set "${upstream_repo_owner}/liferay-environment-composer" as a remote in the "${LEC_REPO_ROOT}" repository like this:

			  cd ${LEC_REPO_ROOT}
			  git remote add upstream git@github.com:${upstream_repo_owner}/liferay-environment-composer.git

		EOF

		exit 1
	fi

	_print_step "Updating Liferay Environment Composer from remote \"${remote}\"..."

	if [[ "${unstable_flag}" == "--unstable" ]]; then
		_git fetch "${remote}" master

		if ! _git rebase "${remote}/master" master; then
			_errorExit "Could not update master branch at ${LEC_REPO_ROOT}"
		fi

		_print_step "Checking out master branch"
		_git checkout master

		return
	fi

	_git fetch "${remote}" --tags

	current_tag=$(_git describe --tags 2>/dev/null)
	latest_tag=$(_git tag --list 'v*' | sort -V | tail -1)

	if [[ "${current_tag}" == "${latest_tag}" ]]; then
		_print_step "Current version ${current_tag} is up to date."

		return
	fi

	tag_branch="release-${latest_tag}"

	if ! _git branch --format='%(refname:short)' | grep -q -e "^${tag_branch}$"; then
		_print_step "Creating a new branch from tag \"${latest_tag}\""
		_git branch "${tag_branch}" "tags/${latest_tag}"
	fi

	_print_step "Checking out branch \"${latest_tag}\""
	_git checkout "${tag_branch}"
}

#
# GO
#

_check_dependencies

COMMAND="${1}"
if [[ -z "${COMMAND}" ]]; then
	_printHelpAndExit
fi

PRIVATE_COMMAND="_cmd_${COMMAND}"
if [[ $(type -t "${PRIVATE_COMMAND}") == function ]]; then
	"${PRIVATE_COMMAND}" "${@:2}"
	exit
fi

if ! _verifyCommand "${COMMAND}"; then
	CLOSEST_COMMAND="$(_getClosestCommand "${COMMAND}")"

	if _verifyCommand "${CLOSEST_COMMAND}" && _confirm "Command \"${COMMAND}\" is unknown. Use closest command \"${CLOSEST_COMMAND}\"?"; then
		COMMAND="${CLOSEST_COMMAND}"
	fi
fi

if ! _verifyCommand "${COMMAND}"; then
	_print_error "Invalid command: \"${COMMAND}\" "
	echo
	_printHelpAndExit
fi

"cmd_${COMMAND}" "${@:2}"
