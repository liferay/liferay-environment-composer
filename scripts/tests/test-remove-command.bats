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

# Override _listRunningProjects to avoid docker calls in test environment
_listRunningProjects() {
    return 0
}

# Override _clean to avoid actual execution but simulate directory removal
# In reality, _clean only stops containers and cleans volumes.
# _removeWorktree is what actually deletes the directory.
_clean() {
    return 0
}

docker() {
    return 0
}

@test "cmd_remove removes a project specified by argument (absolute path)" {
    local test_project_name="lec-test-arg"
    local test_project_path="${LEC_WORKSPACES_DIR}/${test_project_name}"

    # Setup: Create a dummy project directory
    mkdir -p "${test_project_path}/compose-recipes"
    
    # Configure mock to "see" this worktree
    MOCK_WORKTREES="worktree ${test_project_path}"

    # Act
    run cmd_remove "${test_project_path}"

    # Assert
    [ "$status" -eq 0 ]
    [ ! -d "${test_project_path}" ]
}

@test "cmd_remove removes a project specified by argument (even if not detected as project root)" {
    local test_project_name="lec-test-non-root"
    local test_project_path="${LEC_WORKSPACES_DIR}/${test_project_name}"

    # Setup: Create a directory WITHOUT compose-recipes
    mkdir -p "${test_project_path}"
    
    # We must mock _removeWorktree because it uses 'git worktree remove' which won't work on non-worktree dirs
    # But cmd_remove calls _removeWorktree anyway.
    # Actually, in our mock _git, it already does rm -rf.
    
    # Act
    run cmd_remove "${test_project_path}"

    # Assert
    [ "$status" -eq 0 ]
    [ ! -d "${test_project_path}" ]
}

@test "cmd_remove interactively removes selected projects" {
    local test_project_name="lec-test-interactive"
    local test_project_path="${LEC_WORKSPACES_DIR}/${test_project_name}"

    # Setup: Create dummy project directory
    mkdir -p "${test_project_path}/compose-recipes"
    
    # Configure mock to "see" this worktree
    MOCK_WORKTREES="worktree ${test_project_path}"

    # Mock _fzf to return our test path (simulating selection)
    _fzf() {
        echo "${test_project_path}"
    }

    # Act: Call cmd_remove without arguments
    run cmd_remove

    # Assert
    [ "$status" -eq 0 ]
    [ ! -d "${test_project_path}" ]
}

@test "cmd_remove removes project with spaces in name" {
    local test_project_name="lec-test with spaces"
    local test_project_path="${LEC_WORKSPACES_DIR}/${test_project_name}"

    # Setup: Create dummy project directory
    mkdir -p "${test_project_path}/compose-recipes"
    
    # Configure mock to "see" this worktree
    MOCK_WORKTREES="worktree ${test_project_path}"

    # Act
    run cmd_remove "${test_project_path}"

    # Assert
    [ "$status" -eq 0 ]
    [ ! -d "${test_project_path}" ]
}
