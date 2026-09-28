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

Clustering needs a database that every node shares, such as any [database service](Database-Service), and a license that allows clustering in `./configs/common/osgi/modules`. Trial, developer, and limited licenses do not allow clustering, so they are deleted from that folder at startup.

The cluster nodes start after the main instance is healthy, one at a time, so that they do not set up the same data at the same time. Each node gets its own ports from the ranges in `ports.env`, which [`lec ports`](lec-CLI-Reference) prints. The page footer shows which node served the page.

Enable the [Elasticsearch service](Elasticsearch-Service) when clustering. Without it, every node starts its own sidecar Elasticsearch, so each node searches its own index and needs about 1.3 GB more memory.

Every cluster node is another full Liferay JVM, so give Docker enough memory. With the default JVM settings and the Elasticsearch service, the main instance uses about 4 GB, each cluster node about 3.5 GB, and Elasticsearch about 2 GB. The main instance, two cluster nodes, Elasticsearch, and MySQL use about 14 GB right after startup.

### Use TCP unicast

By default, the nodes find each other over UDP multicast. To use TCP unicast (JGroups `TCPPING`) instead, set `lr.docker.environment.cluster.unicast.enabled` to `true`, and enable a database service and the Elasticsearch service:

```properties
# Main instance plus 1 cluster node
lr.docker.environment.cluster.nodes=1
lr.docker.environment.cluster.unicast.enabled=true

# Every node must share one database. Any of the database services works.
lr.docker.environment.service.enabled[mysql]=true

# Without the Elasticsearch service, every node searches its own sidecar index
lr.docker.environment.service.enabled[elasticsearch]=true
```

The database service also sets the address that JGroups uses to find the network interface to bind to (`cluster.link.autodetect.address`). Without a database service, Liferay looks it up by connecting to `www.google.com:80`, which only works if the containers can reach the internet.

The JGroups configuration is in `./configs/docker/tomcat/webapps/ROOT/WEB-INF/classes/jgroups/tcp.xml`. JGroups resolves the `TCPPING` hosts when the channel starts and fails on any host that does not resolve, such as a node that is not running. So when a node starts, `./configs/docker/scripts/configure_jgroups_tcpping_hosts.sh` builds its host list from what is running:

- The main instance lists itself, and the `liferay-cluster-node` service if any cluster node is running.
- The cluster nodes list the `liferay-cluster-node` service, which resolves to every cluster node that is running, and the main instance if it is running.

A node that restarts, even with a different IP address, rejoins the nodes that are still running.

To check that the cluster formed, look for the cluster view in the logs. It should list every node:

```sh
docker compose logs liferay liferay-cluster-node | grep "Accepted view"
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