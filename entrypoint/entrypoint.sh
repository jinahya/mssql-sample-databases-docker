#!/usr/bin/env bash
# Starts the loader in the background, then hands the process over to the official launcher, so SQL Server stays
# PID 1 and receives the container's signals as it does in the official image.
set -Eeuo pipefail

/opt/sample-databases/load.sh &

exec /opt/mssql/bin/launch_sqlservr.sh "$@"
