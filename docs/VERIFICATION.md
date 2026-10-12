# Golden willow verification

Verified on 2026-09-06. This is the first runnable milestone, not a claim that
the later choreography and performance milestones are complete.

## Environment

- Omarchy 4.0.2; Quickshell 0.3.1.
- Qt 6.11.2, built with the matching private GUI headers.
- Intel Arc B390 (PTL); Mesa 26.2.1.
- Vulkan headers 1.4.357; CMake/Ninja, RelWithDebInfo, C++20.
- Fixed show seed: 73. Show duration: 11 seconds.

## Results

The CMake build succeeds and produces the preview, Vulkan capture tool, native
QML module, and relocatable `build/plugin/` bundle. The module resolves its
backing library from the adjacent `native/` directory using `$ORIGIN`, without
an absolute build-directory RUNPATH. System Qt libraries are still required.

`ctest --test-dir build --output-on-failure`: **2/2 passed** (0.11 seconds).

- Engine tests cover ascent, a 460-star 3D burst, frame-pacing independence,
  deterministic rewind, recorded trails, wind, falling branches, bounded
  populations/catch-up, invalid time input, and complete simulation cleanup.
- Audio tests cover deterministic 48 kHz stereo PCM, silence before the
  propagation delay, stereo differences, output headroom, and a silent ending.
- The native QML import test also exercises launch, pause, resume, seek,
  volume bounds, and the view's time bound without opening a window.

`omarchy plugin validate build/plugin`: **passed**.

`bash scripts/verify-live.sh`: **passed**. The standalone preview rendered on
OpenGL and its own window was captured at 1468×1832 physical pixels after the
window manager tiled it. The temporary Quickshell overlay loaded the bundle by
absolute file URL, rendered at 3072×1920 on OpenGL, and reported successful
launch and cleanup after the complete show. Both reported floating-point HDR
light buffers. Test preferences were written under
`build/verification-config/omarchy-fireworks/settings.ini`.

The host emitted a desktop-portal application-ID warning, but no plugin import,
settings initialization, or renderer errors remained in the final run. This
test does not replace installation into the user's running Omarchy shell.

## Rendered frames

`./build/fireworks-capture artifacts`: **passed**, using Vulkan on the Intel
Arc B390 at 1920×1080 with RGBA16F light accumulation.

| Show time | Phase | Vertices | Pixels with alpha > 8/255 | Render + readback |
|---|---|---:|---:|---:|
| 1.15 s | Rising rocket | 1,230 | 4,983 | 4.85 ms |
| 2.03 s | Burst flash | 19,002 | 9,024 | 4.62 ms |
| 3.70 s | Expanding gold branches | 209,868 | 216,058 | 7.89 ms |
| 5.90 s | Falling willow | 224,172 | 176,483 | 6.95 ms |
| 8.20 s | Last embers | 103,752 | 12,221 | 4.89 ms |
| 11.00 s | Fully cleared | 0 | 0 | 2.95 ms |

These are individual captures, not a sustained benchmark. Timings include CPU
geometry/submission, GPU completion, and readback, but exclude simulation
advancement and PNG encoding. They do not establish desktop frame-rate targets.

All six frames passed the premultiplied-alpha check (RGB no greater than alpha,
allowing one 8-bit quantization step). The final frame has **zero pixels with
nonzero alpha**, not merely pixels too faint to count. Dark and light background
composites were visually inspected for framing, fine trails, glow, smoke, and
transparent edges. The phase sequence was inspected from ascent through decay;
the preview screenshot also confirmed the responsive control layout.

The full sequence contains 331 captured frames, including both endpoints, at
30 samples per second. The encoded demo is 1920×1080 H.264, 30 fps, 11 seconds,
with 48 kHz stereo AAC audio. Encoding stops at the WAV's 11-second duration.

Generated evidence (untracked, regenerate using the README commands):

- [Contact sheet](../artifacts/contact-sheet.png)
- [Light-background composition](../artifacts/light-background.png)
- [Preview screenshot](../artifacts/preview.png)
- [Animation with sound](../artifacts/golden-willow.mp4)
- [Uncompressed sound](../artifacts/golden-willow.wav)
- [Machine-readable frame measurements](../artifacts/verification.json)
- [Preview log](../artifacts/preview.log) and [overlay log](../artifacts/overlay.log)

## Honest limits and next work

- The bundle is built but **not installed or enabled** in the user's shell.
  Omafetti, shell configuration, and hotkeys were not modified. IPC routing,
  bar interactions, and manual click-through behavior in the installed shell
  still need an installation test.
- Live tests were muted. Synthesized sound and its timing were verified in PCM
  tests and exported to the demo, but speaker playback, subjective sound quality,
  and real audio-device latency were not auditioned or measured.
- Smoke is procedurally shaded drifting billboards, not ray-marched volumetric
  transport. Depth comes from 3D trajectories and perspective projection.
- Every connected monitor currently repeats the same composition using a
  shared clock and seed, with its own simulation and GPU buffers. Multi-monitor
  synchronization and mixed-DPI behavior were not measured on multiple displays.
- Only this Intel/Mesa system was tested. Qt's software scene graph cannot run
  this native renderer; other GPUs/backends and the RGBA8 fallback are unverified.
- Internal HDR is tone-mapped to a normal transparent desktop surface. True HDR
  display output and physically relighting other applications are not provided.
- The next milestones are additional authored shells, richer choreography and
  spatial sound, then measured CPU/GPU frame-time and memory tuning.
