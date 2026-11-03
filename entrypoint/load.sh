#!/usr/bin/env bash
# Loads the image's sample database into the running server once: restores it from its backup, or runs its scripts in
# order. database.env, written by scripts/fetch.sh, names the database and its files. Started in the background by
# entrypoint.sh. On success it writes the marker the health check looks for; on failure it stops the server, so the
# container exits instead of hanging.
set -Eeuo pipefail

home=/opt/sample-databases
data=/var/opt/mssql/data
marker=/var/opt/mssql/.sample-databases-loaded
timeout=${SAMPLE_DATABASES_STARTUP_TIMEOUT:-300}

# SAMPLE_DATABASE_NAME, SAMPLE_DATABASE_FILES (in load order), SAMPLE_DATABASE_CREATE (1: the scripts expect the
# database to exist)
. "${home}/database.env"
name=$SAMPLE_DATABASE_NAME

log() { echo "sample-databases: $*"; }

# 2017 has only the old tools, which do not know -C (trust the server certificate)
if [ -x /opt/mssql-tools18/bin/sqlcmd ]; then
  sqlcmd() { /opt/mssql-tools18/bin/sqlcmd -C -S localhost -U sa -P "$MSSQL_SA_PASSWORD" -b -I "$@"; }
else
  sqlcmd() { /opt/mssql-tools/bin/sqlcmd -S localhost -U sa -P "$MSSQL_SA_PASSWORD" -b -I "$@"; }
fi

fail() {
  log "load failed: $*" >&2
  pkill -TERM -x sqlservr 2>/dev/null || kill -TERM 1 || true
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

read -r -a files <<< "$SAMPLE_DATABASE_FILES"
if [[ ${files[0]} == *.bak ]]; then
  backup=${home}/files/${files[0]}
  # Moves every file of the backup into the data directory: the first data file to <name>.mdf, further data files to
  # <name>_<logical name>.ndf, the log to <name>_log.ldf
  moves=$(sqlcmd -h -1 -W -s '|' -Q "SET NOCOUNT ON; RESTORE FILELISTONLY FROM DISK = N'${backup}'" | tr -d '\r' \
    | awk -F '|' -v d="${data}/${name}" 'NF > 3 {
        if ($3 == "L") path = d "_log.ldf"; else if (++n == 1) path = d ".mdf"; else path = d "_" $1 ".ndf"
        printf ", MOVE N'\''%s'\'' TO N'\''%s'\''", $1, path }')
  [ -n "$moves" ] || fail "RESTORE FILELISTONLY listed no files"
  log "restoring ${name} from ${files[0]}"
  sqlcmd -Q "RESTORE DATABASE [${name}] FROM DISK = N'${backup}' WITH REPLACE${moves}" >/dev/null
else
  database=()
  if [ "${SAMPLE_DATABASE_CREATE:-0}" = 1 ]; then
    log "creating ${name}"
    sqlcmd -Q "IF DB_ID(N'${name}') IS NULL CREATE DATABASE [${name}]"
    database=(-d "$name")
  fi
  for f in "${files[@]}"; do
    log "loading ${name}: ${f}"
    sqlcmd "${database[@]}" -i "${home}/files/${f}" >/dev/null
  done
fi

touch "$marker"
log "loaded ${name}"
