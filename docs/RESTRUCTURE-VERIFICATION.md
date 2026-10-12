# One repo again: root is the plugin, backend/ is the native build

Verified 2026-09-09 on the installed shell, Intel Arc B390, OpenGL.

## What changed and why

The prior milestone split this project into two repos, reasoning that an
Omarchy plugin is "cloned files only" (confirmed by reading
`omarchy-plugin-add`'s source: `git clone` + `mv`, nothing else) and Fireworks
needs compiled `.so` files a plain clone can never produce, so the installable
plugin needed a repo of its own.

That split solved the wrong problem. `omarchy-studio-effects` is a single
repo: its root is the plugin (`manifest.json`, `BarWidget.qml` at top level);
the Rust daemon lives in `daemon/`, built and installed separately
(`packaging/PKGBUILD`, `makepkg -si`) *before* `omarchy plugin add` runs, not
by it. The "cloned files only" constraint only requires the build to happen
outside `omarchy plugin add` — it never required a second repository. A
build-then-copy step from a `backend/` subfolder into this same repo's own
root-level `native/` satisfies it exactly as well as a second repo did,
without maintaining two copies of the same QML with nothing keeping them in
sync (a limitation the prior milestone's own doc had already flagged).

## The move

`git mv` per file, not a bulk copy: `Fireworks.qml`, `BarWidget.qml`,
`FireworksState.qml`, `LaunchPool.qml`, `fireworks-ctl.sh`, `qmldir`,
`manifest.json` moved from `plugin/` to the repo root. `CMakeLists.txt`,
`src/`, `shaders/`, `qml/`, `tests/`, `scripts/`, `.clang-format` moved into a
new `backend/`. A tracked `native/qmldir` was added at the root (identical
content to `qml/qmldir`, now `backend/qml/qmldir`) so a bare clone gets that
file for free — only the two `.so`s are missing until built.

An audit of every relative import and path reference in the repo, run before
touching anything, found exactly one place that needed real edits:
`backend/CMakeLists.txt`'s `plugin-bundle` target used `copy_directory` on
what was `plugin/` — pointing that at the new repo root instead would have
recursively copied `backend/` itself, `docs/`, and `.git/` into the bundle.
Replaced with an explicit list of the seven plugin files. Every other
reference — the three `tests/*.qml.in` files' `../plugin` imports (relative to
the *build* tree, unaffected by where the source tree's `CMakeLists.txt`
lives), every QML file's `import "native"` / `import "."` / computed
`pluginDir`, the C++ `#include`s — turned out to need no changes, which all
four tests passing unchanged after the move confirms rather than assumes.

While staging the move, `git add -A` picked up 2198 files instead of the
expected ~38: a stale `build/` and `artifacts/` (348 MB) had accumulated at
the true repo root across this session's earlier work and were no longer
covered once `.gitignore`'s patterns moved to `backend/build*`/`backend/
artifacts`. Both were pure regenerable build output; removed. Also found and
pruned 1567 unreachable git objects (348 MB) — compiled `.so` files and
screenshots that had been `git add`ed at some point earlier in this session
before `.gitignore` correctly excluded them, then unstaged before ever being
committed, left as garbage in the object store. `git gc --prune=now` took
`.git` from 318 MB to 244 KB; `git fsck --full` clean afterward, all 14
commits and `git log --follow` history through the renames intact.

## Checks

- `cd backend && cmake -S . -B build -G Ninja -DCMAKE_BUILD_TYPE=RelWithDebInfo && cmake --build build -j 4`
  succeeds. Shader compilation, resource paths (`qrc:/qml/Preview.qml`), and
  RPATH all resolved correctly with no changes, confirming they were already
  relative to the moving unit rather than the old absolute layout.
- `ctest --test-dir backend/build --output-on-failure`: all 4 suites pass —
  `engine`, `authored-shells`, `native-qml-import`, `overlapping-launches`.
- `backend/build/plugin/` contains all seven plugin files plus
  `native/{libfireworks_core.so, libfireworksplugin.so, qmldir}`;
  `fireworks-ctl.sh` kept its executable bit through the rewritten copy step.
- `backend/build/plugin/native/qmldir` (build-generated) is byte-identical to
  the tracked root `native/qmldir`.
- `omarchy plugin validate` passes against both `backend/build/plugin` and the
  repo root directly.
- **Re-ran the exact clone-only reproduction from the prior milestone, against
  the restructured repo**, since that reproduction — not just the file
  layout — is the actual point:
  1. Backed up the existing local dev install.
  2. `omarchy plugin add /path/to/omarchy-fireworks --enable --yes` (local
     path; see Limits) — succeeded, plugin enabled, `native/` holding only the
     tracked `qmldir`.
  3. Restarted the shell for a genuinely fresh process (a shell that already
     has the library `dlopen`'d from earlier in a session will falsely appear
     to work even with the file gone — the prior milestone's doc records
     hitting exactly this the first time). Summoning it reproduced:
     ```
     WARN scene: .../shilai_li.fireworks/Fireworks.qml[8:1]: module "Omarchy.Fireworks" plugin "fireworksplugin" not found
     ```
  4. Copied `backend/build/plugin/native/*.so` in, restarted, summoned again:
     loaded cleanly, `Fireworks renderer: OpenGL ...` logged, a chrysanthemum
     rendered live over the desktop.
  5. Removed the test install (`omarchy plugin remove`), restored the prior
     dev install from its backup, re-enabled it, confirmed a live launch and
     full cleanup (no layer surfaces, no lingering state) against the
     restored install.

## Limits

- Not pushed to GitHub yet; the reproduction above used a local filesystem
  path as the `git-url` argument, which `git clone` (and so
  `omarchy plugin add`) accepts directly.
- `omarchy plugin update` still can't know to rebuild or refresh the `.so`
  files on its own — that remains a manual step after every native change,
  documented in the README.
- A bare `omarchy plugin add` now clones the whole repo — `backend/`, `docs/`,
  `.git` history, everything — into the installed plugin directory, not just
  the seven plugin files. This matches `omarchy-studio-effects`'s own
  behavior (its installed directory carries `daemon/`, `packaging/`, `models/`
  too) and is harmless — Quickshell only looks at the manifest's entry points
  — but it means the installed directory is larger than the minimal bundle
  `backend/build/plugin/` produces for local development.
