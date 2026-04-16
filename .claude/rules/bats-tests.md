---
globs: scripts/tests/**/*.test.sh, scripts/tests/helpers/*.bash
---

# BATS Test Conventions

## File structure — every test file follows this template
```bash
#!/bin/bash

load helpers/setup

setup_file() {
    BATS_TEST_NAME_PREFIX="Feature name: "
    export BATS_TEST_NAME_PREFIX
    common_setup_file
}

setup() {
    common_setup
    _writeProperty "lr.docker.environment.service.enabled[mysql]" "true"
}

teardown() {
    common_teardown
}

@test "Descriptive sentence" {
    _debug "RUNNING ${BATS_TEST_NAME}"
    # test body
}
```

## Lifecycle
- `setup_file` — once per file. Set `BATS_TEST_NAME_PREFIX`, call `common_setup_file`
- `setup` — before each test. Calls `common_setup` which creates an isolated git worktree
- `teardown` — after each test (even on failure). Calls `common_teardown` to clean up
- Each `@test` runs in a subshell — variables don't leak between tests

## Key rules
- Never hardcode ports — use `_getServicePort serviceName internalPort`
- Use `return 1` to fail (not `exit` — that kills the subshell and skips teardown)
- Use distinct return codes (1, 2, 3) per failure point for easier debugging
- Configure services via `_writeProperty` in `setup`, not by editing files directly
- Use `_startup` instead of manually running `./gradlew clean start` + `assert_success`

## Helper API reference
See `scripts/tests/README.md` for full documentation of all shared helpers:
`_startup`, `_writeProperty`, `_assertHttpStatus`, `_assertSqlQueryOutputContains`,
`_getServicePort`, `_getHttpCode`, `_debug`, `_lec`, `_normalize`, `_timestamp`
