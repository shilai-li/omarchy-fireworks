# Studio Effects panel style — verification

Verified 2026-10-13 on the running Omarchy shell (Quickshell from
`~/omarchy/shell`, Hyprland 0.56.2), on a 3840×2160 monitor at scale 2. The
captures were cropped from screenshots of the live card and are not tracked.

The settings card and the first-run card were redrawn to match the Studio
Effects panel (`shilai_li.studio-effects`, `Panel.qml`), which is the visual
standard for Omarchy plugin panels. Behaviour and settings are unchanged: the
same preferences, the same `fireworks-ctl.sh` hotkey writer, the same IPC.

## What changed

| Before | After |
|---|---|
| A form of text labels, pills, and thin sliders | A header with facts, a launch card, Sound and Hotkey tiles, a scrolling list of the sixteen shells, and filling capsules |
| `Commons.Color.menu.*` colours | Tokens the Studio panel uses: `popups.background`, `bar.foreground`, `accent`, and tints of the text colour |
| Space, Escape and R only | Up/down move a cursor, left/right adjust, S sound, R hotkey, C clear, Tab hops to the next bar panel |
| Every row always shown | A row appears only while it applies |
| A text-only setup form with a Close button | A centred icon, the install routes as a grouped list, and key chips |

Rows hidden when they do not apply: Volume with the sound off, Interval unless
Display is a full show, Launch position for a random launch.

No new files: like the sibling plugins, `FireworksEffect.qml` and
`Fireworks.qml` each define the same tokens and inline components.

## Checks

Each was run against the live shell, with keys sent through a `uinput`
keyboard and clicks through a `uinput` mouse, and the result read from the saved
`settings.ini`, `status`, or `bindings.lua`.

| Check | Result |
|---|---|
| Left/right steps the shell | pass (the wrap at the ends was not tried) |
| Left/right on Display, Interval, Launch position, Volume, Light | pass, each by its own step, read back from `settings.ini` |
| S switches the sound; Volume row disappears and returns | pass |
| Enter on Random position switches it; Position row appears and disappears | pass |
| Space launches the selected shell | pass, `status` shows one slot |
| Escape closes the card | pass, in both the settings and first-run cards |
| R, then a bare key, refuses with "Add a modifier" | pass |
| R, then Escape cancels without writing | pass, `bindings.lua` unchanged |
| Record `SUPER+ALT+F9`; clear with C; record `SUPER+ALT+W` | pass, `bindings.lua` byte-identical to the original at the end |
| Click the launch disc | pass, launches |
| Click a shell row, Sound tile, Display segment | pass |
| Click the middle of the Glow capsule | pass, stored `bloom=1` |
| First-run card with `native/` moved aside | renders with the cursor on Build from source; Down and R leave it up; Esc closes it |

## A bug the checks found

Pressing R to start recording made the card say "Add a modifier" at once. The
shared key catcher leaves a text key unhandled, so the same R press reached the
recorder and was read as the chosen combination. The recorder now ignores the
one event that started it.

## Limits

- Hot reload is not enough for this plugin. After a QML change, `rescanPlugins`
  logs "reloading" but `FireworksEffect.qml`, which the wrapper loads through a
  `Loader`, stays at its old version until the shell is restarted
  (`omarchy-restart-shell`). This is what the README already says; it cost
  several stale captures here.
- Not asserted: Glow's key step (it moved and came back during another test, ending where it began), and the exact first-run cursor after Down. Not exercised: Enter on a first-run route (it would open a real build
  terminal), clicking the × on the Hotkey tile (C was used), dragging a capsule
  (a click was used), the Tab panel switch, touch input.
- Only one theme was looked at, with rounded corners. Square corners are handled
  in the code (`rounded` falls back to radius 0) but were not seen.
- The card opened on one monitor; placement on the other was not checked.
- "Use prebuilt" shows as selectable because `prebuilt.json` says a release is
  available. The v0.1.0 release has been withdrawn, so the download would fail
  until it is published again.
- Frame rate is not affected by the card, but this was not measured.
