# liferay-workspace-docker-environments

Sample docker-compose configurations for re-creating different environments

## Getting started

### Start up the environment

1. Configure the environment in the `gradle.properties` file

1. Run `./gradlew composeUp`

### Shut down the environment

```
./gradlew composeDown
```

## `gradle.properties` file reference

### `lr.docker.environment.compose.files`

A list of compose file paths that will be used to set up the environment. You should not have to manually adjust this, as it is much easier to use the `composeProfiles` property instead.

### `lr.docker.environment.compose.profiles`

A list of "profiles" that defines the services to use in the environment. Each profile corresponds to a `docker-compose.{profileName}.yaml` file. For example, a file named `docker-compose.foobar.yaml` would make the `foobar` profile available. You can include as many profiles as you'd like.

You can see the list of available profiles by running the task: `./gradlew possibleProfiles`.

### `lr.docker.environment.data.directory`

An absolute or relative path to a directory containing data that will be mapped to each service container.

See [Persisting data](#persisting-data) for more information on how to import and export the mapped data directories.

### `lr.docker.environment.hotfix.urls`

A list of hotfix URLs. Each URL listed will be downloaded and placed into the `./configs/common/patching` directory, which will be copied to the Liferay docker image when it is built.

### `lr.docker.environment.cluster.nodes`

The number of cluster nodes to start up in addition to the main Liferay instance. Setting this to 0 means there is no clustering.

```properties
# This will start the main Liferay instance and 2 additional cluster nodes
lr.docker.environment.cluster.nodes=2
```

## Declaring a Liferay version

The Liferay version can be set in `gradle.properties`:

```properties
liferay.workspace.product=dxp-2024.q3.8
```

This property will automatically determine the Liferay Docker image version to be used. If you need to set a more specific Liferay Docker image version, you can set it with the `liferay.workspace.docker.image.liferay` property like so:

```properties
liferay.workspace.docker.image.liferay=liferay/dxp:7.2.10-sp8
```

Possible values for the `liferay.workspace.product` property can be found in the [releases.json](https://releases.liferay.com/releases.json) under the `releaseKey` key.

#### Quick tip:

If you are on Linux or MacOS and have `jq` installed, you can quickly see each of these values with the following shell one-liner:

```sh
curl -s https://releases-cdn.liferay.com/releases.json | jq -r '.[].releaseKey'
```

## Adding a database dump

If you are using the `mysql` profile, then a database dump can be added to the `./dumps` directory.

## Persisting data

If a `dataDirectory` is defined, data from that directory will be copied into their respective containers on startup. Where each service's data is mapped is declared in the corresponding `docker-compose.{serviceName}.yaml` file. Each service's data should be inside a sub-folder with the service's name.

### Exporting data for re-use

```
./gradlew exportContainerData
```

In order to retrieve data from the containers while they are running, use the `./gradlew exportContainerData` Gradle task. The data will be copied to a timestamped folder inside of `./exported_data`. The exported folder can then be referenced by the `dataDirectory` property in `config.json` like so:

```properties
lr.docker.environment.data.directory=exported_data/data_20241206.175343
```

## Deploying configuration and other files to the Liferay Docker image

Any files placed into the `./configs/common` directory will be copied to the Liferay bundle inside Docker image. The entire folder structure will be copied, so you can replicate the file structure of the bundle however you'd like.

### Examples

OSGi config files:

```
./configs/common/configs/SomeConfigFile.config
```

Document library files:

```
./configs/common/data/document_library
```

**Note:** both this method and the `dataDirectory` property are valid ways of providing files to Liferay container's `data` directory.

Properties files:

```
./configs/common/portal-ext.properties
```