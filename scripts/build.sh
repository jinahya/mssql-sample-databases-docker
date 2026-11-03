#!/usr/bin/env bash
# Usage: scripts/build.sh <database> <version>
# Fetches the files of one image, builds it as sql-server-samples:<database>-<version> on the version's base image
# from versions.json, and smoke-tests it.
set -Eeuo pipefail
cd "$(dirname "$0")/.."

database=${1:?database, e.g. adventureworks}
version=${2:?SQL Server version, e.g. 2025}

scripts/fetch.sh "$database" "$version"
base=$(python3 -I -c 'import json,sys;print(json.load(open("versions.json"))["versions"][sys.argv[1]])' "$version")
image=$(python3 -I -c 'import json;print(json.load(open("versions.json"))["image"])')
docker build --platform linux/amd64 --build-arg BASE_IMAGE="$base" -t "${image}:${database}-${version}" .
scripts/smoke-test.sh "${image}:${database}-${version}"
