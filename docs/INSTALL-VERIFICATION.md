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
- Bar-widget *pointer* behavior (left-click launch, right-click settings) was not
  driven synthetically. The widget is present and its `openSettings`/`launch`
  entry points were exercised through IPC, which is the same code path.
- Frame-rate targets on the live desktop are still unmeasured. No GPU or CPU
  frame-time instrumentation was run in the shell process.
- A single monitor was connected. Multi-monitor overlay behavior in the
  installed shell remains unverified.
- Screen lock briefly hides the settings overlay; an initial settings capture
  during a lock/unlock cycle showed nothing. Re-running after unlock succeeded.
  This is a capture artifact, not a plugin defect.
- Native-library updates still require replacing the bundle while the shell is
  stopped; that upgrade path was not exercised here.
