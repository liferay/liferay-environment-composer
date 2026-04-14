#!/bin/bash

LEC_REPO_ROOT="${LIFERAY_ENVIRONMENT_COMPOSER_HOME}"
if [[ -z "${LEC_REPO_ROOT}" ]]; then
	echo "The LIFERAY_ENVIRONMENT_COMPOSER_HOME environment variable must be set. \"lec\" not enabled."
	return
fi

# Shell function for the main script
function lec() {
	"$LEC_REPO_ROOT/scripts/cli/lec.sh" "$@"
}

# Util function to allow quickly jumping to a project
function lecd() {
	local worktree_name="$*"

	local worktree_dir
	worktree_dir="$(
		lec list projects |
			fzf \
				--delimiter "/" \
				--exit-0 \
				--height "50%" \
				--no-multi \
				--nth "-1" \
				--query "${worktree_name}" \
				--reverse \
				--select-1 \
				--with-nth "-1" \
			;
	)"

	if [[ -d "${worktree_dir}" ]]; then
		cd "${worktree_dir}" || return 1
	fi
}

function lec-init() {
	local tmp_file
	local workspace_dir

	tmp_file="$(mktemp)"
	trap 'rm -rf ${tmp_file}' EXIT

	if ! lec init "${@}" | tee "${tmp_file}"; then
		return 1
	fi

	workspace_dir="$(grep "Workspace dir: " "${tmp_file}" | awk '{print $3}')"

	if [[ -d "${workspace_dir}" ]]; then
		echo ""
		echo "Navigating to new workspace at ${workspace_dir}..."

		cd "${workspace_dir}" || return 1
	fi
}

function _lec_completions() {
	local cmd=()
	local cur="${COMP_WORDS[COMP_CWORD]}"
	local prev="${COMP_WORDS[COMP_CWORD - 1]}"

	case "$prev" in
	lec)
		cmd=(commands)
		;;
	list)
		cmd=(entities)
		;;
	rm|remove|-p|--project)
		cmd=(projects)
		;;
	*)
		cmd=(flags "${prev}")
		;;
	esac

	# shellcheck disable=SC2207
	COMPREPLY=($(compgen -W "$(lec completions "${cmd[@]}")" -- "${cur}"))

	return 0
}

if [[ -n "${ZSH_VERSION}" ]]; then
	autoload -U bashcompinit && bashcompinit
fi

complete -F _lec_completions lec