# Heart, Saturn, and spiral

Verified 2026-09-08 with seed 73. Three shells are appended at indices 7–9;
the original seven saved indices retain their meanings. The native catalog
supplies preview and plugin selectors, descriptions, capture slugs, and audio
schedules without duplicate QML lists.

The build and all three CTest suites pass. Shape checks cover the heart's notch,
lobes, tip and plane; Saturn's separated planet and planar orbit; and increasing
radius and consistent curvature along the spiral arms. Shared tests cover
determinism, historical colors, golden finishes, bounded particles, cleanup,
and distinct deterministic audio schedules for all ten shells.

Vulkan HDR captures at 1920 × 1080 on Intel Arc B390 were visually inspected
through launch, burst, expansion, and decay for each new shell. Their contact
sheets and transparent frames are under untracked `artifacts/shells/heart/`,
`artifacts/shells/saturn/`, and `artifacts/shells/spiral/`. Each final frame at
11 seconds has zero coverage and vertices. Heart and spiral are intentionally
camera-facing shapes; Saturn has a spherical core and a tilted orbit.

These captures do not measure desktop frame rate or multi-monitor behavior.

The installed bundle was replaced while the shell was stopped, following the
Omarchy desktop workflow, and matches `build/plugin` exactly. The previous
bundle is in `~/.config/omarchy/fireworks-backup.0x6qUU/previous/`.
All three new slugs were launched through installed-shell IPC with sound muted,
waiting 12 seconds after each; the shell answered ping after every run. Settings
were reopened afterward. This checks live invocation and shell responsiveness,
not pointer interaction or audio-device output.
