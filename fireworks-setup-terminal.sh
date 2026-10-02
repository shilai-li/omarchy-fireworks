#!/bin/bash
set -euo pipefail
plugin_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
mode=${1-source}
case "$mode" in source|prebuilt) ;; *) echo 'Choose source or prebuilt.' >&2; exit 2 ;; esac

# Omarchy's presentation launcher takes a shell command string. Quote every
# argument before handing it off, including plugin paths containing spaces.
trusted() { PATH=/usr/share/omarchy/bin:/usr/bin:/bin command -v -- "$1"; }
before=""
if command -v hyprctl >/dev/null && command -v jq >/dev/null; then
  before=$(hyprctl clients -j | jq -c '[.[].address]') || before=""
fi

position_terminal() {
  [[ -n $before ]] || return 0
  for ((attempt = 0; attempt < 40; attempt++)); do
    window=$(hyprctl clients -j | jq -r --argjson before "$before" '
      [.[] | select(.class == "org.omarchy.terminal")
       | select(.address as $address | $before | index($address) | not)]
      | if length == 1 then .[0] | [.address, .monitor] | @tsv else empty end') || return 0
    if [[ -n $window ]]; then
      IFS=$'\t' read -r address monitor <<< "$window"
      geometry=$(hyprctl monitors -j | jq -r --argjson monitor "$monitor" '
        .[] | select(.id == $monitor)
        | . as $m
        | ((if .transform % 2 == 1 then .height else .width end) / .scale | floor) as $screenW
        | ((if .transform % 2 == 1 then .width else .height end) / .scale | floor) as $screenH
        | ([$screenW - 48, 875] | min) as $w
        | ([$screenH - 48, 600] | min) as $h
        | [$w, $h, ($m.x + ($screenW - $w) / 2 | floor), ($m.y + ($screenH - $h) / 2 | floor)] | @tsv') || return 0
      IFS=$'\t' read -r width height x y <<< "$geometry"
      [[ -n $width && -n $height ]] || return 0
      hyprctl dispatch setfloating "address:$address" >/dev/null || return 0
      hyprctl dispatch resizewindowpixel "exact $width $height,address:$address" >/dev/null || return 0
      hyprctl dispatch movewindowpixel "exact $x $y,address:$address" >/dev/null || return 0
      return 0
    fi
    sleep 0.1
  done
}

presenter=$(trusted omarchy-launch-floating-terminal-with-presentation) || presenter=""
if [[ -n $presenter ]]; then
  printf -v setup_command '%q ' /usr/bin/bash "$plugin_dir/fireworks-build.sh" --terminal "$mode"
  "$presenter" "$setup_command" &
else
  terminal=$(trusted xdg-terminal-exec) || {
    echo 'No terminal launcher found. Install xdg-terminal-exec.' >&2
    exit 1
  }
  /usr/bin/setsid "$terminal" --app-id=org.omarchy.terminal --title=Fireworks /usr/bin/bash "$plugin_dir/fireworks-build.sh" --terminal "$mode" &
fi
launcher_pid=$!
position_terminal
wait "$launcher_pid"
