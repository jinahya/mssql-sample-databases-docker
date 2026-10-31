#!/usr/bin/env bash
# Usage: scripts/fetch.sh
# Downloads every file listed in versions.json into ./downloads (skipped when present) and verifies its sha256.
set -Eeuo pipefail
cd "$(dirname "$0")/.."

actual() { (shasum -a 256 "$1" 2>/dev/null || sha256sum "$1") | cut -d' ' -f1; }

python3 -I -c '
import json
for f in json.load(open("versions.json"))["files"]:
    print(f["path"], f["url"], f["sha256"])
' | while read -r path url sha; do
  if [ -f "$path" ] && [ "$(actual "$path")" = "$sha" ]; then
    echo "fetch: ${path} present and verified"
    continue
  fi
  echo "fetch: downloading ${url}"
  mkdir -p "$(dirname "$path")"
  curl -fsSL --retry 5 --retry-delay 10 -o "${path}.part" "$url"
  mv "${path}.part" "$path"
  [ "$(actual "$path")" = "$sha" ] || { echo "fetch: sha256 mismatch for ${path}" >&2; exit 1; }
  echo "fetch: ${path} verified"
done
