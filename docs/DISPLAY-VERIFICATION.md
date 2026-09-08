# One trigger, a whole display

Verified 2026-09-08 on the installed Omarchy shell, Intel Arc B390, OpenGL.
Two panels were connected during the session; measurements name the one used.

Overlapping launches already existed (`f2b850f`), but only if you triggered the
plugin repeatedly. A single trigger still sent up exactly one shell. `Display`
now chooses how much one trigger produces.

| Display | Shells | Lifts (s after trigger) | Runs for | Peak in the air |
|---|---|---|---|---|
| one shell | 1 | 0 | 11 s | 1 |
| volley | 4 | 0, 1.3, 2.6, 3.9 | 15 s | 4 |
| full show | 6, mixed | 0, 2.8, 5.6, 8.4, 14.2, 14.6 | 26 s | 4 |

## Why the full show is spread out

A slot is held for a shell's whole 11 s life, and the fifth concurrent launch
evicts the oldest slot — cutting a shell off in mid-air. So peak concurrency is
"how many lifted in the last 11 s", not the total. The measured cost of holding
more at once decided the shape, on eDP-1 at 3072x1920, from DRM fdinfo:

| Concurrent shells | Render engine busy | Peak GTT | Peak RSS |
|---|---|---|---|
| idle | 0.8 % | 607 MiB | 866 MiB |
| 1 | 23.2 % | 1363 MiB | 968 MiB |
| 2 | 44.6 % | 1751 MiB | 1013 MiB |
| 4 | 65.1 % | 2539 MiB | 1139 MiB |

About +390 MiB and +10-20 points of GPU per extra concurrent shell. Eight at
once — which "8 shells over 12 s" would have required — extrapolates to roughly
90 % of the render engine and about 4 GiB of GTT. That was judged the wrong
trade, so the full show is spread over 26 s at a peak of four rather than
stacked deeper. The gap between the fourth lift and the finale is deliberate:
it lets the early shells die so the finale pair fits under the ceiling.

A whole full show, measured over its 16 s of launches on HDMI-A-1 at 3840x2160:
**24.1 % mean render-engine busy, 1411 MiB peak GTT, 866 MiB peak RSS**, falling
back to 384 MiB GTT afterwards.

## Checks

- CTest passes 4/4, including the extended `overlapping-launches` suite.
- New assertions, each confirmed to fail when the behaviour is broken:

  | Mutation | Caught by |
  |---|---|
  | `stop()` no longer cancels the queue | `a cancelled display must stay cancelled` |
  | full show packed to 1.5 s spacing | `display must not outgrow the slot capacity: full show` |
  | finale allowed to use a mixed shell | `a mixed display must end on the chosen shell` |

  The capacity assertion runs over every row of the table, so retuning a
  schedule into eviction fails the build rather than silently truncating shells.
- Live volley: one summon produced four renderer initialisations at ~1.3 s
  intervals and then stopped at four.
- Live full show: one summon produced six, at 0/2.8/5.6/8.4 s, then the gap,
  then the finale pair at 14.2/14.6 s — matching the table exactly.
- Visual review: mid-show, a Sapphire ring was up while the next rocket climbed,
  and neither was the chosen shell; at the finale both bursts were the chosen
  Rose heart. Captures in `artifacts/displays/`.
- The card's `Display` pills were driven with a `uinput` pointer:
  `displaySize=2` persisted to the INI and the selection followed.
- After a show: no `omarchy-fireworks` layer surfaces and no PipeWire streams.

## Limits

- `tests/overlay.qml.in` is still not registered as a CTest test. It is the only
  thing that exercises `Fireworks.qml` itself, but that file now imports
  `qs.Commons` and `qs.Ui` for theming, which resolve only inside the Omarchy
  shell's own config root; and even with those bridged it needs a real Wayland
  layer-shell backend, which a unit test cannot have without opening overlay
  windows on the desktop. The scheduling logic was therefore put in
  `LaunchPool.qml`, which the registered test does cover; the `Fireworks.qml`
  wiring was verified live instead.
- The GPU figures come from DRM fdinfo for the shell process — render-engine
  busy share and GTT, not frame times. No frame-rate target has been measured.
  `FIREWORKS_PROFILE=1` now makes each view log its own mean CPU-side cost, but
  the shell inherits Hyprland's environment, so setting it requires restarting
  the session rather than the shell.
- The two resolutions in this document are not comparable to each other.
- Connected monitors still show the same display, at the same positions.
- A display is a queue of independent shells, not one composed show: each shell
  still gets its own render target and its own audio track. Combining them into
  a single light-accumulation pass remains the open native change noted in
  `docs/OVERLAP-VERIFICATION.md`.
