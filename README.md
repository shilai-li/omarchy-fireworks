# Fireworks

A native fireworks renderer for the Omarchy desktop, with HDR light accumulation,
colored bloom, historical trails, illuminated smoke, and delayed stereo sound.

| Shell | Design |
|---|---|
| Crimson chrysanthemum (default) | A crimson sphere around a cyan heart; short trails turn gold. |
| Emerald palm | Twelve emerald/cyan fronds with long arching trails and golden crackle. |
| Violet willow | Long violet/cyan branches bend under gravity and dissolve into gold. |
| Prismatic willow | The original eight-color willow, retained as an option. |
| Sapphire ring | A tilted, hollow ring banded in sapphire and rose. |
| Rose peony | Three nested rose/sapphire layers that fade from the outside in. |
| Lime crossette | Few heavy stars, each breaking into a four-armed cross. |
| Rose heart | A rose and cyan double outline with a clear notch and pointed tip. |
| Amber Saturn | A compact amber sphere inside a wide, tilted cyan orbit. |
| Violet spiral | Three curved violet/cyan arms expand and fade into golden sparks. |
| Aurora waterfall | A wide cyan/violet canopy cascades into long golden rain. |
| Ruby dahlia | Sixteen ruby/cyan petals open around a bright cyan pistil. |
| Sapphire star | A five-point sapphire outline edged in rose, with a gold finish. |
| Rainbow bouquet | Twenty-four petals in eight vivid hues around a multicolor pistil. |
| Carnival rings | Three nested rainbow color wheels with short sparkling trails. |
| Rainbow rain | Eight jewel colors cascade from a wide canopy, turning gold late. |

The product direction and milestone checklist live in [AGENTS.md](AGENTS.md).

## Build and preview

Requires a C++20 compiler, CMake, Ninja, Qt 6.7 or newer with Quick, Quick
Controls, Shader Tools, Multimedia, Concurrent, and the private GUI headers.
The capture tool also needs Vulkan headers. On Arch/Omarchy:

```bash
omarchy pkg add cmake ninja gcc qt6-base qt6-declarative qt6-shadertools qt6-multimedia vulkan-headers
cd backend
cmake -S . -B build -G Ninja -DCMAKE_BUILD_TYPE=RelWithDebInfo
cmake --build build -j 4
./build/omarchy-fireworks
```

The repo root is the Omarchy plugin itself (`manifest.json`, `Fireworks.qml`,
`BarWidget.qml`, ...); the native engine, renderer, and this standalone preview
live in `backend/` and build there, one level down.

The preview opens on a paused frame. Choose a shell in the selector, then use
**Launch shell**, or press **R**, to
replay. **Space** pauses/resumes; **M** mutes; the timeline allows scrubbing.
Glow, exposure, and volume controls apply immediately. `--mute` starts muted.

## Architecture

```text
QML controls / Omarchy IPC / monitor overlays
                    |
              ShowDirector
       shared time, seed, audio scheduling
          /                     \
native 3D Simulation          stereo PCM audio
          |                     |
batched GPU Renderer          QAudioSink
          |
HDR scene → bloom → tone mapping → transparent overlay
```

- The launch position is a simulation input, bounded to a fixed world spread so
  the widest shell stays inside a 16:9 frame; the simulation never sees the
  viewport. Random placement is resolved by the show director, which owns the
  seed, so a given seed replays the same sequence of positions and views bind to
  the resolved position rather than to the preference.
- Simulation advances in fixed 1/120-second steps, independently of frame rate.
  Each view simulates on the Qt render thread. Connected monitors share the
  director's clock and seed; they currently show the same composition.
- Rendering uses `QQuickRhiItem` and Qt's active graphics backend. Sparks and
  historical trails use batched triangles; no individual particles are QML
  objects. Internal RGBA16F light buffers feed a two-scale bloom pipeline.
