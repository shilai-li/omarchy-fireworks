#!/usr/bin/env bash
set -euo pipefail
fireworks_repo=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
cd -- "$fireworks_repo"
fireworks_artifacts=${1:-artifacts}
mkdir -p "$fireworks_artifacts" build/verification-config build/verification-cache
export QT_FORCE_STDERR_LOGGING=1
export XDG_CONFIG_HOME="$fireworks_repo/build/verification-config"
export XDG_CACHE_HOME="$fireworks_repo/build/verification-cache"
./build/omarchy-fireworks --mute --smoke-test --screenshot "$fireworks_artifacts/preview.png" 2>&1 | tee "$fireworks_artifacts/preview.log"
quickshell --no-color --path build/tests/overlay.qml 2>&1 | tee "$fireworks_artifacts/overlay.log"
rg -q 'PASS: overlay launch and cleanup' "$fireworks_artifacts/overlay.log"
rg -q 'Fireworks renderer:' "$fireworks_artifacts/preview.log"
rg -q 'Fireworks renderer:' "$fireworks_artifacts/overlay.log"
test -f "$XDG_CONFIG_HOME/omarchy-fireworks/settings.ini"
if rg -qi '^[[:space:]]*(ERROR|FATAL)([[:space:]]|:)|FAIL:|failed to load|Failed to initialize QSettings|unresolvable import|Cannot load shader|vertex budget exceeded' "$fireworks_artifacts/overlay.log" "$fireworks_artifacts/preview.log"; then
  exit 1
fi
