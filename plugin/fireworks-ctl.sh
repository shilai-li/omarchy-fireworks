#!/bin/bash
# Omarchy Fireworks settings helper. Runs ONLY when a hotkey is recorded or
# cleared in the Fireworks settings card — never on its own initiative.
#
#   fireworks-ctl.sh bind "SUPER + ALT + F"   manage the Fireworks hotkey as a
#                                             marked block in
#                                             ~/.config/hypr/bindings.lua
#                                             (replaces only its own block,
#                                             never other lines)
#   fireworks-ctl.sh unbind                   remove that block
#
# The marked-block approach — resolve the config, refuse anything that is not
# the file we expect, rewrite only our own block, swap it in atomically — is
# taken from Omafetti's omafetti-ctl.sh (MIT), which solved this first.
set -euo pipefail

ID="shilai_li.fireworks"
BIND_FILE="$HOME/.config/hypr/bindings.lua"
MARK_IN="-- >>> fireworks hotkey (managed by Omarchy Fireworks settings — change it there)"
MARK_OUT="-- <<< fireworks hotkey"
MARK_IN_KEY=">>> fireworks hotkey"
MARK_OUT_KEY="<<< fireworks hotkey"

# bindings.lua is a page of Lua. Anything far larger is not that file, and it
# is about to be read into a pipeline and rewritten — so the size is checked
# before a single byte is read.
MAX_BIND_FILE=$((1024 * 1024))

# This value is written into bindings.lua as Lua source, so its shape is
# checked here as well as in the settings card: modifiers, then exactly one
# key. Anything else is refused rather than escaped, because there is no
# reason for it to exist. The separator is a literal space — [[:space:]] would
# also match a newline, which would close the Lua string early.
HOTKEY_RE='^(SUPER|CTRL|ALT|SHIFT)( \+ (SUPER|CTRL|ALT|SHIFT))* \+ ([A-Z0-9]|F([1-9]|1[0-2])|SPACE|RETURN|ENTER|TAB|ESCAPE|BACKSPACE|DELETE|INSERT|HOME|END|PAGE_UP|PAGE_DOWN|UP|DOWN|LEFT|RIGHT|COMMA|PERIOD|SLASH|MINUS|EQUAL|SEMICOLON|APOSTROPHE|GRAVE|BRACKETLEFT|BRACKETRIGHT|BACKSLASH)$'

# A user config may legitimately be a symlink into a dotfiles repo — stow and
# chezmoi both work that way. Refusing every symlink locks those users out,
# and renaming over the link would replace their managed link with a plain
# file, orphaning the repo copy so their later edits never reach Hyprland.
# Resolve it instead, and write to the target once the target and its
# directory are confirmed to be ours and writable by nobody else.
resolve_config() {
  local p="$1" real dir
  real=$(realpath -e -- "$p" 2>/dev/null) || return 1
  [[ -f $real ]] || return 1
  [[ -O $real ]] || return 1
  dir=$(dirname -- "$real")
  [[ -d $dir && -O $dir ]] || return 1
  [[ -z $(find "$dir" -maxdepth 0 -perm /022 2>/dev/null) ]] || return 1
  printf '%s' "$real"
}

check_size() {
  local f="$1" sz
  sz=$(stat -c %s -- "$f" 2>/dev/null || echo 0)
  if [[ $sz -gt $MAX_BIND_FILE ]]; then
    echo "fireworks-ctl: refusing to edit $f — $sz bytes is not a bindings file." >&2
    return 1
  fi
}

# The awk below clears its skip state on the closing marker, so an opening
# marker with no closer would run to end of file and swallow every line after
# it. A block that is not exactly one properly ordered pair means something
# else has edited the file, and the only safe answer is to leave it alone and
# say so.
assert_balanced() {
  local f="$1" opens closes o c
  opens=$(grep -c -F -- "$MARK_IN_KEY" "$f" 2>/dev/null || true)
  closes=$(grep -c -F -- "$MARK_OUT_KEY" "$f" 2>/dev/null || true)
  opens=${opens:-0}
  closes=${closes:-0}
  [[ $opens -eq 0 && $closes -eq 0 ]] && return 0
  if [[ $opens -ne 1 || $closes -ne 1 ]]; then
    echo "fireworks-ctl: refusing to edit $f — expected one marked block, found $opens opening and $closes closing markers. Repair or remove the block by hand." >&2
    return 1
  fi
  o=$(grep -n -F -- "$MARK_IN_KEY" "$f" | head -1 | cut -d: -f1)
  c=$(grep -n -F -- "$MARK_OUT_KEY" "$f" | head -1 | cut -d: -f1)
  if [[ $o -ge $c ]]; then
    echo "fireworks-ctl: refusing to edit $f — the closing marker is above the opening marker." >&2
    return 1
  fi
}

# Print bindings.lua without our marked block, and without the blank line
# written above it. That blank is ours, so it comes out with the block:
# stripping only the marked lines leaves one behind on every re-bind, and
# three hotkey changes would mean three orphan blank lines in a file this
# plugin promises to leave otherwise untouched. Blank lines the user has of
# their own are held and re-emitted; exactly one, immediately above the
# opening marker, is dropped.
strip_block() {
  awk '
    function flush(  i) { for (i = 0; i < pending; i++) print ""; pending = 0 }
    index($0, ">>> fireworks hotkey") { if (pending > 0) pending--; flush(); skip = 1; next }
    index($0, "<<< fireworks hotkey") { skip = 0; next }
    skip { next }
    $0 == "" { pending++; next }
    { flush(); print }
    END { flush() }
  ' "$1"
}

# Staged beside the resolved target under a random name mktemp creates
# exclusively, then renamed over it — so the swap is one atomic step, nothing
# can have been planted at the staging path, and a managed symlink keeps
# pointing where it pointed. Staging in the target's own directory keeps the
# rename on one filesystem; mktemp in /tmp plus mv degrades to a copy, which
# can leave a half-written config behind if it is interrupted.
replace_config() {
  local real="$1" tmp
  tmp=$(mktemp "$real.XXXXXXXX")
  trap 'rm -f "$tmp"' EXIT
  cat > "$tmp"
  chmod --reference="$real" "$tmp" 2>/dev/null || chmod 644 "$tmp"
  mv -f "$tmp" "$real"
  trap - EXIT
}

case "${1-}" in
  bind)
    key="${2-}"
    [[ -n $key ]] || exit 1
    if [[ ${#key} -gt 40 ]] || ! [[ $key =~ $HOTKEY_RE ]]; then
      echo "fireworks-ctl: refusing hotkey that is not modifiers plus one key: $key" >&2
      exit 1
    fi
    real=$(resolve_config "$BIND_FILE") || {
      echo "fireworks-ctl: refusing to edit $BIND_FILE — not a regular file we own in a directory only we can write." >&2
      exit 1
    }
    check_size "$real"
    assert_balanced "$real"
    {
      strip_block "$real"
      echo ""
      echo "$MARK_IN"
      printf 'o.bind("%s", "Fireworks (launch a shell)", "omarchy-shell shell summon %s")\n' "$key" "$ID"
      echo "$MARK_OUT"
    } | replace_config "$real"
    hyprctl reload >/dev/null 2>&1 || true
    ;;
  unbind)
    real=$(resolve_config "$BIND_FILE") || exit 0
    check_size "$real"
    assert_balanced "$real"
    strip_block "$real" | replace_config "$real"
    hyprctl reload >/dev/null 2>&1 || true
    ;;
  *)
    echo "usage: fireworks-ctl.sh bind <keys> | unbind" >&2
    exit 2
    ;;
esac
