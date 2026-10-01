## Where settings live

| File | Purpose |
|:--|:--|
| `gradle.properties` | Checked-in defaults for every `lr.docker.environment.*` property |
| `gradle-local.properties` | Local overrides of the same keys (gitignored) |
| `ports.env` | Host port ranges for each service |
| `liferay-jvm-opts.env` | Liferay JVM arguments |
| `configs/common/` | Files baked into the Liferay image (see [Customizing the Liferay Image](Customizing-the-Liferay-Image)) |

Boolean properties accept `true` or `1`.

## Enable a service

Every optional service is toggled the same way: set `lr.docker.environment.service.enabled[<service>]` to `true`, or pick it interactively with [`lec service`](lec-CLI-Reference#enable-services).

```properties
lr.docker.environment.service.enabled[mysql]=true
```

Service names: `mysql`, `postgres`, `db2`, `mariadb`, `sqlserver`, `elasticsearch`, `webserver`, `mail`, `ldap`, `keycloak`, `libreoffice`. Only one database can be enabled at a time.

## Ports

Each variable in `ports.env` defines a range; the exact port is picked automatically from whatever is free in that range. A single value pins the port.

```dotenv
LIFERAY_PORT=8080-8089
DATABASE_PORT=54321-54330
```

Each service page lists its own port variables. Run [`lec ports`](lec-CLI-Reference#print-ports) to see what was actually chosen.

`lec ports` prints both `http://localhost:<port>` and `http://<namespace>.localhost:<port>` for browser-facing ports. The `*.localhost` form gives each project a distinct hostname, so the browser keeps separate sessions per project. Either URL works.

> **macOS:** the OS resolver does not handle `*.localhost`. Chrome, Firefox, and Edge resolve it internally, but Safari, `curl`, `wget`, and other tools do not. Add `127.0.0.1 <namespace>.localhost` to `/etc/hosts` for each project if you use those tools.

## Docker image versions

Change service image versions with `lr.docker.environment.service.version[<service>]`. Defaults are in `gradle.properties`; override them in `gradle-local.properties` to avoid touching the checked-in values. Most non-default versions are untested and may need extra configuration.

`gradle-local.properties`:

```properties
lr.docker.environment.service.version[db2]=11.5.9.0
lr.docker.environment.service.version[elasticsearch]=7.17.9
lr.docker.environment.service.version[mariadb]=10.6.22-jammy
lr.docker.environment.service.version[mysql]=8.4.5-oracle
lr.docker.environment.service.version[postgres]=16.3
lr.docker.environment.service.version[sqlserver]=2022-CU21-ubuntu-22.04
```

For the Liferay image itself, see [Customizing the Liferay Image → Set the Liferay version](Customizing-the-Liferay-Image#set-the-liferay-version).