## Keep data between restarts

By default, stopping the environment deletes all container data. That guarantees a clean reproduction every start, but loses any changes you made since your last export. To keep data, set this in `gradle-local.properties`:

```properties
lr.docker.environment.clear.volume.data=false
```

This also applies to `restart`, which stops the environment first.

## Export container data

```sh
./gradlew exportContainerData   # or: lec exportData
```

Each running container's data is exported to a timestamped directory under `./exported_data`. Point `lr.docker.environment.data.directory` at it to reuse that data on later startups.

> Container directories are intentionally not bind-mounted to the host; doing so easily breaks startup through user-permission mismatches, a known Docker Compose issue.

## Import container data

Set `lr.docker.environment.data.directory` to a relative or absolute path:

```properties
lr.docker.environment.data.directory=exported_data/data_20241206.175343
```

Each subdirectory maps into its container:

```
data_folder
├── elasticsearch -> /usr/share/elasticsearch/data/
├── liferay       -> /opt/liferay/data
└── mysql         -> /var/lib/mysql
```

## Export Liferay logs

```sh
./gradlew exportLiferayLogs
```

Copies the logs, reports, and routes directories to `./exports/liferay` on the host.

## Share a workspace

```sh
./gradlew shareWorkspace   # or: lec share
```

Zips the workspace as-is, including the declared data folder, into a timestamped file in `./shared_workspaces`. It omits `.gradle`, `.git`, other exported data folders, and earlier shared workspaces.

To use a shared workspace, unzip it, `cd` into it, and run `./gradlew start`.

`lec share` adds export and encryption options; see [lec CLI Reference → Share a workspace](lec-CLI-Reference#share-a-workspace).