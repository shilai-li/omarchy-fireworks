#!/bin/bash
set -euo pipefail
plugin_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
if [[ ${1-} == --terminal ]]; then
  printf 'Fireworks first-time setup\n\n'
  mode=${2-source}
  if [[ $mode == prebuilt ]]; then
    printf 'Installing the prebuilt native module. Compatibility and checksum checks run before installation.\n\n'
  else
    printf 'Required packages:\n  omarchy pkg add cmake ninja gcc qt6-base qt6-declarative qt6-shadertools qt6-multimedia vulkan-headers\n\n'
    printf 'Building from %s\n\n' "$plugin_dir"
  fi
  printf 'The Fireworks plugin is paused during setup to keep library installation from interrupting the shell.\n'
  omarchy plugin disable shilai_li.fireworks
  trap 'omarchy plugin enable shilai_li.fireworks >/dev/null || true' EXIT
  result=0
  if [[ $mode == prebuilt ]]; then
    bash "$plugin_dir/fireworks-prebuilt.sh" || result=$?
  else
    bash "$plugin_dir/fireworks-build.sh" || result=$?
  fi
  if (( result != 0 )); then
    printf '\nSetup failed. Read the error above, then retry or choose Build from source in the Fireworks notice.\n'
  else
    printf '\nRestarting the Omarchy shell to load the new native module…\n'
    omarchy restart shell
  fi
  omarchy plugin enable shilai_li.fireworks
  trap - EXIT
  read -r -p 'Press Enter to close this terminal…' || true
  exit "$result"
fi
if [[ ${1-} == --check ]]; then
  [[ -s "$plugin_dir/native/libfireworks_core.so" && -s "$plugin_dir/native/libfireworksplugin.so" ]]
  if [[ -f "$plugin_dir/native/build-info.json" ]]; then
    [[ $(uname -m) == "$(jq -r .architecture "$plugin_dir/native/build-info.json")" ]]
    while IFS=$'\t' read -r package expected; do
      actual=$(pacman -Q "$package" 2>/dev/null | cut -d ' ' -f 2) || exit 1
      [[ $actual == "$expected" ]] || exit 1
    done < <(jq -r '.qtPackages | to_entries[] | [.key, .value] | @tsv' "$plugin_dir/native/build-info.json")
  fi
  exit
fi
for tool in cmake ninja c++; do
  if ! command -v "$tool" >/dev/null; then
    echo "Missing $tool. Install dependencies with: omarchy pkg add cmake ninja gcc qt6-base qt6-declarative qt6-shadertools qt6-multimedia vulkan-headers" >&2
    exit 1
  fi
done
if [[ ! -f "$plugin_dir/backend/CMakeLists.txt" ]]; then
  echo "Backend source is missing. Reinstall from the complete Fireworks repository." >&2
  exit 1
fi
# Build outside the watched plugin tree so generated files do not repeatedly
# reload the shell and interrupt the setup process.
build_dir=$(mktemp -d "${TMPDIR:-/tmp}/omarchy-fireworks-build.XXXXXX")
trap 'rm -rf -- "$build_dir"' EXIT
cmake -S "$plugin_dir/backend" -B "$build_dir" -G Ninja -DCMAKE_BUILD_TYPE=Release -DBUILD_TESTING=OFF
cmake --build "$build_dir" --target fireworksplugin --parallel 4
mkdir -p "$plugin_dir/native"
cp "$build_dir/libfireworks_core.so" "$plugin_dir/native/.libfireworks_core.so.new"
cp "$build_dir/qml/Omarchy/Fireworks/libfireworksplugin.so" "$plugin_dir/native/.libfireworksplugin.so.new"
mv "$plugin_dir/native/.libfireworks_core.so.new" "$plugin_dir/native/libfireworks_core.so"
mv "$plugin_dir/native/.libfireworksplugin.so.new" "$plugin_dir/native/libfireworksplugin.so"
python - "$plugin_dir/native/build-info.json" <<'PY'
import json, platform, subprocess, sys
packages = dict(line.split() for line in subprocess.check_output(['pacman', '-Q', 'qt6-base', 'qt6-declarative', 'qt6-shadertools', 'qt6-multimedia'], text=True).splitlines())
with open(sys.argv[1], 'w') as output:
    json.dump({'architecture': platform.machine(), 'qtPackages': packages}, output)
PY
echo "Fireworks is ready."
