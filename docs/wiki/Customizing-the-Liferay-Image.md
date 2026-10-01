## Set the Liferay version

Set `liferay.workspace.product` in `gradle.properties`. This sets both the version used to build workspace modules and the Liferay Docker image. See [releases.json](https://releases.liferay.com/releases.json) for valid values.

```properties
liferay.workspace.product=dxp-2026.q1.6-lts
```

To use a more specific image than the product key provides (for example a nightly), also set `liferay.workspace.docker.image.liferay`. It overrides the image chosen by `liferay.workspace.product`. At least one of the two properties is required.

```properties
liferay.workspace.docker.image.liferay=liferay/dxp:7.4.13.nightly
```

## Deploy artifacts and configuration

Everything under `./configs/common` is baked into the built Liferay image.

| What | Where | Example |
|:--|:--|:--|
| JARs, ZIPs, `license*.xml` | `configs/common/deploy/` | `com.liferay.apio.samples.portlet-1.0.0.jar` |
| OSGi `.config` files | `configs/common/configs/` | `SomeConfigFile.config` |
| `*.properties` files | `configs/common/` | `portal-ext.properties` |
| License files | `configs/common/deploy/` or `configs/common/osgi/modules/` | |

> Starting a Liferay DXP image fails if no license file is present.

### Custom modules and projects

Liferay Workspace automatically builds custom modules and projects in the workspace and deploys them into the built image. See [Liferay Learn](https://learn.liferay.com/w/dxp/liferay-development/tooling/liferay-workspace) for creating and building projects.

## Deploy hotfixes

Add hotfix URLs to `lr.docker.environment.hotfix.urls` as a comma-separated list. Each one is downloaded into `./configs/common/patching` and included in the image. `file://` URLs also work.

```properties
lr.docker.environment.hotfix.urls=\
    https://releases-cdn.liferay.com/dxp/hotfix/2024.q2.7/liferay-dxp-2024.q2.7-hotfix-4.zip,\
    https://releases-cdn.liferay.com/dxp/hotfix/2024.q2.7/liferay-dxp-2024.q2.7-hotfix-5.zip
```

Or run `lec hotfix`: it lists hotfixes for the project's Liferay version, downloads the one you pick, and adds its URL to the property.

Clean up downloaded hotfixes with [`./gradlew cleanPrepareHotfixes`](Gradle-Task-Reference).

## Enable clustering

Set `lr.docker.environment.cluster.nodes` to the number of nodes to add alongside the main instance. `0` disables clustering. The database, Elasticsearch, and webserver services support clustering out of the box.

```properties
# Main instance plus 2 cluster nodes
lr.docker.environment.cluster.nodes=2
```

## Ports

`ports.env`:

```dotenv
LIFERAY_PORT=8080-8089
LIFERAY_GOGO_SHELL_PORT=11311-11319
LIFERAY_DEBUG_PORT=8000-8009
LIFERAY_YOURKIT_PORT=10001-10010
```

See [Configuring the Environment → Ports](Configuring-the-Environment#ports) for how ranges and `*.localhost` URLs work.

## JVM arguments

Edit `LIFERAY_JVM_OPTS` in `./liferay-jvm-opts.env`. It ships with defaults tuned for server performance.