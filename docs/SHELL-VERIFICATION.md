# Authored shell catalog — verification

Verified 2026-09-07, seed 73, Qt 6.11.2, Mesa 26.2.1, Intel Arc B390 (PTL).
Builds and generated evidence remain untracked under `build/` and `artifacts/`.

## Delivered

| Shell | Simulation | Color design |
|---|---|---|
| Chrysanthemum (default) | 360 stars; fast sphere with a slower inner core and short trails | Crimson outer shell, cyan heart, gold-changing tips |
| Palm | 96 stars grouped into twelve eight-star fronds; lower drag and wider trails | Emerald/cyan fronds, gold finish |
| Willow | 420 stars; long recorded trails and gravity-driven falling branches | Violet/cyan branches transitioning to gold |
| Prismatic | Original 460-star willow retained | Eight stable colors |

Native shell profiles own geometry, drag, lifetime, trails, burn progression,
and crackle timing. Trail points store their emission-time color progression;
changing tips do not recolor old trails. The three new shells emit golden
secondary crackle. Audio tracks use shell-specific crackle windows and counts;
the asynchronous preparation cache now includes both seed and shell.

The preview has a shell selector and shell-specific paused review time. Plugin
settings persist the preferred shell. JSON payloads accept `chrysanthemum`,
`palm`, `willow`, and `prismatic`, overriding the preference for one launch.

## Automated and live checks

- `cmake --build build -j4` succeeds.
- CTest passes **3/3**: engine, authored-shells, native-qml-import.
- Tests cover authored populations and silhouettes, deterministic motion and
  burn progression, preserved trail colors, gold crackle, bounded decay,
  rewind, switching shells, invalid inputs, and deterministic shell audio.
  Existing tests cover stereo audio format, initial delay, and signal headroom.
- `omarchy plugin validate build/plugin` succeeds.
- Vulkan capture succeeds for all four shells at **1920×1080**, with RGBA16F
  accumulation. All 24 sampled phase frames have valid premultiplied alpha.
  Every shell has zero nontransparent pixels and zero vertices at 11 seconds.
- The three authored hero frames each retain at least two saturated hue sectors.
  The retained prismatic hero and falling frames retain all six hue sectors.
- `bash scripts/verify-live.sh artifacts/shells` succeeds. The muted preview
  initializes on OpenGL. A separate Quickshell process selects each new shell
  through its JSON `open()` entry point and verifies cleanup after each launch.
  Its overlay renders at **3072×1920**, OpenGL, HDR buffers enabled, and exits
  after about 35.4 seconds. The existing host portal application-ID warning
  remains; no plugin import, settings initialization, or renderer failures occur.

| Shell | Hero time | Hero vertices | Pixels with alpha > 8/255 |
|---|---:|---:|---:|
| Chrysanthemum | 3.0 s | 98,004 | 113,542 |
| Palm | 3.7 s | 65,448 | 116,654 |
| Willow | 3.7 s | 211,278 | 203,456 |
| Prismatic | 3.7 s | 209,868 | 212,670 |

JSON reports include individual render-and-readback timings. These include GPU
completion and readback, exclude simulation and PNG encoding, and are not
desktop frame-rate benchmarks; the palm capture overlapped the live test.

## Visual review and evidence

Captured 331 frames per new shell at 30 fps through the 11-second cleanup point.
Reviewed phase contact sheets, full-size falling frames, light-background
composition, and one-second samples across each sequence. The palm's upward
velocity was reduced after an initial capture clipped its crown; its trail
history was lengthened to keep the fronds coherent. The willow's gold transition
was moved earlier so it remains visible before the branches fade.
The exported catalog is 33 seconds, 1920×1080 at 30 fps, H.264 video with stereo
AAC audio; container duration and stream formats were checked with `ffprobe`.

- [Three-shell demo](../artifacts/shells/shell-catalog.mp4)
- [Chrysanthemum phases](../artifacts/shells/chrysanthemum/contact-sheet.png)
- [Palm phases](../artifacts/shells/palm/contact-sheet.png)
- [Willow phases](../artifacts/shells/willow/contact-sheet.png)
- [Chrysanthemum report](../artifacts/shells/chrysanthemum/verification.json)
- [Palm report](../artifacts/shells/palm/verification.json)
- [Willow report](../artifacts/shells/willow/verification.json)
- [Prismatic regression report](../artifacts/shells/prismatic/verification.json)
- [Live overlay log](../artifacts/shells/overlay.log)

## Limits and next work

The demo concatenates three independent captures; it is **not live show
choreography**. Replaying still replaces the current shell. Overlapping launches,
coordinated monitor viewpoints, richer smoke lighting, and performance profiling
remain future work. Smoke remains procedural billboards, not volumetric fluid
simulation. A transparent SDR overlay cannot physically relight the desktop.

Live tests were muted: generated audio was tested and exported, not auditioned.
The isolated overlay test exercises the plugin's payload handler, not the
installed Omarchy shell's IPC transport, bar clicks, or interactive settings
selection/persistence across a real shell restart. Multi-monitor synchronization
and sustained frame-rate targets remain unmeasured. Window screenshots may be
stale during compositor tiling and are not used as visual evidence.

Following the Omarchy integration conventions, the bundle remains separate in
`build/plugin/`; it is **not installed or enabled**. Test preferences stay in
`build/verification-config/`. Omafetti, user shell configuration, hotkeys, and
packaged Omarchy files were not modified.