- Shell profiles author the geometry, drag, trail length, palette, and burn
  progression. The ring is thrown in one tilted plane and given deliberately
  short trails, because a willow's trail length reaches back to the burst and
  fills the ring in as a disc. The peony nests three layers that slow, outlive,
  and burn later the further in they sit. A crossette star is replaced mid-flight
  by four children thrown across its line of flight, which is the one shell whose
  star count grows after the burst; children inherit the parent's colour and its
  burn progress rather than starting cold. The waterfall spreads a shallow canopy
  into long falling streamers; the dahlia bundles sixteen layered petals around
  a slow cyan pistil; the star follows a double five-point outline. Authored shells
  transition from coordinated colors to gold;
  historical trails retain their emission colors and shed embers inherit their
  birth color. Prismatic stars keep their original eight-color identities.
  Pale-hot cores and intensity-based tone mapping preserve colored bloom.
- The final texture uses premultiplied alpha. Smoke darkens/obscures background
  pixels while sparks and glow remain luminous. A transparent overlay cannot
  physically relight other applications. Internal HDR does not require or
  imply an HDR desktop output.
- Audio is generated on a worker thread and played once per show, independent
  of monitor count. The initial sound delay models a listener 120 metres away.
  Audio preparation is cached by seed and shell, with shell-specific crackle timing.
  Playback currently requires an output supporting 48 kHz stereo 16-bit PCM.
- **Display** decides how much one trigger sends up: `one shell`, a `volley` of
  four different shells ending on your choice, or a `full show` of every catalog
  style, once each in shuffled order, with your choice last. The **Interval** slider
  appears when Full show is selected and saves a 3–12 second gap between launches.
  At the default three seconds, sixteen styles take about 56 seconds including
  the final fade; slower settings give each shell more time on its own. Changes
  apply to the next show. Every full-show lift uses a
  random horizontal position; one shell and volley follow the launch-position
  setting. The catalog automatically determines the full-show length. Volley
  and full show peak at four active shells.

