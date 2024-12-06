# liferay-workspace-docker-environments

Sample docker-compose configurations for re-creating different environments

## Getting started

### Start up the environment

1. Configure the `config.json` file

1. Run `./gradlew composeUp`

### Shut down the environment

```
./gradlew composeDown
```

## `config.json` file reference

### `composeFiles`

A list of compose file paths that will be used to set up the environment. You should not have to manually adjust this, as it is much easier to use the `composeProfiles` property instead.

### `composeProfiles`

A list of "profiles" that defines the services to use in the environment. Each profile corresponds to a `docker-compose.{profileName}.yaml` file. For example, a file named `docker-compose.foobar.yaml` would make the `foobar` profile available. You can include as many profiles as you'd like.

You can see the list of available profiles by running the task: `./gradlew possibleProfiles`.

### `hotfixURLs`

A list of hotfix URLs. Each URL listed will be downloaded and placed into the `./configs/common/patching` directory, which will be copied to the Liferay docker image when it is built.

## Declaring a Liferay version

The Liferay version can be set in `gradle.properties`:

```properties
liferay.workspace.product=dxp-2024.q3.8
```

Possible values for that property can be found in the [releases.json](https://releases.liferay.com/releases.json) under the `releaseKey` key.

#### Quick tip:

If you are on Linux or MacOS and have `jq` installed, you can quickly see each of these values with the following shell one-liner:

```sh
curl -s https://releases-cdn.liferay.com/releases.json | jq -r '.[].releaseKey'
```

## Adding a database dump

If you are using the `mysql` profile, then a database dump can be added to the `./dumps/mysql` directory.

## Persisting data

Bound data directories will persist across container restarts.

The Liferay bundle's `data` folder is bound to the `./data/liferay/data` directory.
MySQL data is bound to the `./data/mysql` directory.

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

Properties files:

```
./configs/common/portal-ext.properties
```