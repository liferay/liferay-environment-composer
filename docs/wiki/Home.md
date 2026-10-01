Tools for re-creating different Liferay environments and sharing those environments with others, built on Liferay Workspace and Docker Compose.

## Quick start

This workspace is set up so you can immediately spin up an environment with Liferay, a database, Elasticsearch, and an NGINX webserver. Different features and services can be included or omitted as needed.

```sh
./gradlew start   # start the environment
./gradlew stop    # shut it down
```

For day-to-day use, set up the [`lec` CLI](lec-CLI-Reference), which creates per-ticket workspaces and wraps the common tasks.

## Requirements

- `docker` and `docker compose`
- Java 21

## Key concepts

- **Properties-driven.** Nearly everything is toggled in `gradle.properties`. See [Configuring the Environment](Configuring-the-Environment).
- **Ephemeral data by default.** Stopping the environment deletes container data so every start is a clean reproduction. See [Saving and Sharing Data](Saving-and-Sharing-Data#keep-data-between-restarts) to change this.
- **No bind-mounts.** Container directories are never bind-mounted to the host, which avoids Docker user-permission issues. Use [`exportContainerData`](Saving-and-Sharing-Data#export-container-data) to save state instead.

## Guide

| Page | Covers |
|:--|:--|
| **Getting set up** | |
| [Configuring the Environment](Configuring-the-Environment) | `gradle.properties`, enabling services, ports, image versions |
| [lec CLI Reference](lec-CLI-Reference) | The convenience script |
| [Gradle Task Reference](Gradle-Task-Reference) | Every `./gradlew` task |
| **Liferay** | |
| [Customizing the Liferay Image](Customizing-the-Liferay-Image) | Version, deploying artifacts/configs/hotfixes, clustering, JVM args |
| [Document Library](Document-Library) | Importing a DL, store types, LibreOffice, media previews |
| [SAML with Keycloak](SAML-with-Keycloak) | Keycloak as a SAML IdP |
| **Services** | |
| [Database Service](Database-Service) | MySQL, PostgreSQL, DB2, MariaDB, SQL Server, dump import, partitioning |
| [Elasticsearch Service](Elasticsearch-Service) | Standalone Elasticsearch |
| [Webserver Service](Webserver-Service) | NGINX, HTTPS, ModSecurity, hostnames |
| [Mail Service](Mail-Service) · [LDAP Service](LDAP-Service) | Supporting services |
| **Operations** | |
| [Saving and Sharing Data](Saving-and-Sharing-Data) | Persisting, exporting, and importing data; sharing a workspace |
| [Profiling Liferay](Profiling-Liferay) | Glowroot, YourKit |