#!/usr/bin/env bash
# Usage: scripts/fetch.sh <database> <version>
# Downloads the files of one image, as listed in versions.json, into ./downloads/files (skipped when present) and
# verifies each one's sha256. Then stages them for the Dockerfile in ./downloads/image, replacing what was there,
# together with Microsoft's license and the database.env the loader reads.
set -Eeuo pipefail
cd "$(dirname "$0")/.."

database=${1:?database, e.g. adventureworks}
version=${2:?SQL Server version, e.g. 2025}

actual() { (shasum -a 256 "$1" 2>/dev/null || sha256sum "$1") | cut -d' ' -f1; }

# get <url> <sha256> <file>: downloads into ./downloads/files/<file> unless present and verified
get() {
  local path=downloads/files/$3
  if [ -f "$path" ] && [ "$(actual "$path")" = "$2" ]; then
    echo "fetch: ${path} present and verified"
    return
  fi
  echo "fetch: downloading $1"
  mkdir -p downloads/files
  curl -fsSL --retry 5 --retry-delay 10 -o "${path}.part" "$1"
  mv "${path}.part" "$path"
  [ "$(actual "$path")" = "$2" ] || { echo "fetch: sha256 mismatch for ${path}" >&2; exit 1; }
  echo "fetch: ${path} verified"
}

# name <database name> <create>, license <url> <sha256>, then file <url> <sha256> for each file in load order
plan=$(python3 -I - "$database" "$version" <<'EOF'
import json, sys
database, version = sys.argv[1:]
v = json.load(open("versions.json"))
if version not in v["versions"]:
    sys.exit(f"fetch: unknown version {version}; one of {' '.join(v['versions'])}")
if database not in v["databases"]:
    sys.exit(f"fetch: unknown database {database}; one of {' '.join(v['databases'])}")
d = v["databases"][database]
print("name", d["name"], int(d.get("create", False)))
print("license", v["license"]["url"], v["license"]["sha256"])
for f in d["files"].get(version) or d["files"]["*"]:
    print("file", f["url"], f["sha256"])
EOF
)

rm -rf downloads/image
mkdir -p downloads/image/files
files=()
while read -r kind a b; do
  case $kind in
    name)    name=$a create=$b ;;
    license) get "$a" "$b" sql-server-samples-license.txt
             ln -f downloads/files/sql-server-samples-license.txt downloads/image/LICENSE ;;
    file)    get "$a" "$b" "${a##*/}"
             ln -f "downloads/files/${a##*/}" "downloads/image/files/${a##*/}"
             files+=("${a##*/}") ;;
  esac
done <<< "$plan"

printf 'SAMPLE_DATABASE_NAME=%s\nSAMPLE_DATABASE_FILES="%s"\nSAMPLE_DATABASE_CREATE=%s\n' \
  "$name" "${files[*]}" "$create" > downloads/image/database.env
echo "fetch: staged ${name} for SQL Server ${version} in downloads/image"
