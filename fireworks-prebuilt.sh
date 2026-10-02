#!/bin/bash
set -euo pipefail
plugin_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
for tool in curl jq pacman sha256sum python; do
  command -v "$tool" >/dev/null || { echo "Missing $tool. Use Build from source or install this tool." >&2; exit 1; }
done
metadata="$plugin_dir/prebuilt.json"
[[ $(uname -s) == Linux && $(uname -m) == "$(jq -r .architecture "$metadata")" ]] || {
  echo 'No compatible prebuilt for this architecture. Use Build from source.' >&2; exit 1;
}
while IFS=$'\t' read -r package expected; do
  actual=$(pacman -Q "$package" 2>/dev/null | cut -d ' ' -f 2) || actual=missing
  if [[ $actual != "$expected" ]]; then
    printf 'Prebuilt requires %s %s; installed: %s. Use Build from source.\n' "$package" "$expected" "$actual" >&2
    exit 1
  fi
done < <(jq -r '.qtPackages | to_entries[] | [.key, .value] | @tsv' "$metadata")
url=$(jq -r .url "$metadata")
[[ $url == https://github.com/shilai-li/omarchy-fireworks/releases/download/* ]] || {
  echo 'Invalid prebuilt release URL.' >&2; exit 1;
}
stage=$(mktemp -d "${TMPDIR:-/tmp}/omarchy-fireworks-prebuilt.XXXXXX")
trap 'rm -rf -- "$stage"' EXIT
echo "Downloading $url"
curl --fail --location --proto '=https' --proto-redir '=https' --connect-timeout 15 --max-time 120 --output "$stage/native.tar.gz" "$url"
printf '%s  %s\n' "$(jq -r .sha256 "$metadata")" "$stage/native.tar.gz" | sha256sum --check --status || {
  echo 'Download checksum mismatch. Nothing was installed.' >&2; exit 1;
}
# Read only known regular files; archive paths and symlinks are never extracted.
python - "$stage" <<'PY'
from pathlib import Path
import sys, tarfile
stage = Path(sys.argv[1])
with tarfile.open(stage / 'native.tar.gz', 'r:gz') as archive:
    for name in ('libfireworks_core.so', 'libfireworksplugin.so', 'qmldir'):
        entry = archive.getmember('native/' + name)
        if not entry.isfile() or entry.size > 64 * 1024 * 1024:
            raise SystemExit('Invalid native archive entry: ' + name)
        (stage / name).write_bytes(archive.extractfile(entry).read())
PY
for library in libfireworks_core.so libfireworksplugin.so; do
  dependencies=$(ldd "$stage/$library" 2>&1) || { echo "$dependencies" >&2; exit 1; }
  if [[ $dependencies == *'not found'* ]]; then
    echo "$dependencies" >&2
    echo 'Runtime dependencies are missing. Use Build from source.' >&2
    exit 1
  fi
done
if [[ ${1-} == --verify ]]; then
  echo 'Prebuilt download, checksum, Qt packages and runtime dependencies verified.'
  exit
fi
mkdir -p "$plugin_dir/native"
for name in libfireworks_core.so libfireworksplugin.so qmldir; do
  install -m 644 "$stage/$name" "$plugin_dir/native/.$name.new"
  mv "$plugin_dir/native/.$name.new" "$plugin_dir/native/$name"
done
install -m 644 "$metadata" "$plugin_dir/native/.build-info.json.new"
mv "$plugin_dir/native/.build-info.json.new" "$plugin_dir/native/build-info.json"
echo 'Prebuilt Fireworks installed. No compiler was needed.'
