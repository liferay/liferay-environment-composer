#!/bin/bash

LEC_REPO_ROOT="${LIFERAY_ENVIRONMENT_COMPOSER_HOME:?The LIFERAY_ENVIRONMENT_COMPOSER_HOME environment variable must be set}"

LEC_WORKSPACES_DIR="${LIFERAY_ENVIRONMENT_COMPOSER_WORKSPACES_DIR}"
if [[ -z "${LEC_WORKSPACES_DIR}" ]]; then
	LEC_WORKSPACES_DIR="${LEC_REPO_ROOT}/../lec-workspaces"
fi

if [ ! -d "${LXC_REPOSITORY_PATH}" ] && [ -d "${HOME}/dev/projects/liferay-lxc" ]; then
	LXC_REPOSITORY_PATH="${HOME}/dev/projects/liferay-lxc"
fi

#
# Helper function for fzf
#

_fzf () {
	if [[ -x "${LEC_REPO_ROOT}/scripts/cli/dependencies/fzf" ]]; then
		"${LEC_REPO_ROOT}/scripts/cli/dependencies/fzf" "${@}"

		return
	fi

	if ! _check_dependency fzf; then
		_print_warn "Dependency \"fzf\" is not installed. Please install it following the instructions here: https://junegunn.github.io/fzf/installation/"
	fi

	fzf "${@}"
}

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
		${C_BOLD}Liferay Environment Composer CLI${C_RESET}

		${C_BOLD}USAGE:${C_RESET}
		  lec <command>

		${C_BOLD}COMMANDS:${C_RESET}
		  init [ticket] [version]          Create a new Composer project
		  start                            Start a Composer project
		  stop                             Stop a Composer project
		  clean                            Stop a Composer project and remove Docker volumes
		  exportData                       Export container data for a Composer project
		  remove                           Completely tear down and remove a Composer project
		  share [--export]                 Save a Composer workspace for sharing. The "--export" flag exports the container data before saving the workspace.
		  update [--unstable]              Check for updates to Composer and lec. The "--unstable" flag updates to latest master branch.
		  version                          Prints the current version of lec

		  importDLStructure <sourceDir>    Import a Document Library (file structure only, no content) into configs/common/data/document_library

		${C_BOLD}JUMP TO A PROJECT:${C_RESET}
		  lecd [project name]

	EOF

	exit 0
}

#
# Interactivity functions
#
_confirm() {
	local message="${*}"

	printf "${C_BOLD}%s (y/N): ${C_RESET}" "${message}"
	read -r -n1

	echo

	if [ "${REPLY}" != "y" ] && [ "${REPLY}" != "Y" ]; then
		return 1
	fi
}
_prompt() {
	printf "${C_BOLD}%s${C_RESET}" "${1:?Provide prompt text}"
	read -r "${2:?Need a variable to write response to}"
}
_select() {
	local prompt_message="${1}"
	shift

	fzf --color="dark" --height=50% --info="inline" --prompt "${prompt_message} > " --reverse "${@}"
}

