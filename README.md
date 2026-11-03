# sql-server-samples-docker

Docker images of the official [SQL Server](https://mcr.microsoft.com/product/mssql/server/about) image with three of
Microsoft's [sample databases](https://github.com/microsoft/sql-server-samples/tree/master/samples/databases) loaded on
first start:

| database | source | what |
|---|---|---|
| `AdventureWorks` | [`AdventureWorks2025.bak`](https://github.com/microsoft/sql-server-samples/releases/tag/adventureworks) | the classic OLTP sample: 71 tables in 6 schemas |
| `WideWorldImporters` | [`WideWorldImporters-Standard.bak`](https://github.com/microsoft/sql-server-samples/releases/tag/wide-world-importers-v1.0) | the SQL Server 2016+ sample: 26 sequences, 17 temporal tables |
| `FutonManufacturing` | [`futon-manufacturing/*.sql`](https://github.com/microsoft/sql-server-samples/tree/master/samples/databases/futon-manufacturing) | a multi-level bill of materials, inventory, production and sales: 32 tables, 40 views |

Images are published to:

- Docker Hub: [`onacit/mssql-sample-databases`](https://hub.docker.com/r/onacit/mssql-sample-databases)
- GitHub Container Registry: [`ghcr.io/jinahya/mssql-sample-databases`](https://github.com/jinahya/sql-server-samples-docker/pkgs/container/mssql-sample-databases)

## Quick start

```sh
docker run -d --name mssql-samples -p 1433:1433 -e ACCEPT_EULA=Y -e MSSQL_SA_PASSWORD='Passw0rd!' onacit/mssql-sample-databases
# wait until `docker inspect -f '{{.State.Health.Status}}' mssql-samples` says healthy, then
sqlcmd -C -S localhost -U sa -P 'Passw0rd!' -Q 'SELECT count(*) FROM AdventureWorks.Person.Person'
```

`ACCEPT_EULA=Y` is required, as in the official image; setting it accepts the
[SQL Server license](https://go.microsoft.com/fwlink/?linkid=857698), and without it SQL Server exits at start.
`MSSQL_SA_PASSWORD` is required and must meet SQL Server's
[password policy](https://learn.microsoft.com/sql/relational-databases/security/password-policy). The
edition is Developer (`MSSQL_PID=developer`), free for development and testing only. Everything else behaves exactly
like the official image.

A JDBC URL for one of the databases:

```
jdbc:sqlserver://localhost:1433;databaseName=AdventureWorks;encrypt=true;trustServerCertificate=true
```

## Tags

| tag | meaning |
|---|---|
| `latest`, `2025-latest` | built on `mcr.microsoft.com/mssql/server:2025-latest`, rebuilt weekly |
| `17.0.5035.5`, ... | the SQL Server build of the base image; pin this for an image that never changes |

Images are `linux/amd64` only, as SQL Server is. On Apple silicon they run under Rosetta; turn on *Use Rosetta for
x86_64/amd64 emulation* in Docker Desktop and pass `--platform linux/amd64`.

## How it works

The image adds the two backups, the Futon Manufacturing scripts and a small entrypoint to the official image. The
entrypoint starts a loader in the background and hands over to the official launcher, so SQL Server stays PID 1. On the
first start of an empty data directory the loader waits for the server, restores `AdventureWorks` and
`WideWorldImporters`, runs the Futon Manufacturing scripts `01`, `02`, `03`, `05`, `06` and `07` (`04` and `08` hold
sample queries only), and writes `/var/opt/mssql/.sample-databases-loaded`. The container reports healthy only after
that file exists, which takes under a minute. Later starts skip the load, so keep `/var/opt/mssql` in a volume to avoid
reloading. If the load fails, the loader stops the server and the container exits; the next start loads again.

`WideWorldImporters` comes from the Standard backup, which has no memory-optimized tables. The Full backup's
memory-optimized tables crash SQL Server now and then under Rosetta, on restore and on later starts alike; the Standard
backup has the same data, temporal tables and sequences.

Full-text search is not installed, as in the official image. `AdventureWorks` keeps its full-text catalog, but queries
that use `CONTAINS` or `FREETEXT`, such as `dbo.uspSearchCandidateResumes`, fail.

## Environment

| variable | default | description |
|---|---|---|
| `ACCEPT_EULA` | (none) | `Y` accepts the [SQL Server license](https://go.microsoft.com/fwlink/?linkid=857698); required |
| `MSSQL_SA_PASSWORD` | (none) | the `sa` password; required |
| `SAMPLE_DATABASES_STARTUP_TIMEOUT` | `300` | seconds the loader waits for the server to accept connections |

All variables of the official image apply as well.

## Building locally

```sh
scripts/fetch.sh                  # downloads ./downloads/* and verifies each file's sha256 from versions.json
docker build --platform linux/amd64 -t mssql-sample-databases .
scripts/smoke-test.sh mssql-sample-databases
```

## Maintenance

- A new cumulative update of SQL Server 2025 is picked up by the weekly build.
- A new sample release: update the file's `url` and `sha256` in `versions.json`, and the restore's logical file names in
  `entrypoint/load.sh` if they changed (`RESTORE FILELISTONLY` lists them).

## Roadmap

Planned, not built yet: one image per database and SQL Server version, tagged `sql-server-samples:<db>-<version>`,
with no combined image. A database gets images when
[microsoft/sql-server-samples](https://github.com/microsoft/sql-server-samples) still maintains it (not archived nor
abandoned; a change some years ago counts, one decades ago does not), whether it ships as a release `.bak` or as
scripts.

Microsoft publishes no maintained/archived status for these samples (unlike
[Oracle's](https://github.com/oracle-samples/db-sample-schemas)); the verdicts below are inferred from the last non-bot
commit to each `samples/databases` folder and the date of its release asset, as checked on 2026-11-03:

| database | last change | source | verdict |
|---|---|---|---|
| `AdventureWorks` | 2025-11-14 | `AdventureWorks2025.bak`, 2025-11-18 | maintained |
| `AdventureWorksDW` | 2025-11-14 | `AdventureWorksDW2025.bak`, 2025-11-18 | maintained |
| `AdventureWorksLT` | 2025-11-14 | `AdventureWorksLT2025.bak`, 2025-11-18 | maintained |
| `FutonManufacturing` | 2026-10-06 | `futon-manufacturing/*.sql` | maintained |
| `WideWorldImporters` | 2026-07-09 | `WideWorldImporters-Standard.bak`, 2022-10-07 | maintained |
| `WideWorldImportersDW` | 2026-07-09 | `WideWorldImportersDW-Standard.bak`, 2016-06-08 | maintained; backup is old |
| `Northwind` | 2024-06-27 | `instnwnd.sql` | maintained |
| `pubs` | 2024-06-27 | `instpubs.sql` | maintained |
| Contoso data warehouse | 2023-02-20 | load scripts for Azure SQL Data Warehouse | out: nothing runs in SQL Server |

Out of scope: the superseded `adventureworks2008r2`, `adventureworks2012` and `wide-world-importers-v0.x` releases, the
`.bacpac` files, the 2016 `_EXT` and the Full (memory-optimized) variants, the Analysis Services models, and the
`in-memory-oltp-demo`, `iot-smart-grid` and `wwi-sales-orders` demos.

SQL Server versions are the ones Microsoft still supports, from
[`mcr.microsoft.com/mssql/server`](https://mcr.microsoft.com/product/mssql/server/about) (`linux/amd64` only):

| version | newest CU (2026-11-03) | base OS | support |
|---|---|---|---|
| 2017 | CU31 | Ubuntu 16.04 / 18.04 | extended, until October 2027 |
| 2019 | CU32 | Ubuntu 16.04 / 18.04 / 20.04 | extended |
| 2022 | CU27 | Ubuntu 20.04 / 22.04 | mainstream |
| 2025 | CU10 | Ubuntu 22.04 / 24.04 | mainstream |

The matrix, 32 images; ✓ marks the cells the current image already loads and smoke-tests:

| database | 2017 | 2019 | 2022 | 2025 |
|---|---|---|---|---|
| `AdventureWorks` | `AdventureWorks2017.bak` | `AdventureWorks2019.bak` | `AdventureWorks2022.bak` | `AdventureWorks2025.bak` ✓ |
| `AdventureWorksDW` | `AdventureWorksDW2017.bak` | `AdventureWorksDW2019.bak` | `AdventureWorksDW2022.bak` | `AdventureWorksDW2025.bak` |
| `AdventureWorksLT` | `AdventureWorksLT2017.bak` | `AdventureWorksLT2019.bak` | `AdventureWorksLT2022.bak` | `AdventureWorksLT2025.bak` |
| `WideWorldImporters` | `WideWorldImporters-Standard.bak` | same | same | same ✓ |
| `WideWorldImportersDW` | `WideWorldImportersDW-Standard.bak` | same | same | same |
| `Northwind` | `instnwnd.sql` | same | same | same |
| `pubs` | `instpubs.sql` | same | same | same |
| `FutonManufacturing` | `futon-manufacturing/*.sql` | same | same | same ✓ |

What each sample says it targets:

- AdventureWorks, DW and LT: one backup per version; a backup restores on its version or later and keeps that version's
  compatibility level. The 2025 backup also enables Query Store, accelerated database recovery and optimized locking,
  and its dates are adjusted, so it is not interchangeable with the earlier ones.
- WideWorldImporters and DW: "SQL Server 2016 (or higher)"; one backup for every version, restored at compatibility
  level 130.
- Northwind and pubs: "originally created for SQL Server 2000"; the scripts create the database at the server's level,
  and `instpubs.sql` uses `ALTER DATABASE … SET RECOVERY SIMPLE` instead of `sp_dboption` on SQL Server 2014 and later.
- FutonManufacturing: no version stated.

Every cell was loaded into Microsoft's `<version>-latest` image on Apple silicon (Rosetta) on 2026-11-03, checked, and
restarted with the database online; all 32 pass. Builds: 2017 `14.0.3560.2`, 2019 `15.0.4500.2`, 2022 `16.0.4305.5`,
2025 `17.0.5035.5`. Compatibility level per cell:

| database | 2017 | 2019 | 2022 | 2025 | tables | rows | empty tables |
|---|---|---|---|---|---|---|---|
| `AdventureWorks` | 140 | 150 | 160 | 170 | 71 | 760,837; 760,167 on 2025 | 1 |
| `AdventureWorksDW` | 140 | 150 | 160 | 170 | 31 | 1,060,820; 1,047,563 on 2025 | 0 |
| `AdventureWorksLT` | 110 | 150 | 160 | 170 | 12 | 4,277 | 1 |
| `WideWorldImporters` | 130 | 130 | 130 | 130 | 48 | 4,713,833 | 2 |
| `WideWorldImportersDW` | 130 | 130 | 130 | 130 | 29 | 923,643 | 13 |
| `Northwind` | 140 | 150 | 160 | 170 | 13 | 3,308 | 2 |
| `pubs` | 140 | 150 | 160 | 170 | 11 | 255 | 0 |
| `FutonManufacturing` | 140 | 150 | 160 | 170 | 32 | 355 | 4 |

- `AdventureWorksLT2017.bak` keeps compatibility level 110 (SQL Server 2012), unlike the other 2017 backups.
- `instnwnd.sql` does not create its database ("Run this script in the database you want the objects to be created"),
  so the loader has to create `Northwind` first and run the script in it.
- The empty tables come with the samples; nothing failed to load.

Open question: the 2026-07-09 commit fixed the WideWorldImportersDW table scripts, but its backup is from 2016; compare
the restored backup with the scripts before relying on its schema.

## License

The scripts of this repository are under the [MIT License](https://github.com/jinahya/sql-server-samples-docker/blob/main/LICENSE).
The sample databases are Microsoft's, "Copyright (c) Microsoft Corporation", under the
[MIT License](https://github.com/microsoft/sql-server-samples/blob/master/license.txt); the image carries that notice
at `/opt/sample-databases/LICENSE`. SQL Server itself is under Microsoft's
[license terms](https://go.microsoft.com/fwlink/?linkid=857698).
