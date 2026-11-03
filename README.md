# sql-server-samples-docker

Docker images of the official [SQL Server](https://mcr.microsoft.com/product/mssql/server/about) image, one per
SQL Server version and Microsoft
[sample database](https://github.com/microsoft/sql-server-samples/tree/master/samples/databases), with the database
loaded on first start. Tags are `<database>-<version>`:

| database | 2017 | 2019 | 2022 | 2025 | what |
|---|---|---|---|---|---|
| `AdventureWorks` | `adventureworks-2017` | `adventureworks-2019` | `adventureworks-2022` | `adventureworks-2025` | the classic OLTP sample: 71 tables in 6 schemas |
| `AdventureWorksDW` | `adventureworks-dw-2017` | `adventureworks-dw-2019` | `adventureworks-dw-2022` | `adventureworks-dw-2025` | its data warehouse: 31 tables |
| `AdventureWorksLT` | `adventureworks-lt-2017` | `adventureworks-lt-2019` | `adventureworks-lt-2022` | `adventureworks-lt-2025` | its lightweight version: 12 tables |
| `WideWorldImporters` | `wideworldimporters-2017` | `wideworldimporters-2019` | `wideworldimporters-2022` | `wideworldimporters-2025` | the SQL Server 2016+ sample: 48 tables, sequences, temporal tables |
| `WideWorldImportersDW` | `wideworldimporters-dw-2017` | `wideworldimporters-dw-2019` | `wideworldimporters-dw-2022` | `wideworldimporters-dw-2025` | its data warehouse: 29 tables |
| `Northwind` | `northwind-2017` | `northwind-2019` | `northwind-2022` | `northwind-2025` | the SQL Server 2000 sample: 13 tables |
| `pubs` | `pubs-2017` | `pubs-2019` | `pubs-2022` | `pubs-2025` | the SQL Server 2000 sample: 11 tables |
| `FutonManufacturing` | `futon-manufacturing-2017` | `futon-manufacturing-2019` | `futon-manufacturing-2022` | `futon-manufacturing-2025` | a multi-level bill of materials, inventory, production and sales: 32 tables, 40 views |

Images are published to:

- Docker Hub: [`jinahya/sql-server-samples`](https://hub.docker.com/r/jinahya/sql-server-samples)
- GitHub Container Registry: [`ghcr.io/jinahya/sql-server-samples`](https://github.com/jinahya/sql-server-samples-docker/pkgs/container/sql-server-samples)

They replace `onacit/mssql-sample-databases`, which held AdventureWorks, WideWorldImporters and FutonManufacturing in
one SQL Server 2025 image and is no longer updated.

## Quick start

```sh
docker run -d --name adventureworks -p 1433:1433 -e ACCEPT_EULA=Y -e MSSQL_SA_PASSWORD='Passw0rd!' \
  jinahya/sql-server-samples:adventureworks-2025
# wait until `docker inspect -f '{{.State.Health.Status}}' adventureworks` says healthy, then
sqlcmd -C -S localhost -U sa -P 'Passw0rd!' -Q 'SELECT count(*) FROM AdventureWorks.Person.Person'
```

`ACCEPT_EULA=Y` is required, as in the official image; setting it accepts the
[SQL Server license](https://go.microsoft.com/fwlink/?linkid=857698), and without it SQL Server exits at start.
`MSSQL_SA_PASSWORD` is required and must meet SQL Server's
[password policy](https://learn.microsoft.com/sql/relational-databases/security/password-policy). The
edition is Developer (`MSSQL_PID=developer`), free for development and testing only. Everything else behaves exactly
like the official image.

A JDBC URL for the database:

```
jdbc:sqlserver://localhost:1433;databaseName=AdventureWorks;encrypt=true;trustServerCertificate=true
```

## Tags

| tag | meaning |
|---|---|
| `<database>-<version>`, such as `adventureworks-2025` | built on `mcr.microsoft.com/mssql/server:<version>-latest`, rebuilt weekly |
| `<database>-<build>`, such as `adventureworks-17.0.5035.5` | the SQL Server build of the base image; pin this for an image that never changes |

The versions are the ones Microsoft still supports: 2017 (extended support until October 2027), 2019 (extended), 2022
and 2025 (mainstream). Images are `linux/amd64` only, as SQL Server is. On Apple silicon they run under Rosetta; turn
on *Use Rosetta for x86_64/amd64 emulation* in Docker Desktop and pass `--platform linux/amd64`.

## How it works

Each image adds one database's backup or scripts and a small entrypoint to the official image. The entrypoint starts a
loader in the background and hands over to the official image's own entrypoint. On the first start of an empty data
directory the loader waits for the server, restores the backup or runs the scripts, and writes
`/var/opt/mssql/.sample-databases-loaded`. The container reports healthy only after that file exists, which takes
under a minute. Later starts skip the load, so keep `/var/opt/mssql` in a volume to avoid reloading. If the load
fails, the loader stops the server and the container exits; the next start loads again.

What each database is loaded from:

| database | 2017 | 2019 | 2022 | 2025 |
|---|---|---|---|---|
| `AdventureWorks` | `AdventureWorks2017.bak` | `AdventureWorks2019.bak` | `AdventureWorks2022.bak` | `AdventureWorks2025.bak` |
| `AdventureWorksDW` | `AdventureWorksDW2017.bak` | `AdventureWorksDW2019.bak` | `AdventureWorksDW2022.bak` | `AdventureWorksDW2025.bak` |
| `AdventureWorksLT` | `AdventureWorksLT2017.bak` | `AdventureWorksLT2019.bak` | `AdventureWorksLT2022.bak` | `AdventureWorksLT2025.bak` |
| `WideWorldImporters` | `WideWorldImporters-Standard.bak` | same | same | same |
| `WideWorldImportersDW` | `WideWorldImportersDW-Standard.bak` | same | same | same |
| `Northwind` | `instnwnd.sql` | same | same | same |
| `pubs` | `instpubs.sql` | same | same | same |
| `FutonManufacturing` | `futon-manufacturing/*.sql` `01`, `02`, `03`, `05`, `06`, `07` | same | same | same |

- AdventureWorks, DW and LT have one backup per version, which keeps that version's compatibility level, except
  `AdventureWorksLT2017.bak`, which keeps 110 (SQL Server 2012). The 2025 backups also enable Query Store, accelerated
  database recovery and optimized locking, and their dates are adjusted, so their rows differ slightly from the
  earlier ones (`AdventureWorks` 760,167 rows against 760,837).
- WideWorldImporters and DW have one backup for every version, which stays at compatibility level 130 (SQL Server
  2016). They come from the Standard backups, which have no memory-optimized tables: the Full backups'
  memory-optimized tables crash SQL Server now and then under Rosetta, on restore and on later starts alike. The
  Standard backups have the same data, temporal tables and sequences.
- `instnwnd.sql` does not create its database, so the loader creates `Northwind` first; `instpubs.sql` creates `pubs`
  itself. Both create the database at the server's compatibility level.
- FutonManufacturing's `04` and `08` hold sample queries only.
- Some tables are empty in the samples themselves, most of all in `WideWorldImportersDW` (13 of 29).

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
scripts/build.sh adventureworks 2025   # fetches, builds sql-server-samples:adventureworks-2025, smoke-tests it
```

`scripts/build.sh` runs `scripts/fetch.sh <database> <version>`, which downloads the files into `./downloads/files`,
verifies each one's sha256 from `versions.json` and stages one image's files in `./downloads/image`; then
`docker build` with the version's base image as `BASE_IMAGE`; then `scripts/smoke-test.sh`, which checks the database
has tables with rows and survives a restart.

## Maintenance

- A new cumulative update of a SQL Server version is picked up by the weekly build.
- A new sample release: update the file's `url` and `sha256` in `versions.json`.
- A new SQL Server version: add it to `versions` in `versions.json`, and its backups to the AdventureWorks entries.

## Which samples

The images cover the samples [microsoft/sql-server-samples](https://github.com/microsoft/sql-server-samples) still
maintains, whether they ship as a release `.bak` or as scripts. Microsoft publishes no maintained/archived status for
them (unlike [Oracle's](https://github.com/oracle-samples/db-sample-schemas)); the verdicts below are inferred from the
last non-bot commit to each `samples/databases` folder and the date of its release asset, as checked on 2026-11-03:

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

Open question: the 2026-07-09 commit fixed the WideWorldImportersDW table scripts, but its backup is from 2016; compare
the restored backup with the scripts before relying on its schema.

## License

The scripts of this repository are under the [MIT License](https://github.com/jinahya/sql-server-samples-docker/blob/main/LICENSE).
The sample databases are Microsoft's, "Copyright (c) Microsoft Corporation", under the
[MIT License](https://github.com/microsoft/sql-server-samples/blob/master/license.txt); each image carries that notice
at `/opt/sample-databases/LICENSE`. SQL Server itself is under Microsoft's
[license terms](https://go.microsoft.com/fwlink/?linkid=857698).
