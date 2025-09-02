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

### Database features overview

- [Enable MySQL 8.4](#enable-mysql-84)
- [Enable PostgreSQL 16.3](#enable-postgresql-163)
- [Import a database dump](#import-a-database-dump)
- [Enable database partitioning (MySQL and PostgreSQL only)](#enable-database-partitioning-mysql-and-postgresql-only)
- Supports Liferay clustering OOTB

### Elasticsearch features overview

- [Enable standalone Elasticsearch](#enable-standalone-elasticsearch)
- Supports Liferay clustering OOTB

### Webserver features overview

- [Enable NGINX (HTTP)](#enable-nginx-http)
- [Enable NGINX (HTTPS)](#enable-nginx-https)
- [Use custom hostnames](#use-custom-hostnames)
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

### Gradle tasks overview

- [Start up environment](#start-up-environment)
- [Shut down environment](#shut-down-environment)
- [Restart environment](#restart-environment)
- [Export container data](#export-container-data)
- [Zip the workspace for sharing](#zip-the-workspace-for-sharing)
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

#### Import a database dump

Database dump files can be added to the `./dumps` directory at the root of the Workspace. It will automatically be copied into the MySQL container.

```
./dumps/dumpfile.sql
```

#### Enable database partitioning (MySQL and PostgreSQL only)

Set the `lr.docker.environment.database.partitioning.enabled` property to `true` or `1` in `gradle.properties`.

`gradle.properties`:

```properties
lr.docker.environment.database.partitioning.enabled=true
```

### Elasticsearch Features

#### Enable standalone Elasticsearch

Set the `lr.docker.environment.service.enabled[elasticsearch]` property to `true` or `1` in `gradle.properties`.

`gradle.properties`:

```properties
lr.docker.environment.service.enabled[elasticsearch]=true
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
data_folder          (directory in their repsective container)
├── elasticsearch -> /usr/share/elasticsearch/data/
├── liferay       -> /opt/liferay/data
└── mysql         -> /var/lib/mysql
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

#### Clean up prepared hotfixes

```
./gradlew cleanPrepareHotfixes
```

#### Clean up all prepared data and built Liferay Docker images

```
./gradlew clean
```