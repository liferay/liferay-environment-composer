# Writing Tests for Liferay Environment Composer

## Overview

Tests use [BATS](https://bats-core.readthedocs.io/) (Bash Automated Testing System). Each test file creates isolated git worktrees via the `lec` CLI so that tests can freely modify `gradle.properties` and spin up Docker containers without affecting the main workspace or other tests.

## Running Tests

Always use `lec bats` to run tests — it sets required environment variables like `BATS_FILE_EXTENSION`:

```bash
# Run all tests in a file
lec bats ./scripts/tests/test-e2e-basic.test.sh

# Run tests matching a filter
lec bats --filter "raw/mysql" ./scripts/tests/test-database-import.test.sh

# Run with debug output (prints _debug messages)
export DEBUG=1
lec bats ./scripts/tests/test-e2e-basic.test.sh
```

## Test File Structure

Test files must use the `.test.sh` extension and follow this structure:

```bash
#!/bin/bash

load helpers/setup

setup_file() {
    # Set a prefix — used to name the worktree for each test run
    BATS_TEST_NAME_PREFIX="My feature: "
    export BATS_TEST_NAME_PREFIX

    common_setup_file
    # Optional: set other file-level variables (shared across all tests in this file)
}

setup() {
    common_setup
    # Optional: configure gradle.properties for this test's needs
    _writeProperty "lr.docker.environment.service.enabled[mysql]" "true"
}

teardown() {
    common_teardown
}

@test "Description of what this test verifies" {
    _debug "RUNNING ${BATS_TEST_NAME}"

    # ... test body ...
}
```

## BATS Lifecycle

BATS provides four lifecycle hooks. Understanding when each runs is important:

| Hook | Runs | Use for |
|------|------|---------|
| `setup_file` | Once, before all tests in a file | Setting `BATS_TEST_NAME_PREFIX` and file-level variables |
| `setup` | Before **each** `@test` | Creating the worktree, configuring services |
| `teardown` | After **each** `@test` | Stopping containers, removing the worktree |
| `teardown_file` | Once, after all tests in a file | Not currently used |

Key behavior:
- Each `@test` runs in a subshell. Variables set inside a test are not visible to other tests.
- Variables exported in `setup_file` persist across all tests in the file.
- Variables exported in `setup` persist into the test body and `teardown`.
- `teardown` runs even if the test fails, ensuring cleanup always happens.

## Shared Helpers (`helpers/setup.bash`)

Loading `helpers/setup` gives you access to these functions:

### `common_setup_file`

Call this in `setup_file`. Sets up:
- `WORKSPACE_DIR` — the repo root
- `LIFERAY_ENVIRONMENT_COMPOSER_HOME` — tells `lec` where the repo lives
- `LIFERAY_ENVIRONMENT_COMPOSER_WORKSPACES_DIR` — points to BATS temp dir for worktree isolation

### `common_setup`

Call this in `setup`. Requires `BATS_TEST_NAME_PREFIX` to be exported (typically in `setup_file`). It:

1. Normalizes the prefix (lowercases, strips punctuation, replaces spaces with underscores)

1. Generates a unique worktree name from the normalized prefix, test number, and timestamp

1. Runs `lec init` to create a fresh git worktree

1. Sets `TEST_WORKSPACE_DIR` to the new worktree path

1. Loads `bats-support` and `bats-assert` libraries (providing `run`, `assert_success`, `assert_output`, etc.)

1. `cd`s into the worktree

After `common_setup` returns, your working directory is the isolated worktree. All `./gradlew` and `docker compose` commands run there.

### `common_teardown`

Call this in `teardown`. Cleans up the worktree created by `common_setup` (only if `TEST_WORKSPACE_DIR` exists):

1. `docker compose down -v` — stops containers and removes volumes

1. `_lec fn _clean` — cleans generated files

1. `_lec fn _removeWorktree` — removes the git worktree

### `_writeProperty key value`

Writes a property to `gradle.properties` in the current worktree. This is the primary way to configure which services are enabled and how they behave.

```bash
_writeProperty "lr.docker.environment.service.enabled[mysql]" "true"
_writeProperty "lr.docker.environment.service.enabled[liferay]" "false"
_writeProperty "lr.docker.environment.lxc.backup.password" "12345"
```

Handles bracket-containing keys (like `service.enabled[mysql]`) which are common in this project. Only modifies keys that already exist in `gradle.properties` — it uses sed substitution, so the key must be present (possibly commented out with `#`).

### `_startup`

Runs `./gradlew clean start` using BATS `run` and asserts the command succeeded. Replaces the common pattern of manually running Gradle and checking the exit code.

```bash
_startup

# Equivalent to:
# run ./gradlew clean start
# assert_success
```

### `_assertHttpStatus url`

Curls the given URL and asserts the HTTP status code is in the 2xx–3xx range (>= 200 and < 400).

```bash
local port
port=$(_getServicePort liferay 8080)

_assertHttpStatus "http://localhost:${port}"
```

### `_assertSqlQueryOutputContains sqlQuery expectedOutput`

Runs a SQL query via `./gradlew executeSQLQuery` and asserts the output contains the expected string.

```bash
_assertSqlQueryOutputContains "select emailAddress from User_ where screenName = 'test';" "test@liferay.com"
```

### `_getHttpCode url`

Returns the HTTP status code for a URL using curl. Used internally by `_assertHttpStatus`.

```bash
local code
code=$(_getHttpCode "http://localhost:${port}")
```

### `_getServicePort serviceName internalPort`

Returns the published host port for a Docker Compose service. Strips the host prefix so it returns just the port number.

```bash
local port
port=$(_getServicePort liferay 8080)

curl -s "http://localhost:${port}"
```

### `_debug message`

Prints a message to BATS output, but only when `DEBUG` is exported and greater than `0`. Use this for diagnostic output.

```bash
_debug "Current status: ${status}"
_debug "$(cat .env)"
```

### `_lec args...`

Wrapper that calls `lec.sh` from the repo root. Use this to invoke any `lec` command or internal function:

```bash
_lec init "my-workspace" dxp-2025.q4.12   # Create a workspace
_lec fn _clean "${TEST_WORKSPACE_DIR}"      # Call internal lec function
```

### `_normalize input`

Normalizes a string for use as a worktree name: trims whitespace, lowercases, strips punctuation, and replaces spaces/blanks with underscores. Used internally by `common_setup` to sanitize `BATS_TEST_NAME_PREFIX`.

### `_timestamp`

Returns a Unix timestamp. Used internally by `common_setup` to generate unique worktree names.

## Configuring Services

Services are toggled via `gradle.properties` using `_writeProperty`. Available services:

- `liferay`, `mysql`, `postgres`, `mariadb`, `db2`, `sqlserver`
- `elasticsearch`, `keycloak`, `webserver`, `mail`, `libreoffice`, `clamav`

The key pattern is `lr.docker.environment.service.enabled[<service>]=true|false`.

Since each test runs in its own worktree, you can freely modify properties without affecting other tests.

## Working with Ports

Docker Compose assigns ports from ranges defined in `ports.env`. Never hardcode port numbers in assertions. Use the `_getServicePort` helper to look up the published host port for a service:

```bash
local port
port=$(_getServicePort liferay 8080)

curl -s "http://localhost:${port}"
```

Common internal ports:
- Liferay: `8080` (HTTP), `8000` (debug), `11311` (Gogo shell)
- MySQL: `3306`
- Elasticsearch: `9200` (HTTP), `9300` (transport)

## Failing a Test

Use `return` with a non-zero exit code to fail a test. Do not use `exit` — that would kill the BATS subshell and skip teardown.

```bash
@test "example" {
    if ! ./gradlew clean start; then
        _debug "Start failed, dumping .env:"
        _debug "$(cat .env)"
        return 1
    fi

    local count
    count=$(docker compose ps -q | wc -l)

    if [[ ${count} -lt 2 ]]; then
        _debug "[FAILED] expected 2+ containers, got ${count}"
        return 2
    fi
}
```

Using distinct return codes (1, 2, 3...) makes it easier to identify which assertion failed.

## Tips

- **Filtering is essential during development.** The full database-import suite has 20 tests, each spinning up Docker containers. Use `--filter` to run only what you need.
- **Check `docker compose ps`** on failure to see which containers actually started.
- **Dump `.env` on failure** — the generated `.env` file shows how Gradle resolved all compose variables (ports, versions, image names). This is often the fastest way to diagnose configuration issues.
- **`_lec fn <function>`** exposes internal `lec.sh` functions. Run `grep '^_' scripts/cli/lec.sh` to see what's available.