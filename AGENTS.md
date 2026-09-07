# Omarchy Fireworks

## Product direction

Build cinematic fireworks for the Omarchy desktop. Judge the result by convincing
light, depth, motion, and choreography. The reference architecture is a starting
point; make implementation choices that improve the visible result.

Build colorful, authored shells: a crimson/cyan chrysanthemum, an emerald/cyan
palm, and a violet/cyan willow, with changing tips and golden crackle finishes.
The chrysanthemum is the default; retain the original eight-color prismatic
willow as an option. Keep distinct hues through bloom and fading. Historical
trails retain their emission colors rather than changing all at once. A golden
finish is intentional, but do not revert the whole effect to monochrome gold.

## Architecture

- QML owns settings, IPC, hotkeys, preview controls, and click-through overlays.
- A native show director owns the show clock, seed, and timed audio events.
- Native simulation owns 3D positions, gravity, drag, wind, particle lifetimes,
  and recorded trails. Keep simulation independent of QML and rendering.
- A batched GPU renderer owns luminous particles, trails, procedural smoke,
  floating-point light accumulation, bloom, and transparent composition.
- Audio consumes show events and sends stereo sound to the audio device. It does
  not depend on GPU readback or the number of connected monitors.
- Use Qt Quick's rendering integration and the host's graphics backend. Keep
  graphics resources on the render thread; transfer state at synchronization.
- Keep individual particles out of the QML object tree. Bound particle counts,
  trail storage, simulation catch-up, and audio voices.

## Milestone 1 — Golden willow

Implement one complete, runnable effect before adding more firework families.

- [x] Reproducible CMake build and native QML module.
- [x] Deterministic 3D rocket flight, burst, falling stars, and secondary embers.
- [x] Tapered historical trails, bright spark cores, and illuminated drifting smoke.
- [x] GPU light accumulation, bloom, tone mapping, and correct transparent edges.
- [x] Delayed stereo boom and crackle, with mute and volume controls.
- [x] Standalone preview and Omarchy-compatible overlay entry point.
- [x] Meaningful simulation/audio tests and captured launch, burst, and decay frames.
- [x] Build/run documentation with measured verification and honest limitations.

Completion requires a successful build, passing relevant tests, and visual
inspection of rendered frames. Record the graphics backend used. Do not claim
desktop frame-rate targets or live shell integration were verified without
measuring/testing them. Update the checklist as evidence becomes available.

Verified 2026-09-06 on Intel Arc B390: Vulkan captures and an OpenGL preview /
temporary Quickshell overlay. See [docs/VERIFICATION.md](docs/VERIFICATION.md).
The bundle is now installed and enabled in the running Omarchy shell; see
Milestone 2.1. Frame-rate targets remain unmeasured.

## Milestone 1.1 — Prismatic color

- [x] Eight authored colors shared by stars, historical trails, shed embers, and smoke.
- [x] Pale-hot spark cores and hue-preserving HDR tone mapping.
- [x] Deterministic palette tests and GPU checks against a monochrome regression.
- [x] Updated preview/plugin labels and visually inspected burst, fall, and decay captures.

Verified 2026-09-06 with Vulkan captures and a temporary OpenGL overlay.
See [docs/COLOR-VERIFICATION.md](docs/COLOR-VERIFICATION.md).

## Later milestones

### Milestone 2 — Authored shell catalog

- [x] Three distinct simulations: chrysanthemum sphere, twelve-frond palm, long willow.
- [x] Coordinated palettes, historical color transitions, and golden crackle finishes.
- [x] Preview selector, persistent plugin selector, and named-shell IPC payloads.
- [x] Shell-aware audio schedules, deterministic tests, bounded cleanup, and per-shell captures.
- [x] Visual review of all three shell sequences and documented verification.

Verified 2026-09-07: three passing test suites, four Vulkan shell capture sets,
and an isolated OpenGL overlay running all three new shells through cleanup.
See [docs/SHELL-VERIFICATION.md](docs/SHELL-VERIFICATION.md) for evidence and limits.
Frame-rate targets remain unmeasured; installed-shell integration is covered by
Milestone 2.1.

### Milestone 2.1 — Installed-shell integration

- [x] Bundle installed and enabled in the running Omarchy shell.
- [x] Bar widget present; native renderer initializes in the shell process.
- [x] All four shells and the settings view driven through live `summon` IPC.
- [x] Live PipeWire audio stream in the documented format.
- [x] Overlay, layer-surface, and audio cleanup after each show.

Verified 2026-09-07 on the running shell with OpenGL on Intel Arc B390.
See [docs/INSTALL-VERIFICATION.md](docs/INSTALL-VERIFICATION.md). Frame-rate
targets, multi-monitor overlay behavior, and pointer-driven bar interaction
remain unverified.

### Subsequent work

1. Additional authored shells: rings and layered bursts.
2. Show choreography, coordinated monitor views, and richer sound design.
3. Performance tuning against measured GPU/CPU frame times on real displays.

## Working conventions

- Use `gh` first for GitHub discovery, reviews, checks, and merges.
- Preserve user changes. Do not add Codex attribution trailers to commits.
- Develop in this repository; keep generated builds and captures untracked.
- Follow the Omarchy skill when working with desktop integration. Never modify
  packaged files under `/usr/share/omarchy/`.
- Keep this plugin separate from the installed Omafetti reference.
- Document native Qt/QRhi compatibility requirements and installation steps.
- Validate motion over time, transparent composition, and cleanup—not just a
  single attractive frame. Use a fixed seed for repeatable visual review.
