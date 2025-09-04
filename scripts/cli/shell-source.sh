#!/bin/bash

LEC_REPO_ROOT="${LIFERAY_ENVIRONMENT_COMPOSER_HOME}"
if [[ -z "${LEC_REPO_ROOT}" ]]; then
	echo "The LIFERAY_ENVIRONMENT_COMPOSER_HOME environment variable must be set. \"lec\" not enabled."
	return
fi

# Set the alias to the main script
# shellcheck disable=SC2139
alias lec="$LEC_REPO_ROOT/scripts/cli/lec.sh"

# Util function to allow quickly jumping to a project
function lecd() {
	local worktree_name="$*"

	local worktree_dir
	worktree_dir="$(
		lec list |
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