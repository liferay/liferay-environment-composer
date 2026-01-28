# Liferay Environment Composer

Tools for re-creating different Liferay environments and sharing those environments with others, built on Liferay Workspace and Docker Compose.

## Quick start

This Liferay Workspace is set up so you can immediately spin up an environment with Liferay, a database, Elasticsearch and an NGINX webserver set up. Different features and services can be included or omitted as needed.

To start up the environment, run `./gradlew start`.

To shut down the environment, run `./gradlew stop`.

## Features

### Liferay features overview

- [Set the Liferay Docker image version](#set-the-liferay-docker-image-version)
- [Deploy OSGi configs](#deploy-osgi-configs)
- [Deploy portal-ext.properties](#deploy-portal-ext.properties)
- [Deploy hotfixes](#deploy-hotfixes)
- [Deploy custom modules and projects](#deploy-custom-modules-and-projects)
- [Set the Liferay version for building modules](#set-the-liferay-version-for-building-modules)
- [Deploy a Document Library](#deploy-a-document-library)
- [Deploy license files](#deploy-license-files)
- [Enable clustering](#enable-clustering)
- [Configure Liferay ports](#configure-liferay-ports)
- [Enable LibreOffice integration](#enable-libreoffice-integration)
- [Configure document library store](#configure-document-library-store)
- [Enable media previews](#enable-media-previews)

### Database features overview

- [Enable MySQL 8.4](#enable-mysql-84)
- [Enable PostgreSQL 16.3](#enable-postgresql-163)
- [Enable DB2 11.5](#enable-db2-115)
- [Enable MariaDB 10.6](#enable-mariadb-106)
- [Enable SQL Server 2022](#enable-sql-server-2022)
- [Import a database dump](#import-a-database-dump)
- [Enable database partitioning (MySQL and PostgreSQL only)](#enable-database-partitioning-mysql-and-postgresql-only)
- [Configure database port](#configure-database-port)
- Supports Liferay clustering OOTB

### Elasticsearch features overview

- [Enable standalone Elasticsearch](#enable-standalone-elasticsearch)
- [Configure Elasticsearch ports](#configure-elasticsearch-ports)
- Supports Liferay clustering OOTB

### Mail features overview

- [Enable the mail service](#enable-the-mail-service)
- [Configure mail service ports](#configure-mail-service-ports)

### Webserver features overview

- [Enable NGINX (HTTP)](#enable-nginx-http)
- [Enable NGINX (HTTPS)](#enable-nginx-https)
- [Use custom hostnames](#use-custom-hostnames)
- [Configure webserver ports](#configure-webserver-ports)
- Supports Liferay clustering OOTB

### Java Virtual Machine features overview
- [Use custom JVM arguments to improve performance](#use-custom-jvm-arguments-to-improve-performance)

### Data features overview

- [Export container data to a timestamped directory](#export-container-data-to-a-timestamped-directory)
- [Import data for various containers](#import-data-for-various-containers)

### Profiling features overview

- [Enable Glowroot](#enable-glowroot)
- [Enable YourKit](#enable-yourkit)

### Sharing features overview
- [Zip up the workspace to share the setup](#zip-up-the-workspace-to-share-the-setup)

### Docker features overview

- [Build a custom Liferay image with custom modules and configs included](#build-a-custom-liferay-image-with-custom-modules-and-configs-included)
- [Start up and shut down the Docker Compose containers](#start-up-and-shut-down-the-docker-compose-containers)
- [Customize Docker image versions](#customize-docker-image-versions)

### Gradle tasks overview

- [Start up environment](#start-up-environment)
- [Shut down environment](#shut-down-environment)
- [Restart environment](#restart-environment)
- [Export container data](#export-container-data)
- [Zip the workspace for sharing](#zip-the-workspace-for-sharing)
- [Export the Liferay logs, reports, and routes directories](#export-the-liferay-logs,-reports,-and-routes-directories)
- [Clean up prepared hotfixes](#clean-up-prepared-hotfixes)
- [Clean up all prepared data and built Liferay Docker images](#clean-up-all-prepared-data-and-built-liferay-docker-images)

## Requirements

- You must have `docker` and `docker compose` installed

## Manual

### Liferay Features

#### Set the Liferay Docker image version

Set the `liferay.workspace.docker.image.liferay` property in `gradle.properties`.

This will override the Docker image version that is determined from the `liferay.workspace.product` property (see [Set the Liferay version for building modules](#set-the-liferay-version-for-building-modules)).

`gradle.properties`:

```properties
liferay.workspace.docker.image.liferay=liferay/dxp:7.2.10-sp8
```

#### Deploy OSGi configs

Place OSGi `.config` files in the `./configs/common/configs` directory. They will be included in the built Liferay image.

OSGi config files:

```
./configs/common/configs/SomeConfigFile.config
```

#### Deploy portal-ext.properties

Place `*.properties` files in the `./configs/common` directory. They will be included in the built Liferay image.

Properties files:

```
./configs/common/portal-ext.properties
```

#### Deploy hotfixes

Add hotfix URLs to the `lr.docker.environment.hotfix.urls` property in `gradle.properties` as a comma-separated string. Each URL listed will be downloaded and placed into the `./configs/common/patching` directory, which will be included in the built Liferay image.

`gradle.properties`:

```properties
lr.docker.environment.hotfix.urls=\
    https://releases-cdn.liferay.com/dxp/hotfix/2024.q2.7/liferay-dxp-2024.q2.7-hotfix-4.zip,\
    https://releases-cdn.liferay.com/dxp/hotfix/2024.q2.7/liferay-dxp-2024.q2.7-hotfix-5.zip
```

*Note:* Local file URLs are also supported using the `file://` protocol.

#### Deploy custom modules and projects

Liferay Workspace will automatically build and deploy custom modules and projects contained in the Workspace to the built Liferay Docker image. More documentation on creating and building projects can be found at [Liferay Learn](https://learn.liferay.com/w/dxp/liferay-development/tooling/liferay-workspace).

#### Set the Liferay version for building modules

#### Deploy a Document Library

Document library files can be added to Liferay in one of two ways:

1. Add the document library folder to `./configs/common/data/document_library`

1. Include the document library as part of the data directory defined by the `lr.docker.environment.data.directory` property. See [Data Features](#data-features) for more details on how to create and use data directories.

Document library files for method #1:

```
./configs/common/data/document_library
```

##### If you receive a very large Document Library

If you receive a very large Document Library and do not need the actual file contents, you may want to copy the file structure only. The `lec` script provides the `lec importDLStructure` command to assist with this:

```sh
lec importDLStructure <source_directory>
```

The source directory's _file structure only_ will be copied into `./configs/common/data/document_library`.

#### Deploy license files

Add a license files to `./configs/common/osgi/modules`.

*Note:* The Gradle command to start the server will fail if there are no license files and you are trying to start up a Liferay DXP image.

#### Enable clustering

Clustering can be enabled by setting the `lr.docker.environment.cluster.nodes` property in `gradle.properties`. Setting it to 0 means no clustering is enabled. Setting it to 1 or more will add that many cluster nodes in addition to the main Liferay instance.

`gradle.properties`:

```properties
# This will start the main Liferay instance and 2 additional cluster nodes
lr.docker.environment.cluster.nodes=2
```

#### Configure Liferay ports

You can configure the Liferay ports in the `ports.env` file. Each variable in this file defines a range from which the
exact port numbers will be automatically chosen based on availability.

`ports.env`:

```dotenv
LIFERAY_PORT=8080-8089
LIFERAY_GOGO_SHELL_PORT=11311-11319
LIFERAY_DEBUG_PORT=8000-8009
LIFERAY_YOURKIT_PORT=10001-10010
```

#### Enable LibreOffice integration

You can enable LibreOffice integration with Liferay by setting the `lr.docker.environment.service.enabled[libreoffice]` property to `true` or `1` in `gradle.properties`.

`gradle.properties`:

```properties
lr.docker.environment.service.enabled[libreoffice]=true
```

#### Configure document library store

You can configure which document library store Liferay will use by setting the `lr.docker.environment.dl.store` property in the `gradle.properties` file. Valid document library store options are `advanced`, `db`, `s3`, and `simple`. The default document library store is `simple`.

`gradle.properties`:

```properties
lr.docker.environment.dl.store=simple
```

##### Configuring advanced file system store

When using the `advanced` document library store option, you will also need to define the path used to specify the document library directory by setting the `lr.docker.environment.dl.store.path` property in `gradle.properties`.

`gradle.properties`:

```properties
lr.docker.environment.dl.store.path=data/document_library
```

##### Configuring S3 store

When using the `s3` document library store option, you must also provide additional details related to the S3-compatible object storage bucket in `gradle.properties`.

`gradle.properties`:

```properties
lr.docker.environment.s3.access.key=
lr.docker.environment.s3.bucket.name=
lr.docker.environment.s3.region=
lr.docker.environment.s3.secret.key=
```

You may also need to configure the endpoint URL by setting the value for the `lr.docker.environment.s3.endpoint` property in `gradle.properties`.

`gradle.properties`:

```properties
lr.docker.environment.s3.endpoint=

#### Enable media previews

You can enable media previews in Liferay by setting the `lr.docker.environment.media.preview.enabled` property to `true` or `1` in `gradle.properties`.

`gradle.properties`:

```properties

lr.docker.environment.preview.media.enabled=true

```

### Java Virtual Machine features overview

#### Use custom JVM arguments to improve performance

To customize Liferay's JVM arguments, modify the `LIFERAY_JVM_OPTS` variable in `./liferay-jvm-opts.env`. This file already includes several default arguments for better server performance.

### Database Features

#### Enable MySQL 8.4

Set the `lr.docker.environment.service.enabled[mysql]` property to `true` or `1` in `gradle.properties`.

`gradle.properties`:

```properties

lr.docker.environment.service.enabled[mysql]=true

```

#### Enable PostgreSQL 16.3

Set the `lr.docker.environment.service.enabled[postgres]` property to `true` or `1` in `gradle.properties`.

`gradle.properties`:

```properties

lr.docker.environment.service.enabled[postgres]=true

```

#### Enable DB2 11.5

Set the `lr.docker.environment.service.enabled[db2]` property to `true` or `1` in `gradle.properties`.

`gradle.properties`:

```properties

lr.docker.environment.service.enabled[db2]=true

```

#### Enable MariaDB 10.6

Set the `lr.docker.environment.service.enabled[mariadb]` property to `true` or `1` in `gradle.properties`.

`gradle.properties`:

```properties

lr.docker.environment.service.enabled[mariadb]=true

```

#### Enable SQL Server 2022

Set the `lr.docker.environment.service.enabled[sqlserver]` property to `true` or `1` in `gradle.properties`.

`gradle.properties`:

```properties

lr.docker.environment.service.enabled[sqlserver]=true

```

#### Import a database dump

Database dump files can be added to the `./dumps` directory at the root of the Workspace. They will automatically be copied into the database container.

```

./dumps/dumpfile.sql # raw database dump file
./dumps/dumpfile.gz # compressed database dump file downloaded from LXC or extracted from a password-protected archive

```

For SaaS database backups, you will often be provided with a password-protected 7zip file. While ideally you would extract the file, the tool can also automatically extract it for you if you set the `lr.docker.environment.lxc.backup.password` property in `gradle.properties` to the provided password.

```

./dumps/dumpfile.7z # database dump file provided by SRE team (SaaS), usually password-protected
./dumps/dumpfile.zip # database dump file provided by SRE team (SaaS), usually password-protected

```

When importing SaaS database backups, make sure to set properties to allow the tool to find information related to the SaaS environment.

```

lr.docker.environment.lxc.environment.name=abc1prd

```

For example, if the projectId is `lxcabc1-abc1prd`, the environment name name is `abc1prd`. The tool will use this information to automatically copy configurations from the `liferay/liferay-lxc` repository, which it assumes will be located at `${user.home}/dev/projects/liferay-lxc`. If it is not located at this location, you will need to set the correct path as an environment variable.

```

export LXC_REPOSITORY_PATH=/home/me/dev/projects/liferay-lxc

```

#### Enable database partitioning (MySQL and PostgreSQL only)

Set the `lr.docker.environment.database.partitioning.enabled` property to `true` or `1` in `gradle.properties`.

`gradle.properties`:

```properties

lr.docker.environment.database.partitioning.enabled=true

```

#### Configure database port

The database port can be configured by the `DATABASE_PORT` environment variable in the `ports.env` file.

`ports.env`:

```dotenv

DATABASE_PORT=54321-54330

```

#### Reset user passwords

Set the `lr.docker.environment.liferay.user.password` property to the password you wish to type when signing in using existing users in imported databases.

```properties

lr.docker.environment.liferay.user.password=test

```

### Elasticsearch Features

#### Enable standalone Elasticsearch

Set the `lr.docker.environment.service.enabled[elasticsearch]` property to `true` or `1` in `gradle.properties`.

`gradle.properties`:

```properties

lr.docker.environment.service.enabled[elasticsearch]=true

```

#### Configure Elasticsearch ports

The Elasticsearch HTTP and transport ports can be configured by the `ELASTICSEARCH_HTTP_PORT` and
the `ELASTICSEARCH_TRANSPORT_PORT` environment variables respectively in the `ports.env` file.

`ports.env`:

```dotenv

ELASTICSEARCH_HTTP_PORT=9200-9209
ELASTICSEARCH_TRANSPORT_PORT=9300-9309

```

### Mail features

#### Enable the mail service

Set the `lr.docker.environment.service.enabled[mail]` property to `true` or `1` in `gradle.properties`.

`gradle.properties`:

```properties

lr.docker.environment.service.enabled[mail]=true

```

#### Configure mail service ports

The mail service's web and SMTP ports can be configured by the `MAIL_WEB_PORT` and `MAIL_SMTP_PORT` environment variables
respectively in the `ports.env` file.

`ports.env`:

```dotenv

MAIL_WEB_PORT=1080
MAIL_SMTP_PORT=1025

```

### Webserver Features

#### Enable NGINX (HTTP)

Set the `lr.docker.environment.service.enabled[webserver_http]` property to `true` or `1` in `gradle.properties`.

`gradle.properties`:

```properties

lr.docker.environment.service.enabled[webserver_http]=true

```

#### Enable NGINX (HTTPS)

Set the `lr.docker.environment.service.enabled[webserver_https]` property to `true` or `1` in `gradle.properties`.

`gradle.properties`:

```properties

lr.docker.environment.service.enabled[webserver_https]=true

```

#### Configure webserver ports

The webserver HTTP and HTTPS ports can be configured by the `WEBSERVER_HTTP_PORT` and the `WEBSERVER_HTTPS_PORT`
environment variables respectively in the `ports.env` file.

`ports.env`:

```dotenv

WEBSERVER_HTTP_PORT=80
WEBSERVER_HTTPS_PORT=443

```

#### Use custom hostnames

Specify the hostnames through which you want to access Liferay using the `lr.docker.environment.web.server.hostnames` property.
You can provide multiple hostnames, separated by commas.

```properties

lr.docker.environment.web.server.hostnames=localhost

```

### Data Features

#### Export container data to a timestamped directory

```

./gradlew exportContainerData

```

This will export data from each of the running containers to a timestamped directory inside of `./exported_data`. This directory can then be directly referenced by the `lr.docker.environment.data.directory` property to re-use that data on future startups.

**Note:** This repo intentionally does not bind-mount container directories to host directories as it can easily cause startup issues due to user permission mismatches. It is a known issue with Docker Compose.

#### Import data for various containers

Set the `lr.docker.environment.data.directory` property in `gradle.properties` to a relative or absolute path to a directory. This directory structure illustrates where each service directory is mapped in the respective container:

```

data_folder (directory in their repsective container)
├── elasticsearch -> /usr/share/elasticsearch/data/
├── liferay -> /opt/liferay/data
└── mysql -> /var/lib/mysql

```

`gradle.properties`:

```properties

lr.docker.environment.data.directory=exported_data/data_20241206.175343

```

### Profiling features

#### Enable Glowroot

Set the `lr.docker.environment.glowroot.enabled` property to `true` or `1` in `gradle.properties` to enable Glowroot.

`gradle.properties`:

```properties

lr.docker.environment.glowroot.enabled=true

```

#### Enable YourKit

Set the `lr.docker.environment.yourkit.enabled` property to `true` or `1` in `gradle.properties` to enable YourKit.

`gradle.properties`:

```properties

lr.docker.environment.yourkit.enabled=true

```

You can provide the download URL of the preferred YourKit version zip in the `lr.docker.environment.yourkit.url` property.

`gradle.properties`:

```properties

lr.docker.environment.yourkit.url=https://www.yourkit.com/download/docker/YourKit-JavaProfiler-2025.3-docker.zip

```

### Sharing Features

#### Zip up the workspace to share the setup

```

./gradlew shareWorkspace

```

This will zip up the workspace as-is, including the declared data folder, into a shareable `zip` file. The zipped workspace will be timestamped and placed in the `./shared_workspaces` directory. It will omit unnecessary files such as the `.gradle` and `.git` directories, as well as other exported data folders and shared workspaces in the `exported_data` and `shared_workspaces` directories.

The shared workspace should be immediately usable by simply unzipping the archive, `cd` to the unzipped folder, and starting up with `./gradlew start`.

### Docker Features

#### Customize Docker image versions

You can change Docker image versions for several services in the `versions.env` file. Most version have not been tested, so extra configuration may be needed when changing versions to get them working.

`versions.env`:

```dotenv

DB2_VERSION=11.5.9.0
MARIADB_VERSION=10.6.22-jammy
MYSQL_VERSION=8.4.5-oracle
POSTGRES_VERSION=16.3
SQLSERVER_VERSION=2022-CU21-ubuntu-22.04

```

### Gradle tasks

#### Start up environment

```

./gradlew start

```

#### Shut down environment

```

./gradlew stop

```

By default, stopping a container will delete all persistent data, which has the desirable side-effect that product team members always start from a clean reproduced environment, but has the undesirable side-effect that customer support engineers always lose all changes since the last saved reproduced environment.

To change this behavior, set the following in your `gradle-local.properties`:

```properties

lr.docker.environment.clear.volume.data=false

```

#### Restart environment

```

./gradlew restart

```

This will also stop the environment, so please see the previous note which describes the strategy for persisting data between restarts.

#### Export container data

```

./gradlew exportContainerData

```

#### Zip the workspace for sharing

```

./gradlew shareWorkspace

```

#### Export the Liferay logs, reports, and routes directories

```

./gradlew exportLiferayLogs

```

This will copy the logs, reports, and routes directories to the `./exports/liferay` directory on your machine (host machine).

#### Clean up prepared hotfixes

```

./gradlew cleanPrepareHotfixes

```

#### Clean up all prepared data and built Liferay Docker images

```

./gradlew clean

```

## Convenience script

Creating new workspaces can be tedious, so we have provided a shell script to help automate some repetitive tasks.

To use this shell script, add the following snippet to your `.bashrc` or `.zshrc`, replacing the values with the correct file paths:

```sh

#

# Liferay Environment Composer

#

# This environment variable should be the path to your clone of this repository (or your own fork).

export LIFERAY_ENVIRONMENT_COMPOSER_HOME="$HOME/Documents/liferay/liferay-environment-composer"

# Source the cli

[[ -s "$LIFERAY_ENVIRONMENT_COMPOSER_HOME/scripts/cli/shell-source.sh" ]] && source "$LIFERAY_ENVIRONMENT_COMPOSER_HOME/scripts/cli/shell-source.sh"

# Optional: This environment variable should point to a directory where you want projects created when running `lec init`.

export LIFERAY_ENVIRONMENT_COMPOSER_WORKSPACES_DIR="$HOME/Documents/liferay/tickets"

```

This will provide the `lec` script alias and the `lecd` shell function.

### Script Usage

Create a new workspaces:

```sh

lec init # No args

lec init LPP-12345 # Pass in the LPP ticket number

lec init LPP-12345 dxp-2025.q3.0 # Pass in the LPP ticket number and the Liferay version

lec init LPP-12345 abc1prd # Pass in the LPP ticket number and the SaaS environment name

```

The `lec-init` shell function is the same as `lec init`, but will also jump to the new project after it is created.

Start the workspace:

```sh

lec start # Starts the environment and tails the logs

```

Stop the workspace:

```sh

lec stop # Shuts down the environment

```

Stop the workspace and delete the Docker volumes:

```sh

lec clean # Shuts down the environment and deletes the Docker volumes

```

Completely tear down and remove one or more Composer projects:

```sh

lec remove # Choose one or more projects to remove

```

List various entities

```sh

lec list # Displays entities that can be listed; `lec list <entity>` lists all entries of the selected entity.
lec list releases # Displays all releases.

```

Jump to a workspace:

```sh

lecd # Choose from a list
lecd workspace-name # Pre-filter the list by name. If only one matches, jump there.

```