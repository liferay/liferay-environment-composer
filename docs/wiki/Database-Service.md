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

A PostgreSQL dump whose Liferay tables are in a schema other than `public` (for example, `liferay`) is renamed to `public` after the import. Partition schemas (`lpartition_*`) are left as they are.

### How a PostgreSQL dump is imported

The dump is imported only when the data directory is empty. Gradle prepares the files, and the database container imports them the first time it starts:

1. `importDatabaseDumps` builds the `database` image and creates its container without starting it.

1. It copies the dump into the `dumps` volume, which the container mounts at `/dumps`, and extracts any archive there. It also adds `100_prepare_database_import.sql`, which creates the `cloudsqlsuperuser` role that Cloud SQL dumps grant privileges to. The dumps are not mounted in the image's `/docker-entrypoint-initdb.d`, because the entrypoint would run them in name order, and an extracted archive can contain file names that sort before this file.

1. The first step that needs the database starts the container and waits until it is healthy, or fails if the container exits.

1. On its first start, the postgres image's entrypoint creates the database and runs `compose-recipes/postgres/conf/import-dumps.sh`, which:

    1. Identifies the files in `/dumps`. A file that `pg_restore --list` can read is a binary dump, whatever its name. Other `.sql`, `.sql.xz` and `.sql.zst` files are SQL dumps. It fails before importing anything if there is more than one binary dump, or if a `.bak`, `.dmp`, `.dump` or `.pg` file is not a valid binary dump (for example, one written by a newer `pg_dump` than the image's).

    1. Runs `100_prepare_database_import.sql`, then all SQL dumps in name order with `psql`, then the binary dump with `pg_restore`. An archive can contain several SQL files, for example a role script next to the database dump.

    1. Renames a non-`public` Liferay schema to `public`.

1. When the container is healthy, Gradle resets user passwords and clears production-only configuration in the imported data.

If the import fails, the container exits and the build fails with the container's log. The partly imported data stays in the database volume, so run `lec clean` to remove the volumes before trying again.

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