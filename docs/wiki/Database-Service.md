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

Put one dump file in `./dumps` at the workspace root. It is copied into the database container automatically.

| Database | Supported dump files |
|:--|:--|
| MySQL | `.sql`, `.sql.bz2`, `.sql.gz`, `.sql.xz`, `.sql.zst` |
| MariaDB | `.sql`, `.sql.bz2`, `.sql.gz`, `.sql.xz`, `.sql.zst` |
| PostgreSQL | `.sql`, `.sql.bz2`, `.sql.gz`, `.sql.xz`, `.sql.zst`, or a `pg_dump` custom/tar archive ending in `.bak`, `.dmp`, `.dump`, or `.pg` |
| DB2 | A `db2move` export (`db2move.lst` and its table files, packed into one archive), or a backup image from `db2 BACKUP DATABASE` with its original file name (e.g. `LPORTAL.0.db2admin.DBPART000.20260130234412.001`) |
| SQL Server | `.bacpac` or `.bak` |

Any of these can also be wrapped in an archive, which is extracted first: `.7z`, `.bz2`, `.gz`, `.tar.bz2`, `.tar.gz`, `.tbz`, `.tgz`, or `.zip`.

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