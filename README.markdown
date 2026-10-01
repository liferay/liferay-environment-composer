# Liferay Environment Composer

Tools for re-creating different Liferay environments and sharing those environments with others, built on Liferay Workspace and Docker Compose.

## Quick start

This Liferay Workspace is set up so you can immediately spin up an environment with Liferay, a database, Elasticsearch and an NGINX webserver set up. Different features and services can be included or omitted as needed.

To start up the environment, run `./gradlew start`.

To shut down the environment, run `./gradlew stop`.

## Requirements

- `docker` and `docker compose`
- Java 21

## Documentation

See the [wiki](https://github.com/liferay/liferay-environment-composer/wiki) for configuring services, importing data, sharing workspaces, and using the `lec` CLI.

The wiki is generated from [`docs/wiki/`](docs/wiki). To update it, edit those files in a pull request.