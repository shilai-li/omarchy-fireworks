# Prismatic willow — color verification

Verified 2026-09-06 on Qt 6.11.2 / Mesa 26.2.1 / Intel Arc B390, seed 73.
The default effect is now colorful; the original golden-willow captures remain
in `artifacts/` as a baseline. New evidence is in `artifacts/prismatic/`.

## What changed

- Eight authored colors: ruby, amber, lime, emerald, cyan, sapphire, violet, rose.
- Stars keep their color throughout flight. Historical trails, shed sparks,
  crackling embers, and star-emitted smoke inherit that color.
- Pale-hot spark cores replace the fixed golden highlight. Colored radiance
  also enters bloom; tone mapping scales intensity while retaining RGB ratios.
- The warm rocket and near-white burst flash lead into the multicolor shell.
  Physics, timing, audio, particle budgets, and draw batching are unchanged.
- Preview and plugin labels now identify the effect as **Prismatic willow**.

## Checks

The build succeeds; CTest passes **2/2 tests**, including deterministic star and
ember colors, all eight palette entries, frame-pacing independence, rewind,
native QML controls, simulation cleanup, and the existing stereo-audio checks.
`omarchy plugin validate build/plugin` also passes.

Vulkan captures pass at 1920×1080 with RGBA16F accumulation. The capture tool now
rejects a monochrome or washed-out burst: at 3.7 and 5.9 seconds, every one of
six 60-degree hue sectors must contain at least 100 bright, saturated pixels.
Pixels qualify when their peak RGB channel exceeds 64/255 and saturation is
greater than 40%. Hot pale cores and faint pixels are excluded.

| Phase | Time | Smallest hue-sector population | Render + readback |
|---|---:|---:|---:|
| Expanding burst | 3.7 s | 8,581 pixels | 7.53 ms |
| Falling branches | 5.9 s | 2,969 pixels | 6.85 ms |
| Last embers | 8.2 s | 193 pixels | 4.95 ms |

All six captured phases retain valid premultiplied alpha; the final 11-second
frame has zero nontransparent pixels. Timings are individual capture samples,
including GPU completion/readback and excluding simulation/PNG encoding, not
a desktop frame-rate benchmark.

The muted preview and temporary Quickshell overlay run successfully on OpenGL,
with HDR buffers enabled. The overlay renders at 3072×1920 and reports launch
and cleanup success. The host's existing portal application-ID warning remains;
no plugin import, settings initialization, or renderer errors were logged.

Burst, falling trails, decay, and dark/light compositions were visually inspected.
The 331-frame sequence was encoded into an 11-second 1920×1080, 30 fps H.264 demo
with stereo AAC audio. Live tests remain muted; audio was not auditioned.

The preview's optional window screenshot was inconsistent in this session:
some grabs retained the pre-tiling surface size or incomplete contents. Waiting
longer and trying asynchronous item capture did not resolve it reliably, so
those experimental capture changes were not retained. Window screenshots are
not used as color evidence; the direct Vulkan frames and animation above are.
The startup/overlay lifecycle test does not assert screenshot pixel contents.

## Evidence

- [Colorful animation](../artifacts/prismatic/prismatic-willow.mp4)
- [Burst](../artifacts/prismatic/03-3.70s.png)
- [Motion phases](../artifacts/prismatic/contact-sheet.png)
- [Light-background composition](../artifacts/prismatic/light-background.png)
- [Measurements](../artifacts/prismatic/verification.json)
- [Overlay log](../artifacts/prismatic/overlay.log)

The native plugin bundle is rebuilt in `build/plugin/`, **not installed or
enabled** in the running shell. Following the Omarchy integration conventions,
tests use repository-local preferences; Omafetti and user shell settings are
unchanged. The [baseline limitations](VERIFICATION.md#honest-limits-and-next-work)
still apply: one authored shell, procedural billboard smoke, unmeasured sustained
frame rate, and no installed-shell IPC/bar or multi-monitor synchronization test.