_selectMultiple() {
	local prompt_message="${1}"
	shift

	fzf --color="dark" --height=50% --info="inline" --multi --marker="*" --prompt "${prompt_message} > " --reverse "${@}"
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
_listSaaSEnvironments() {
	if [ ! -d "${LXC_REPOSITORY_PATH}/automation/environment-descriptors" ]; then
		return 0
	fi

	find "${LXC_REPOSITORY_PATH}/automation/environment-descriptors" -name '*.json' | sed -E 's,^.*/([^/]*).json$,\1,g'
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
_removeWorktree() {
	local worktree="${1:?Worktree directory required}"

	if [[ ! -d "${worktree}" ]]; then
		_errorExit "${worktree} is not a directory"
	fi

	local worktree_name="${worktree##*/}"

	if ! _confirm "Are you sure you want to remove the project ${C_YELLOW}${worktree_name}${C_NC}? The project directory and all data will be removed."; then
		return
	fi

	_print_step "Shutting down project and removing Docker volumes..."
	(
		cd "${worktree}" || exit 1

		./gradlew stop -Plr.docker.environment.clear.volume.data=true
	)

	_print_step "Removing project dir..."
	_git worktree remove --force "${worktree_name}"

	_print_step "Removing Git branch..."
	_git branch -D "${worktree_name}"

	_print_success "Project ${worktree_name} removed"
}
_selectLiferayRelease() {
	(
		_listReleases | sed "s,^,${C_GREEN}Release${C_NC} :: ,g"
		_listSaaSEnvironments | sed "s,^,${C_BLUE}LXC${C_NC}     :: ,g"
	) | _select "Select a Liferay release or LXC ID" | awk -F ':: ' '{print $2}'
}
_isLXCVersion() {
	local lxc_version="${1}"

	_listSaaSEnvironments | grep -q "^${lxc_version}$"
}
_isReleaseVersion() {
	local liferay_version="${1}"

	_listReleases | grep -q "^${liferay_version}$"
}
_verifyLiferayVersion() {
	local liferay_version="${1}"

	if _isLXCVersion "${liferay_version}"; then
		return 0
	fi

	if _isReleaseVersion "${liferay_version}"; then
		return 0
	fi

	_errorExit "'${liferay_version}' is not a valid Liferay version"
}
_writeLiferayVersion() {
	local worktree_dir="${1}"
	local liferay_version="${2}"

	(
		cd "${worktree_dir}" || exit

		if _isLXCVersion "${liferay_version}"; then
			_writeProperty "lr.docker.environment.lxc.environment.name" "${liferay_version}" gradle.properties

			echo "LXC environment set to ${liferay_version} in gradle.properties"
			./gradlew copyLiferayLXCRepositoryConfigurations

			return
		fi

		if _isReleaseVersion "${liferay_version}"; then
			_writeProperty "liferay.workspace.product" "${liferay_version}" gradle.properties

			echo "Liferay version set to ${liferay_version} in gradle.properties"

			return
		fi
	)
}
_writeProperty() {
	local key="${1:?Need a key}"
	local value="${2:?Need a value}"
	local file="${3}"

	if [[ ! -f "${file}" ]]; then
		_errorExit "${file} is not a valid file"
	fi

	sed -E -i.bak "s/^#?${key}=.*$/${key}=${value}/g" "${file}"
	rm "${file}.bak"
}

#
# PRIVATE COMMAND DEFINITIONS
#

_cmd_commands() {
	printf "\n${C_BOLD}%s${C_RESET}\n\n" "Public Commands:"
	_listPublicCommands | sed 's,^,  ,g'

	printf "\n${C_BOLD}%s${C_RESET}\n\n" "Private Commands:"
	_listPrivateCommands | sed 's,^,  ,g'
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
_cmd_remove2() {
	local worktrees
	worktrees="$(_listWorktrees | grep -E -v "^${LIFERAY_ENVIRONMENT_COMPOSER_HOME}$" | _selectMultiple "Choose projects to remove (Tab to select multiple)")"
	_cancelIfEmpty "${worktrees}"

	for worktree in ${worktrees}; do
		_removeWorktree "${worktree}"
		echo
	done
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
cmd_exportData() {
	_checkCWDProject

	_print_step "Exporting container data..."

	(
		cd "${CWD_PROJECT_ROOT}" || exit

		if ! ./gradlew exportContainerData --quiet; then
			exit 1
		fi

		local exportedDataRelativeDir
		exportedDataRelativeDir=$(grep lr.docker.environment.data.directory gradle-local.properties | sed "s,.*=,,g")

		_print_success "Container data exported to ${CWD_PROJECT_ROOT}/${exportedDataRelativeDir}"
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
		_errorExit "Worktree ${worktree_name} already exists at: ${existing_worktree}"
	fi

	if [[ -z "${liferay_version}" ]]; then
		liferay_version="$(_selectLiferayRelease)"
	fi
	_cancelIfEmpty "${liferay_version}"
	_verifyLiferayVersion "${liferay_version}"

	if _git rev-parse --verify --quiet "refs/heads/${worktree_name}" >/dev/null; then
		_print_step "Deleting stale branch ${worktree_name}"
		if ! _git branch -D "${worktree_name}"; then
			exit 1
		fi
	fi

	_print_step "Creating new worktree"
	if ! _git worktree add -b "${worktree_name}" "${LEC_WORKSPACES_DIR}/${worktree_name}" HEAD; then
		exit 1
	fi

	worktree_dir="$(_getWorktreeDir "${worktree_name}")"

	echo
	_print_step "Writing Liferay version"

	_writeLiferayVersion "${worktree_dir}" "${liferay_version}"

	_print_success "Created new Liferay Environment Composer project at ${C_BLUE}${worktree_dir}${C_NC}"
}
cmd_remove() {
	local worktree
	worktree="$(_listWorktrees | _select "Choose a project to remove")"
	_cancelIfEmpty "${worktree}"

	_removeWorktree "${worktree}"
}
cmd_share() {
	local exportFlag="${1}"

	_checkCWDProject

	(
		cd "${CWD_PROJECT_ROOT}" || exit

		if [[ "${exportFlag}" == "--export" ]]; then
			_print_step "Exporting container data..."

			if ! ./gradlew exportContainerData --quiet; then
				exit 1
			fi
		fi

		_print_step "Zipping up workspace..."

		if ! ./gradlew shareWorkspace | grep "Workspace zip"; then
			exit 1
		fi

		_print_success "Workspace saved"
	)
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

	_print_step "Checking for updates..."

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
		_print_success "Current version ${C_BLUE}${current_tag}${C_NC} is up to date"

		return
	fi

	tag_branch="release-${latest_tag}"

	_print_step "Updating to newer version ${C_BLUE}${latest_tag}${C_NC}..."

	if ! _git branch --format='%(refname:short)' | grep -q -e "^${tag_branch}$"; then
		_git branch "${tag_branch}" "tags/${latest_tag}"
	fi

	if ! _git checkout "${tag_branch}"; then
		_errorExit "Could not checkout out updated Git brannch, please make sure the main repository at ${C_YELLOW}${LEC_REPO_ROOT}${C_NC} does not contain any changes."
	fi

	_print_success "Updated to newer version ${C_BLUE}${latest_tag}${C_NC}"
}
cmd_version() {
	_git describe --tags --abbrev=0 2>/dev/null
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
