#!/usr/bin/env bash
# Starts the loader in the background, then hands the process over to the official image's own entrypoint, so SQL
# Server receives the container's signals as it does in the official image. That entrypoint differs by version:
# launch_sqlservr.sh from 2022, permissions_check.sh in 2019, nonroot_msg.sh in 2017.
set -Eeuo pipefail

/opt/sample-databases/load.sh &

for launcher in launch_sqlservr.sh permissions_check.sh nonroot_msg.sh; do
  [ -x "/opt/mssql/bin/${launcher}" ] && exec "/opt/mssql/bin/${launcher}" "$@"
done
exec "$@"
