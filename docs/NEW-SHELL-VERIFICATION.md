# Waterfall, dahlia and star

Verified 2026-10-01 on Intel Arc B390.

Three shells are appended at indices 10–12, preserving all existing saved
selections. The native catalog supplies their names, descriptions and IPC slugs
(`waterfall`, `dahlia`, `star`) to the preview and plugin settings automatically.

- Aurora waterfall: 28 cyan/violet streamers with eight beads each, spreading
  into a shallow canopy before gravity pulls them into a falling curtain.
- Ruby dahlia: 16 narrow radial petals with 16 beads each, surrounding a slow
  spherical cyan pistil of 32 stars. Bright outer tips mark each petal.
- Sapphire star: two alternating sapphire/rose bands along a five-point outline,
  with deep notches and short trails that preserve the hollow shape.

All retain historical trail colors, changing golden tips, bounded particle
storage, and shell-specific crackle schedules. Existing simulation, audio,
native import and overlapping-launch suites pass. New geometry assertions check
the waterfall's canopy and width, dahlia petal bundles and pistil separation,
and the star's five tips, five notches and hollow plane. The generic shell loop
checks deterministic motion, burn history, bounded decay and complete cleanup.

The Vulkan capture tool produced six frames per shell with seed 73 at
1920×1080, under `backend/artifacts/new-shells/` (untracked). All three contact
sheets were visually reviewed through launch, bloom, fall and decay: the
waterfall fans out and droops, the dahlia retains separated petals around its
cyan centre, and the star remains legible as it expands. GPU checks pass for
color separation and premultiplied transparent edges. At 11 seconds every
capture has zero covered pixels and zero vertices.

These captures verify sampled progression, not desktop frame rate. Native
updates require a shell restart; do not overwrite mapped libraries in place.

The updated native libraries and manifest were installed after stopping the
shell, with the previous bundle backed up under `/tmp/`. The shell restarted
successfully and returned `ok` for all three named, muted one-shell IPC launches.
Its log records three OpenGL renderers at 3072×1920 on the same Intel Arc B390,
with no firework load errors. Audio was checked by synthesis tests, not by
listening to these muted live launches.

## Eight-color expansion

Three further shells are appended at indices 13–15: `bouquet`, `carnival`, and
`rainbow-rain`. Rainbow bouquet has 24 colored petal bundles and a 48-star
multicolor pistil. Carnival has three concentric hollow rings with eight hue
sectors rotated between layers. Rainbow rain colors each falling streamer
individually. Their gold transition starts after 72–74% of each star's life,
preserving saturated bloom and falling trails. The original prismatic willow
continues to retain its colors throughout its lifetime.

All four suites pass with the sixteen-shell catalog. New checks require at
least eight stars in each of the eight palette colors, a late gold transition,
and three separated planar carnival rings. The capture tool now requires all
six visible hue sectors in both the bloom and fall frames of every multicolor
shell. All three pass Vulkan color, transparent-edge and empty-final-frame
checks at 1920×1080, seed 73. Their six-frame contact sheets under
`backend/artifacts/rainbow-shells/` were visually reviewed: petals, nested rings
and falling streamers retain distinct rainbow bands through expansion and fall.

Mixed shows now shuffle the catalog from a fixed display seed and reserve the
chosen shell for the last lift. This fixes the old arithmetic stride, which
would repeat just two entries with a sixteen-shell catalog. The launch-pool
suite verifies all fifteen other selections are visited without repeats.

The sixteen-shell build was installed with a bundle backup and shell restart.
All three rainbow slugs returned `ok` from muted one-shell IPC launches; the
running shell initialized three OpenGL renderers at 3072×1920. No firework load
errors appeared, and the compositor had no firework layer surfaces after they
finished. Each bloom/fall capture has at least 707 saturated pixels in every hue
sector (the assertion threshold is 100). Desktop frame rate remains unmeasured.

Volley now uses the same shuffled selection: three distinct catalog picks,
followed by the selected shell. The launch-pool suite checks that all four
styles differ and the selected one comes last. Its four lifts and launch-position
setting are unchanged.

The initial QML-only deployment did not take effect in the running shell:
rescans reported a reload, but even a newly installed `status` method remained
unavailable. After a clean shell restart, live status reported `volleyMixed:
true`, sixteen catalog entries, and the saved `volley` display. A muted trigger
using the saved settings was inspected after 4.3 seconds: the four simultaneous
controllers were Carnival rings (14), Amber Saturn (8), Sapphire ring (4) and
Crimson chrysanthemum (0), at distinct resolved launch positions. Only one
shell process remained. A rescan log alone is insufficient deployment evidence.

## Full catalog, one at a time

Full show now derives its lift count from the catalog and visits every style
once, ending on the selected shell. Lifts are 11.2 seconds apart, leaving the
previous 11-second shell and its 80 ms start delay time to finish. Sixteen shells
take about 179 seconds. All positions are randomized. The earlier simultaneous
two-shell finale is superseded by this sequential ending.

All four suites pass. The launch-pool suite advances the queue with simulated
completion between lifts and verifies all sixteen styles without repeats,
selected-style-last behavior, random placement enabled, and peak concurrency
of one. The installed shell's live status confirms sixteen lifts at
0/11.2/22.4/…/168 seconds after a clean restart.
The live first lift was Carnival rings; after the scheduled interval, only
Amber Saturn was active, confirming the first shell had released its slot.
Closing cancelled the remaining queue and left no active controllers. The
whole sixteen-style ordering is covered by the automated queue test; this
live check sampled the first transition rather than waiting three minutes.

## Adjustable pacing

The fixed 11.2-second gap was replaced by a saved **Interval** slider in the
Full show settings. It ranges from 3 to 12 seconds in half-second steps and
defaults to 3 seconds (about 56 seconds for sixteen styles including the final
fade). Shorter intervals overlap shells; three seconds is the fastest value
that keeps eleven-second shows within the four launch slots.

All four suites pass. Interval checks cover 6.5-second scheduling, bounds at
3 and 12, and preserving the schedule of an already-started show when the
setting changes. The new installed card was visually inspected in a desktop
screenshot: the slider, seconds readout, explanatory caption and launch button
fit without clipping. Live status reports the default lifts at 0/3/6/…/45 seconds.
The interval is stored alongside other preferences in settings.ini; changes
apply to the next triggered show.
