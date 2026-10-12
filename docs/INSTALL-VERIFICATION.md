# Installed-shell integration — verification

Verified 2026-09-07 on the running Omarchy shell (`quickshell -n -p
/usr/share/omarchy/shell`, PID 1044296), Qt 6.11.2, Mesa 26.2.1, Intel Arc B390
(PTL), Hyprland/Wayland, 3072×1920. Evidence is untracked under
`artifacts/installed/`.

This is the first verification against the *installed* shell. Earlier milestones
were verified with the standalone preview, the Vulkan capture tool, and a
temporary isolated Quickshell overlay; see
[SHELL-VERIFICATION.md](SHELL-VERIFICATION.md).

## Installation performed

```bash
cmake --build build -j 4
omarchy plugin validate build/plugin           # exit 0
cp -a build/plugin ~/.config/omarchy/plugins/shilai_li.fireworks
omarchy-shell shell rescanPlugins
omarchy plugin enable shilai_li.fireworks
```

`omarchy plugin list` reports `shilai_li.fireworks  enabled  third-party
overlay,bar-widget`. Enabling added `{"id": "shilai_li.fireworks"}` to the right
section of `~/.config/omarchy/shell.json`. No packaged file under
`/usr/share/omarchy/` was modified, and the Omafetti installation is untouched.

## Checks

| Check | Result | Evidence |
|---|---|---|
| Plugin discovered and enabled | pass | `omarchy plugin list` |
| Bundle loads in the live shell | pass, no QML errors | `shell.log`, "Local plugin changed, reloading: shilai_li.fireworks" |
| Native renderer initializes in-shell | pass | `shell.log`: `Fireworks renderer: OpenGL "Intel Mesa Intel(R) Arc(tm) B390 (PTL) 4.6 … Mesa 26.2.1-arch1.1" QSize(3072, 1920) HDR true` |
| Bar widget renders | pass, ✦ icon in the right section | `bar-widget.png` |
| Overlay composites over other applications | pass | `chrysanthemum.png` |
| All four shells run from IPC | pass | `chrysanthemum.png`, `palm.png`, `willow.png`, `prismatic.png` |
| Settings view via `{"view":"settings"}` | pass | `settings.png` |
| Live audio reaches the device | pass | PipeWire sink input, `s16le 2ch 48000Hz`, Corked: no, Mute: no |
| Cleanup after a show | pass | no `omarchy-fireworks` layer surface in `hyprctl layers`; no residual sink input; `after-close.png` |
| Shell stability | pass | same PID before and after, ~56 min uptime, RSS 785 MB with the whole desktop shell loaded |

The renderer reports the shell's OpenGL backend, not the Vulkan path used by the
capture tool. `HDR true` refers to the internal RGBA16F light buffers, not an HDR
desktop output.

Commands exercised:

```bash
omarchy-shell shell summon shilai_li.fireworks '{"shell":"chrysanthemum","muted":true}'
omarchy-shell shell summon shilai_li.fireworks '{"shell":"palm","muted":true}'
omarchy-shell shell summon shilai_li.fireworks '{"shell":"willow","muted":true}'
omarchy-shell shell summon shilai_li.fireworks '{"shell":"prismatic","muted":true}'
omarchy-shell shell summon shilai_li.fireworks '{"view":"settings"}'
omarchy-shell shell call shilai_li.fireworks close ""
```

## Limitations

- Audio was verified as a live, uncorked 48 kHz stereo stream in the expected
  format. Its musical quality and the 120-metre delay were not judged by ear in
  a recorded, repeatable way.
- Recording a hotkey inside the card was driven with a `uinput` keyboard and the
  bar icon with a `uinput` pointer, because `wtype`'s virtual-keyboard input is
  delivered straight to the focused client and never reaches Hyprland's keybind
  matching — Omafetti's own hotkey did not fire from `wtype` either. A kernel
  `uinput` device goes through the compositor's normal path, and did.
- Frame-rate targets on the live desktop are still unmeasured. No GPU or CPU
  frame-time instrumentation was run in the shell process.
- A single monitor was connected. Multi-monitor overlay behavior in the
  installed shell remains unverified.
- Screen lock briefly hides the settings overlay; an initial settings capture
  during a lock/unlock cycle showed nothing. Re-running after unlock succeeded.
  This is a capture artifact, not a plugin defect.
- Native-library updates still require replacing the bundle while the shell is
  stopped; that upgrade path was not exercised here.

## Milestone 2.2 — bar icon opens settings; recordable hotkey

Verified 2026-09-08 on the same machine and shell.

| Check | Result | Evidence |
|---|---|---|
| Bar icon opens the settings card | pass | `uinput` pointer click at the widget's own reported position (`debugBarGeometry`: x 1248, w 23); only the `omarchy-fireworks-settings` layer appeared and the renderer line count did not change |
| Bar icon never launches a show | pass | same run: no `omarchy-fireworks` show layer, no new `Fireworks renderer` line |
| Second click closes the card | pass | no fireworks layer surfaces after the second click |
| Recording captures a real combination | pass | `R` then SUPER+ALT+W through a `uinput` keyboard; the card showed `SUPER + ALT + W` |
| Binding written correctly | pass | marked block in `bindings.lua`; Omafetti's adjacent block untouched |
| Hyprland registers it | pass | `hyprctl binds`: modmask 72, key W |
| Pressing it launches a show | pass | crimson chrysanthemum over the desktop; `Fireworks renderer` line at the keypress |
| Clearing removes everything | pass | block gone, INI key emptied, Hyprland binding gone, file byte-identical to the pre-test backup |
| Refusal is reported honestly | pass | with `bindings.lua` absent, the card showed the script's own message rather than "Bound." |
| `hyprctl reload` does not restart the shell | pass | same shell PID before and after |

Limits specific to this milestone:

- The hotkey validation was exercised against injection-shaped inputs (embedded
  quotes, newlines, shell metacharacters, two keys, no modifier, over-length)
  through the script directly, with the bindings file unchanged after each
  refusal. The QML pattern is the same expression, but was not fuzzed on its own.
- No conflict detection: recording a combination another binding already owns
  writes it anyway, and Hyprland will run whichever binding wins. The card warns
  about this in words only.
- Moving `bindings.lua` out of the way to test the refusal path made Hyprland's
  config watcher reload against a missing file and raise a config-error banner.
  That is an artifact of the test, not of the plugin, and `hyprctl reload`
  cleared it once the file was back.
