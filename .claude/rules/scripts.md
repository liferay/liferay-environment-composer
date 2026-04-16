---
globs: scripts/**/*.sh, scripts/**/*.bash
---

# Bash Script Conventions

## Function naming
- `cmd_*` = public CLI commands (user-facing, shown in help)
- `_cmd_*` = private/hidden commands
- `_*` = helper functions (always underscore-prefixed)

## Variable declarations
- UPPERCASE for globals (`LEC_REPO_ROOT`), snake_case for locals
- NEVER combine local and assignment — masks exit codes:
  ```bash
  # WRONG
  local var="$(command)"

  # CORRECT
  local var
  var="$(command)"
  ```

## Quoting — always quote
- Variables: `"${var}"` not `$var`
- Command substitutions: `"$(command)"`
- Array expansion: `"${array[@]}"`

## Control flow
- Early return/continue over else blocks
- Fatal errors: `_errorExit "message"`
- Directory isolation: `(cd "${dir}" || exit; command)` in subshell

## BATS tests
- See `.claude/rules/bats-tests.md` for detailed test conventions
- Test helpers: `_assertFoo()` pattern, underscore-prefixed
