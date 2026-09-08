# Overlapping desktop launches

The prior styles were committed as `36e7ed5` before this change.

The desktop plugin now uses four fixed launch slots. Each slot owns a native
ShowDirector and its own clock, seed, selected style, resolved launch position,
and audio source. Monitor overlays create a native view for each active slot;
audio sources are shared across monitors. Inactive views are destroyed. The
fifth launch replaces the oldest slot, including its pending start and audio.
Closing the plugin cancels every pending timer and running show.

All four CTest suites pass, including the new overlapping-launch test. It checks
independent clock progress, types, positions, per-launch mute, rapid replacement,
pending-start cancellation, natural completion, and early visibility bindings.
The build succeeds and the plugin bundle validates.

Verified 2026-09-08 on the installed shell, OpenGL / Intel Arc B390,
3072 × 1920, with HDR accumulation. The screenshot at
`artifacts/overlap/screenshot-2026-09-08_06-15-40.png` was visually inspected:
a heart and Saturn are visible at different ages and positions over the desktop.
The shell log records two native renderer initializations one second apart.
Earlier captures exposed stale QML and an early-binding issue; the installed
shell was restarted and the slot-creation notification was fixed before the
successful capture.

Five rapid live summons produced four PipeWire playback streams named
`quickshell`. After 12 seconds, both those streams and the fireworks layer
surfaces were absent, and the shell still answered ping. A separate two-launch
check showed two uncorked, unmuted playback streams. The initial PID-based
stream filter was inconclusive because these PipeWire streams do not expose
an application process ID; the successful check used their media name.

The QML update is installed. The previous Fireworks.qml is backed up in
`~/.config/omarchy/fireworks-backup.3YGzBU/`. No packaged Omarchy files changed.
Four full-screen render targets can cost more GPU time and memory than one;
desktop frame rate and multi-monitor behavior remain unmeasured. Individual
shells retain the existing batched renderer; this does not yet combine all
shells into one shared light-accumulation pass.

Startup follow-up: views now wait for a slot's native clock to be running before
they are created. During the 80 ms layout delay, random placement still has a
provisional position; exposing that time-zero rocket could produce a flash at
the wrong location before launch resolved the final position. The regression
test checks that pending random launches are not render-ready and that the
first visible position is already final. All four suites pass. The fix is
installed; one live summon initialized one OpenGL renderer and cleaned up its
layer. Hyprland reports exactly one Super+Alt+W binding, with repeat disabled.
The previous QML files are backed up in
`~/.config/omarchy/fireworks-backup.n0EyCv/`.