QRhi is a Qt API with limited binary compatibility. Rebuild the native module
after Qt upgrades; do not carry its binaries between incompatible Qt builds.
References: [Qt rendering integration](https://doc.qt.io/qt-6/qquickrhiitem.html)
and [QRhi](https://doc.qt.io/qt-6/qrhi.html).

## Verification

```bash
ctest --test-dir backend/build --output-on-failure
omarchy plugin validate backend/build/plugin
./backend/build/fireworks-capture backend/artifacts/shells/chrysanthemum --shell chrysanthemum
```

The windowless capture tool uses the desktop's platform Vulkan integration. Run
it from a working graphical session with GPU access; Qt's `offscreen` platform
does not provide Vulkan initialization here. It writes six 1920×1080 frames,
transparent versions, dark/light background comparisons, a contact sheet,
`show.wav`, and a JSON verification report. `--shell` takes any slug in the
catalog — run `--help` for the current list, which the tool generates rather
than repeating. `--launch` takes a position from -1 to 1. It checks premultiplied alpha, visible output,
at least two hue sectors in each authored shell's hero frame, all six hue sectors
in the prismatic burst and falling trails, and complete transparency at the end.
Reported timings include GPU completion and readback, not just rendering.

To capture the full animation:

```bash
./backend/build/fireworks-capture backend/artifacts/shells/palm --shell palm --sequence
ffmpeg -y -framerate 30 -i backend/artifacts/shells/palm/sequence/frame-%04d.png -i backend/artifacts/shells/palm/show.wav -c:v libx264 -crf 18 -pix_fmt yuv420p -c:a aac -b:a 192k -shortest backend/artifacts/shells/palm/show.mp4
```

`bash backend/scripts/verify-live.sh backend/artifacts/shells` briefly opens
the preview, saves a screenshot of its own window, then launches a muted
Quickshell overlay on connected monitors.
The overlay selects and runs all three new shells, then exits after about
35.4 seconds. Test settings and caches stay in `backend/build/`.
Window screenshots can retain stale contents during compositor tiling; use the
direct GPU captures for reliable visual review. The live script checks startup,
renderer initialization, settings, and lifecycle, not screenshot pixel contents.

## Omarchy plugin bundle

The repo root *is* the plugin — `manifest.json`, `Fireworks.qml`,
`BarWidget.qml`, and the rest sit at the top level, the way `omarchy plugin
add` needs them to. Its ID is `shilai_li.fireworks`; it is separate from
Omafetti, and the reference Omafetti installation is not changed by the build
or tests.

An Omarchy plugin is cloned files only — `omarchy plugin add` builds nothing
and runs nothing — but Fireworks needs two compiled Qt/QRhi libraries that
Quickshell loads directly (`import "native"`), not a daemon reached over IPC.
On a fresh install, the plugin opens a setup card before loading its native
module. Setup and settings open in a bar-anchored popup, like Studio Effects.
No prebuilt release is currently published; choose **Build from source**.
When a release is available, choose **Use prebuilt** to download its libraries, or
**Build from source** (also Enter) to compile them yourself. Both choices open
the centered floating Omarchy terminal with progress and any errors (with a
standard-terminal fallback if the floating launcher is unavailable). After
setup, press a key once at Omarchy's Done prompt to close it; the fallback asks
for Enter. Escape closes the card; the bar icon opens it again.
The terminal first explains the build, install location and shell restart,
shows the source commit and cache directory, then asks **Continue? [Y/n]**.
Declining makes no changes. Source builds compile a clone of the plugin's
committed checkout under `~/.cache/omarchy-fireworks-build/`; source files in the
installed plugin are left alone. Only its resulting native libraries and build
metadata are installed into the plugin. No system package or root access is
needed when the build dependencies are already present.

The prebuilt option requires Linux x86_64 and the exact Arch Qt package versions
recorded in [prebuilt.json](prebuilt.json). It verifies the release's SHA-256
checksum and shared-library dependencies before installing anything. It needs
`curl`, `jq`, Python and the Qt runtime packages, but no compiler or CMake.
If your Qt packages differ, choose **Build from source**. QRhi uses private Qt
APIs, so binaries must be rebuilt after incompatible Qt changes.

The source option does not install system packages: install the dependencies
listed under Build and preview first. During either setup, Fireworks is paused;
successful setup restarts the Omarchy shell and re-enables the plugin to load
the new libraries safely.

```bash
omarchy plugin add https://github.com/shilai-li/omarchy-fireworks.git --enable
# In the Fireworks notice, choose Use prebuilt or Build from source.
```

You can also build and install manually:

```bash
cd backend
cmake -S . -B build -G Ninja -DCMAKE_BUILD_TYPE=RelWithDebInfo
cmake --build build -j 4
cd ..

omarchy plugin add https://github.com/shilai-li/omarchy-fireworks.git --enable
cp backend/build/plugin/native/*.so ~/.config/omarchy/plugins/shilai_li.fireworks/native/
omarchy-shell shell rescanPlugins
```

For local development — testing a change against the running shell without
publishing anything — `backend/build/plugin/` is already the complete bundle,
native libraries included; copy it into
`~/.config/omarchy/plugins/shilai_li.fireworks/` directly:

```bash
cp -a backend/build/plugin ~/.config/omarchy/plugins/shilai_li.fireworks
omarchy-shell shell rescanPlugins
omarchy plugin enable shilai_li.fireworks
omarchy-shell shell summon shilai_li.fireworks
```

**Launch** places the shell across the frame, from hard left to hard right, or
`random` picks a fresh spot for every launch. The stereo image leans the same
way, so a shell that goes up on the left booms from the left. The rocket rises
vertically and bursts directly above its launch position.

Click the star icon to open the settings card. The icon never launches a show:
an icon between the tray and the clock is too easy to hit by accident for
something that then covers every monitor for half a minute. Launching is the
hotkey's job.

In the card, **record (R)** captures a key combination and binds it; **clear**
removes it. The binding lives in a marked block in `~/.config/hypr/bindings.lua`
that only this plugin writes:

```lua
-- >>> fireworks hotkey (managed by Fireworks settings — change it there)
o.bind("SUPER + ALT + W", "Fireworks (launch a shell)", "omarchy-shell shell summon shilai_li.fireworks")
-- <<< fireworks hotkey
```

`fireworks-ctl.sh` does that writing, and refuses a bindings.lua it does
not recognise — missing, not a regular file the user owns, over a megabyte, or
with its marked block already damaged — rather than guessing. Clearing restores
the file byte for byte. The card reports the script's own refusal message when
it declines, instead of claiming a write that did not happen. The block-editing
approach follows [Omafetti](https://github.com/weedwhitesandwine/omafetti)'s
`omafetti-ctl.sh` (MIT), which solved this first.

Inside the card, Space launches, Escape closes, and R starts recording. Shell,
sound, glow, and light save as you set them; only the hotkey reaches outside the
plugin's own INI. A payload overrides the saved shell or display
size for one launch without changing either preference:

```bash
omarchy-shell shell summon shilai_li.fireworks '{"shell":"palm","muted":true}'
omarchy-shell shell summon shilai_li.fireworks '{"size":"full show"}'
omarchy-shell shell summon shilai_li.fireworks '{"shell":"heart","size":"volley"}'
omarchy-shell shell call shilai_li.fireworks close ""
```

`close` stops all fireworks and dismisses the settings overlay.

Launches overlap on the desktop, whether they come from one trigger or several:
up to four shells keep independent timelines, styles, positions, and sound. A
fifth launch replaces the oldest, which is why the built-in displays are spaced
to stay at four.
The audio level is shared across active shells to retain mixing headroom.
`close` stops all active and pending launches. The standalone preview still
replays a single shell for inspection.

Preferences are stored in `$XDG_CONFIG_HOME/omarchy-fireworks/settings.ini`
(normally `~/.config/omarchy-fireworks/settings.ini`).
Settings are also available through:

```bash
omarchy-shell shell summon shilai_li.fireworks '{"view":"settings"}'
```

A Hyprland hotkey can invoke the same summon command. Choose an unused shortcut
in your user bindings. The plugin does not rewrite bindings automatically.

Inspect the live display and active shell types with:

```bash
omarchy-shell shell call shilai_li.fireworks status ""
```

Native-library updates require a shell restart. Avoid overwriting shared
libraries while the shell has them loaded; stage an updated bundle and replace
it while the shell is stopped. QML changes normally hot-reload; if a rescan leaves
old behavior active, restart the shell and verify actual launches with `status`.
`omarchy plugin update shilai_li.fireworks` pulls this repo's QML but, being a
plain git pull, cannot know to also rebuild and copy a `.so` — do
`cd backend && cmake --build build -j 4` and the `cp .../native/*.so` step
yourself after `omarchy restart shell`, then restart it again.

See [docs/INSTALL-VERIFICATION.md](docs/INSTALL-VERIFICATION.md) for the
installed-shell integration evidence,
[docs/SHELL-VERIFICATION.md](docs/SHELL-VERIFICATION.md) for the current shell
catalog, [docs/COLOR-VERIFICATION.md](docs/COLOR-VERIFICATION.md) for the earlier
prismatic milestone, and [docs/VERIFICATION.md](docs/VERIFICATION.md) for the
original golden-willow baseline.

## License

MIT — see [LICENSE](LICENSE).

`fireworks-ctl.sh` adapts the marked-block hotkey-rewriting approach
(resolve the config, refuse anything unrecognised, rewrite only the plugin's
own block, swap it in atomically) from
[Omafetti](https://github.com/weedwhitesandwine/omafetti)'s
`omafetti-ctl.sh`, MIT-licensed, Copyright (c) 2026 weedwhitesandwine.
