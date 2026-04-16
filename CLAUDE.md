# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Liferay Environment Composer - a Liferay Workspace project for creating reproducible Liferay development environments using Docker Compose. It orchestrates Liferay DXP with databases, Elasticsearch, NGINX, Keycloak, and other services.

## Common Commands

```bash
# Start/stop environment
./gradlew start          # Start all configured services
./gradlew stop           # Stop all containers
./gradlew restart        # Restart environment

# Build
./gradlew build
./gradlew buildDockerImage    # Build custom Liferay Docker image with configs

# Source formatting (Liferay Source Formatter)
./gradlew formatSource                         # Format source files
./gradlew formatSource -Denv.mode.ci=true      # CI mode (fails on auto-fix)

# Tests (BATS - Bash Automated Testing System)
# Preferred: use `lec bats` which sets BATS_FILE_EXTENSION and other env vars
lec bats ./scripts/tests/<test-file>.test.sh
# Or directly: ./scripts/vendor/bats/bin/bats ./scripts/tests/<test-file>.test.sh
# Test files: test-database-import, test-e2e-basic, test-initial-startup, test-port-resolution

# Data management
./gradlew exportContainerData
./gradlew importContainerData
./gradlew importDatabaseDumps    # Import from ./dumps directory

# Utilities
./gradlew executeSQLQuery -PsqlQuery="SELECT ..."
./gradlew exportLiferayLogs
./gradlew printBundleInfo        # Print Liferay bundle version info
./gradlew shareWorkspace         # Zip workspace for distribution
```

## Architecture

### Build System

Gradle with Groovy DSL. Custom plugins live in `buildSrc/src/main/groovy/`:
- `docker-common.gradle` - Shared Docker Compose orchestration (composeUp/composeDown, volume management, compose file assembly)
- `docker-database-saas.gradle` - Database import/export tasks
- `docker-keycloak.gradle` - Keycloak IdP setup and SAML configuration
- `docker-liferay-bundle.gradle` - Liferay Docker image building and deployment

`Config.groovy` reads all `lr.docker.environment.*` properties from `gradle.properties` and exposes them as a typed config object used throughout the build scripts.

### Service Composition

Services are defined as modular YAML fragments in `compose-recipes/<service>/`:
- `service.<name>.yaml` - Base service definition
- Optional feature overlays (e.g., `clustering.liferay.yaml`, `glowroot.liferay.yaml`)

Services are toggled via `lr.docker.environment.service.enabled[<name>]` in `gradle.properties`. The build assembles enabled services into the final Docker Compose configuration.

### Configuration Layers

- `configs/common/` - Shared deployment artifacts (JARs, OSGi configs, properties, licenses, hotfixes)
- `configs/docker/` - Docker-specific overrides
- `configs/local/` - Local overrides (gitignored)
- `gradle.properties` - Primary configuration file for all environment settings
- `ports.env` / `versions.env` - Port ranges and Docker image versions

### CLI Tool

`scripts/cli/lec.sh` - Interactive shell tool for workspace lifecycle management. Source it with `source scripts/cli/shell-source.sh` to get the `lec` command.

Key subcommands:
- `lec init [ticket] [version]` - Initialize a new project workspace
- `lec start` / `lec stop` / `lec restart` / `lec clean` - Lifecycle management
- `lec ports` - Print exposed ports
- `lec list` - List available entities/releases
- `lec bats` - Run BATS tests with correct env vars
- `lec exportData` / `lec importDLStructure` - Data management
- `lec remove` / `lec rm` - Remove project workspace
- `lec share` - Share workspace
- `lec update` - Update LEC
- `lec version` - Print version info

## Key Concepts

- **Ephemeral data by default** - Stopping a container deletes all persistent data to ensure clean reproducible environments. Set `lr.docker.environment.clear.volume.data=false` in `gradle-local.properties` to persist data.
- **No bind-mounts** - The project intentionally does not bind-mount container directories to avoid Docker user permission issues. Use `./gradlew exportContainerData` to save state.
- **Properties-driven** - Most environment flags and feature toggles are defined in `gradle.properties`.

## Key Properties

All environment configuration goes through `gradle.properties` with the `lr.docker.environment.*` prefix. Supported databases: MySQL, PostgreSQL, DB2, MariaDB, SQL Server. Only one database can be enabled at a time.

## Languages

- **Groovy** - Gradle build scripts and plugins
- **Bash** - Shell scripts and BATS tests
- **YAML** - Docker Compose service definitions
- **Java Properties / XML** - Liferay configuration

## CI

GitHub Actions workflows in `.github/workflows/`:
- `check-source-formatting.yaml` - Runs `./gradlew formatSource -Denv.mode.ci=true`
- `validate-database-import.yaml` - Validates database import
- `test-e2e-basic.yaml` - Runs BATS e2e test
- `test-webserver-service.yaml` - Tests webserver service
- `validate-initial-startup.yaml` - Validates Liferay startup with each database type

## Requirements

- Docker and Docker Compose
- Java 21