| Task | What it does |
|:--|:--|
| `./gradlew start` | Start the environment |
| `./gradlew stop` | Stop the environment (deletes data unless [configured otherwise](Saving-and-Sharing-Data#keep-data-between-restarts)) |
| `./gradlew restart` | Stop, then start |
| `./gradlew exportContainerData` | [Export container data](Saving-and-Sharing-Data#export-container-data) to `./exported_data` |
| `./gradlew importDatabaseDumps` | Import dumps from `./dumps` (see [Database Service](Database-Service#import-a-database-dump)) |
| `./gradlew executeSQLQuery -PsqlQuery="..."` | Run a SQL query against the running database |
| `./gradlew shareWorkspace` | [Zip the workspace](Saving-and-Sharing-Data#share-a-workspace) into `./shared_workspaces` |
| `./gradlew exportLiferayLogs` | Copy logs, reports, and routes to `./exports/liferay` |
| `./gradlew printBundleInfo` | Print version and product info for the running bundle |
| `./gradlew listAdminUsers` | List admin users and login URLs for every company |
| `./gradlew buildDockerImage` | Build the custom Liferay image with your configs and modules |
| `./gradlew cleanPrepareHotfixes` | Delete downloaded hotfixes |
| `./gradlew clean` | Delete all prepared data and built Liferay images |

`executeSQLQuery` is meant for tests but works as a general utility.