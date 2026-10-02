#!/bin/bash
set -euo pipefail
plugin_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
mode=${1-source}
case "$mode" in source|prebuilt) ;; *) echo 'Choose source or prebuilt.' >&2; exit 2 ;; esac

# Omarchy's presentation launcher takes a shell command string. Quote every
# argument before handing it off, including plugin paths containing spaces.
trusted() { PATH=/usr/share/omarchy/bin:/usr/bin:/bin command -v -- "$1"; }
presenter=$(trusted omarchy-launch-floating-terminal-with-presentation) || presenter=""
if [[ -n $presenter ]]; then
  printf -v setup_command '%q ' /usr/bin/bash "$plugin_dir/fireworks-build.sh" --terminal "$mode"
  exec "$presenter" "$setup_command"
fi
terminal=$(trusted xdg-terminal-exec) || {
  echo 'No terminal launcher found. Install xdg-terminal-exec.' >&2
  exit 1
}
exec /usr/bin/setsid "$terminal" /usr/bin/bash "$plugin_dir/fireworks-build.sh" --terminal "$mode"
