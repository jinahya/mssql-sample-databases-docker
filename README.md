# mssql-sample-databases-docker

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
- GitHub Container Registry: [`ghcr.io/jinahya/mssql-sample-databases`](https://github.com/jinahya/mssql-sample-databases-docker/pkgs/container/mssql-sample-databases)

## Quick start

```sh
docker run -d --name mssql-samples -p 1433:1433 -e MSSQL_SA_PASSWORD='Passw0rd!' onacit/mssql-sample-databases
# wait until `docker inspect -f '{{.State.Health.Status}}' mssql-samples` says healthy, then
sqlcmd -C -S localhost -U sa -P 'Passw0rd!' -Q 'SELECT count(*) FROM AdventureWorks.Person.Person'
```

`MSSQL_SA_PASSWORD` is required and must meet SQL Server's
[password policy](https://learn.microsoft.com/sql/relational-databases/security/password-policy). `ACCEPT_EULA=Y` is
preset; by running the image you accept the [SQL Server license](https://go.microsoft.com/fwlink/?linkid=857698). The
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

## License

The scripts of this repository are under the [MIT License](https://github.com/jinahya/mssql-sample-databases-docker/blob/main/LICENSE). The sample databases are Microsoft's, under the
[MIT License](https://github.com/microsoft/sql-server-samples/blob/master/license.txt). SQL Server itself is under
Microsoft's license terms.
