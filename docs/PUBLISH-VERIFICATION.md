# Publish readiness

Verified 2026-09-09 on the installed shell.

## What changed

No `LICENSE` existed, and `manifest.json` was missing the `license` field and
had `"author": "shilai_li"` where the sibling Omarchy plugins
(`omarchy-eye-break`, `omarchy-recent-paths`, `omarchy-ssh-manager`,
`omarchy-studio-effects`) all use `"Shilai Li"`. Fixed to match: MIT license,
same copyright line, same manifest fields.

`plugin/fireworks-ctl.sh` is substantially derived from Omafetti's MIT
`omafetti-ctl.sh`. A code comment already credited it, but MIT requires the
copyright and permission notice to travel with a substantial reuse, not just
an attribution comment. Added a Credits section to the README with that
notice.

## The bigger finding: this repo cannot be `omarchy plugin add`-installed as-is

Checking `omarchy-studio-effects`'s own README turned up the actual constraint:
**"an Omarchy plugin is cloned files only — the installer builds nothing and
runs nothing."** Confirmed by reading `omarchy-plugin-add`'s source: it is
`git clone` followed by `mv` into `~/.config/omarchy/plugins/<id>/`, nothing else.

`shilai_li.fireworks` isn't a QML widget that talks to an external daemon over
IPC (studio-effects's shape); it's a `QQmlExtensionPlugin` —
`libfireworksplugin.so` and `libfireworks_core.so` — that Quickshell `dlopen`s
directly via `import "native"`. Those files:

- are not in git (only `plugin/{Fireworks.qml, BarWidget.qml, manifest.json,
  fireworks-ctl.sh, qmldir, FireworksState.qml, LaunchPool.qml}` are tracked;
  `native/` is a CMake output directory)
- can't safely be committed prebuilt either — the README already warns that
  QRhi has limited binary compatibility across Qt versions

So a plain clone of this repo would install a plugin whose `native/` is empty
or wrong for the local Qt build, and it would fail the moment Quickshell hit
the `import`.

## The split

Following the studio-effects pattern (native component built/packaged
separately from the installable plugin), but adapted for an in-process module
rather than a daemon: **two repos**.

- **This repo** — native source, build, tests, docs. Unchanged in shape;
  `plugin/` stays because `CMakeLists.txt`'s `plugin-bundle` target uses it as
  its copy source (`${CMAKE_SOURCE_DIR}/plugin` → `build/plugin/`).
- **[omarchy-fireworks-plugin](https://github.com/shilai-li/omarchy-fireworks-plugin)**
  — the installable bundle: `manifest.json` at its literal root (as the
  platform's publish checklist requires), the QML, `fireworks-ctl.sh`, and a
  `native/` that ships only its static `qmldir` declaration. The two `.so`
  files are gitignored there and copied in by hand after `omarchy plugin add`.

Both READMEs were updated: this repo's install section now points at the
plugin repo and gives the exact `cp build/plugin/native/*.so ...` step; the
plugin repo's README states the two-repo shape and the same step, plus update
and removal instructions.

## Checks

- `omarchy plugin validate` passes against the new repo with `manifest.json`
  at its root (not `plugin/manifest.json` — the actual constraint under test).
- **Reproduced the failure for real**, not just documented it: backed up the
  existing local dev install, ran the actual
  `omarchy plugin add <path-to-omarchy-fireworks-plugin> --enable --yes`,
  confirmed it succeeds and enables the plugin with `native/` holding only
  `qmldir`. A first attempt to summon it appeared to work — but that shell
  process had `libfireworksplugin.so` already `dlopen`'d from earlier in the
  same session, and Linux does not unload a mapped library just because its
  path was moved. Restarting the shell for a genuinely fresh process and
  retrying reproduced the real failure:

  ```
  WARN scene: .../shilai_li.fireworks/Fireworks.qml[8:1]: module "Omarchy.Fireworks" plugin "fireworksplugin" not found
  ```

- Copied `build/plugin/native/*.so` in, restarted the shell, summoned again:
  loaded cleanly, no warning, `Fireworks renderer: OpenGL ...` logged, and a
  chrysanthemum rendered live over the desktop — the exact install path both
  READMEs now document, proven rather than assumed.
- Removed the test install (`omarchy plugin remove`) and restored the prior
  local dev install from its backup; re-enabled it; confirmed a live launch
  and full cleanup (no layer surfaces, no lingering state) against the
  restored install.

## Limits

- Neither repo has been pushed to GitHub yet; the install test above used a
  local filesystem path as the `git-url` argument (which `git clone`, and so
  `omarchy plugin add`, accepts directly) rather than a real remote.
- `omarchy plugin update` on the plugin repo will pull QML changes but cannot
  know to also refresh the `.so` files — that remains a manual step after every
  native change, documented in both READMEs.
- The two repos can drift: `plugin/`'s QML in this repo and the plugin repo's
  copy are not otherwise linked. No mechanism (subtree, submodule, or sync
  script) keeps them in step yet; for now, changes need to be applied to both.
