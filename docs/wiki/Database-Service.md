## Enable a database

[Enable](Configuring-the-Environment#enable-a-service) exactly one of:

| Database | Service name |
|:--|:--|
| MySQL 8.4 | `mysql` |
| PostgreSQL 16.3 | `postgres` |
| DB2 11.5 | `db2` |
| MariaDB 10.6 | `mariadb` |
| SQL Server 2022 | `sqlserver` |

```properties
lr.docker.environment.service.enabled[mysql]=true
```

To use a different engine version, see [Configuring the Environment → Docker image versions](Configuring-the-Environment#docker-image-versions).

## Default login

All engines share one login, which you can override:

```properties
lr.docker.environment.database.user=liferay
lr.docker.environment.database.password=Liferay123
```

## Import a database dump

Put dump files in `./dumps` at the workspace root. They are copied into the database container automatically.

```
./dumps/dumpfile.sql   # raw dump
./dumps/dumpfile.gz    # compressed dump, e.g. downloaded from LXC
```

### SaaS backups

SRE usually provides a password-protected `.7z` or `.zip`. You can extract it yourself, or set the password and let the tool do it:

```properties
lr.docker.environment.lxc.backup.password=<password>
```

Also set the SaaS environment name so the tool can copy the environment's configuration. For project ID `lxcabc1-abc1prd`, the name is `abc1prd`:

```properties
lr.docker.environment.lxc.environment.name=abc1prd
```

Configuration is copied from a clone of `liferay/liferay-lxc`, expected at `~/dev/projects/liferay-lxc`. If yours is elsewhere:

```sh
export LXC_REPOSITORY_PATH=/home/me/dev/projects/liferay-lxc
```

## Reset user passwords

For imported databases, set `lr.docker.environment.liferay.user.password` to the password you want to sign in with for existing users.

```properties
lr.docker.environment.liferay.user.password=test
```

## Enable database partitioning

MySQL and PostgreSQL only.

```properties
lr.docker.environment.database.partitioning.enabled=true
```

## Run a SQL query

```sh
./gradlew executeSQLQuery -PsqlQuery="SELECT * FROM User_"
```

## Ports

`ports.env`:

```dotenv
DATABASE_PORT=54321-54330
```