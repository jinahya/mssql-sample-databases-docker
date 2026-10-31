#!/usr/bin/env bash
# Loads the sample databases into the running server once: restores AdventureWorks and WideWorldImporters from their
# backups and runs the Futon Manufacturing scripts. Started in the background by entrypoint.sh. On success it writes
# the marker the health check looks for; on failure it stops the server, so the container exits instead of hanging.
set -Eeuo pipefail

home=/opt/sample-databases
data=/var/opt/mssql/data
marker=/var/opt/mssql/.sample-databases-loaded
timeout=${SAMPLE_DATABASES_STARTUP_TIMEOUT:-300}

log() { echo "sample-databases: $*"; }

sqlcmd() { /opt/mssql-tools18/bin/sqlcmd -C -S localhost -U sa -P "$MSSQL_SA_PASSWORD" -b -I "$@"; }

fail() {
  log "load failed: $*" >&2
  pkill -TERM -x sqlservr || true
  exit 1
}
trap 'fail "line ${LINENO}"' ERR

if [ -f "$marker" ]; then
  log "already loaded"
  exit 0
fi

if [ -z "${MSSQL_SA_PASSWORD:-}" ]; then
  fail "MSSQL_SA_PASSWORD is not set"
fi

log "waiting for the server (up to ${timeout}s)"
start=$(date +%s)
until sqlcmd -Q "SELECT 1" >/dev/null 2>&1; do
  (( $(date +%s) - start < timeout )) || fail "the server did not accept connections"
  sleep 2
done

log "restoring AdventureWorks"
sqlcmd -Q "RESTORE DATABASE [AdventureWorks] FROM DISK = N'${home}/AdventureWorks2025.bak' WITH REPLACE,
  MOVE N'AdventureWorks' TO N'${data}/AdventureWorks.mdf',
  MOVE N'AdventureWorks_log' TO N'${data}/AdventureWorks_log.ldf'"

# The Standard backup, not the Full one: the Full one's memory-optimized tables crash SQL Server now and then under
# Rosetta, on restore and on later starts alike. The Standard one keeps the temporal tables and the sequences.
log "restoring WideWorldImporters"
sqlcmd -Q "RESTORE DATABASE [WideWorldImporters] FROM DISK = N'${home}/WideWorldImporters-Standard.bak' WITH REPLACE,
  MOVE N'WWI_Primary' TO N'${data}/WideWorldImporters.mdf',
  MOVE N'WWI_UserData' TO N'${data}/WideWorldImporters_UserData.ndf',
  MOVE N'WWI_Log' TO N'${data}/WideWorldImporters.ldf'"

# 04 and 08 hold sample queries only; 01 drops and recreates the database, so a rerun starts clean
for f in 01-schema 02-sample-data 03-manufacturing-reports 05-sales-schema-enhancements 06-sales-sample-data \
         07-sales-reports; do
  log "loading FutonManufacturing: ${f}.sql"
  sqlcmd -i "${home}/futon-manufacturing/${f}.sql" >/dev/null
done

touch "$marker"
log "loaded AdventureWorks, WideWorldImporters, FutonManufacturing"
