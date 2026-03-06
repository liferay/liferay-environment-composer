#!/usr/bin/env bats

# Setup environment
export LIFERAY_ENVIRONMENT_COMPOSER_HOME="/app"
export LEC_WORKSPACES_DIR="/tmp/lec-workspaces"
mkdir -p "${LEC_WORKSPACES_DIR}"

# Source lec.sh to get function definitions
source "/app/scripts/cli/lec.sh"

# Mock external commands and functions AFTER sourcing to ensure we override them
_check_dependencies() {
    true
}

_confirm() {
    return 0
}

_print() {
    true
}

# Global variable to control mocked worktree list
MOCK_WORKTREES=""

_git() {
    if [[ "$1" == "worktree" && "$2" == "list" ]]; then
        echo "${MOCK_WORKTREES}"
        return 0
    elif [[ "$1" == "worktree" && "$2" == "remove" ]]; then
        # The path/name is the last argument
        local last_arg="${@: -1}"
        # Try as full path first, then as name in LEC_WORKSPACES_DIR
        if [[ -d "${last_arg}" ]]; then
            rm -rf "${last_arg}"
        elif [[ -d "${LEC_WORKSPACES_DIR}/${last_arg}" ]]; then
            rm -rf "${LEC_WORKSPACES_DIR}/${last_arg}"
        fi
        return 0
    elif [[ "$1" == "branch" && "$2" == "-D" ]]; then
        return 0
    fi
    return 0
}

docker() {
    return 0
}

@test "cmd_remove removes a project specified by argument" {
    local test_project_name="lec-test-arg"
    local test_project_path="${LEC_WORKSPACES_DIR}/${test_project_name}"

    # Setup: Create a dummy project directory with compose-recipes to be recognized as a project root
    mkdir -p "${test_project_path}/compose-recipes"
    echo "#!/bin/sh" > "${test_project_path}/gradlew"
    chmod +x "${test_project_path}/gradlew"
    
    # Configure mock to "see" this worktree
    MOCK_WORKTREES="worktree ${test_project_path}"

    # Act
    cmd_remove "${test_project_path}"

    # Assert
    [ ! -d "${test_project_path}" ]
}

@test "cmd_remove interactively removes selected projects" {
    local test_project_name="lec-test-interactive"
    local test_project_path="${LEC_WORKSPACES_DIR}/${test_project_name}"

    # Setup: Create dummy project directory
    mkdir -p "${test_project_path}/compose-recipes"
    echo "#!/bin/sh" > "${test_project_path}/gradlew"
    chmod +x "${test_project_path}/gradlew"
    
    # Configure mock to "see" this worktree
    MOCK_WORKTREES="worktree ${test_project_path}"

    # Mock _fzf to return our test path (simulating selection)
    _fzf() {
        echo "${test_project_path}"
    }

    # Act: Call cmd_remove without arguments
    cmd_remove

    # Assert
    [ ! -d "${test_project_path}" ]
}
