`lec` automates creating and managing per-ticket Composer workspaces.

## Install

Add to your `.bashrc` or `.zshrc`, adjusting paths:

```sh
# Path to your clone of this repository (or your fork)
export LIFERAY_ENVIRONMENT_COMPOSER_HOME="$HOME/Documents/liferay/liferay-environment-composer"

[[ -s "$LIFERAY_ENVIRONMENT_COMPOSER_HOME/scripts/cli/shell-source.sh" ]] && source "$LIFERAY_ENVIRONMENT_COMPOSER_HOME/scripts/cli/shell-source.sh"

# Optional: where `lec init` creates projects
export LIFERAY_ENVIRONMENT_COMPOSER_WORKSPACES_DIR="$HOME/Documents/liferay/tickets"
```

This provides the `lec` command plus the `lec-init` and `lecd` shell functions.

## Create a workspace

```sh
lec init                                  # prompts for ticket, version, and services
lec init LPP-12345                        # ticket number
lec init LPP-12345 dxp-2025.q3.0          # ticket and Liferay version
lec init LPP-12345 abc1prd                # ticket and SaaS environment name
lec init LPP-12345 dxp-2025.q3.0 --start  # create and start immediately
```

`lec-init` does the same, then `cd`s into the new project.

## Jump to a workspace

```sh
lecd                 # choose from a list
lecd workspace-name  # pre-filter; jumps directly if only one matches
```

## Enable services

```sh
lec service
```

## Lifecycle

```sh
lec start            # start and tail logs
lec stop             # shut down
lec restart          # restart a running environment
lec restart --clean  # remove volumes and images during shutdown, then restart
lec clean            # shut down and delete volumes
lec remove           # pick one or more projects to tear down and delete (alias: lec rm)
```

## Print ports

```sh
lec ports
```

See [Configuring the Environment → Ports](Configuring-the-Environment#ports).

## Data

```sh
lec exportData                       # export container data
lec importDLStructure <source_dir>   # copy a DL's file structure only
lec hotfix                           # pick and download a hotfix
```

## Share a workspace

```sh
lec share               # zip the workspace
lec share --export      # export container data first
lec share --encrypt     # encrypt with AES-256 (prompts for a password)
lec share --no-encrypt  # skip the encryption prompt
```

Without a flag, `lec share` asks whether to encrypt. Encryption requires the `7z` CLI. Set `LEC_SHARE_ENCRYPT_MODE` to `1`/`true`/`yes` to always encrypt, or `0`/`false`/`no` to never prompt.

## List entities

```sh
lec list           # show listable entities
lec list releases  # list all releases
```

## Update and version

```sh
lec update             # latest stable release
lec update --unstable  # latest master
lec version
```

## Targeting a project

`clean`, `exportData`, `importDLStructure`, `remove`, `share`, `start`, and `stop` accept `-p` / `--project` with a project name or path. Without it, the current directory is used.

```sh
lec start -p lec-LPP-12345
lec stop --project /path/to/project
```