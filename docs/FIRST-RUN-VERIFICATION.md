# First-run setup

Verified 2026-10-02 on the installed Omarchy shell, Intel Arc B390, OpenGL.

- Removed the installed plugin with `omarchy plugin remove ... --yes`.
- Installed using `omarchy plugin add` with this repository's local path.
  Uncommitted source changes were copied into the disabled clone before enabling
  it. Neither native library was present; no prebuilt libraries were copied.
- Restarted the shell to clear its cached QML and previous native module.
- Visually inspected the setup notice. The source-only entry point loaded and
  returned a not-ready status instead of failing its native import.
- Verified the terminal setup action opens the configured Omarchy terminal,
  prints dependency instructions, compiles the backend, installs its libraries,
  restarts the shell and re-enables Fireworks. The terminal retains the output
  until Enter is pressed. The resulting status reports the 16-shell catalog.
- An initial version that built inside a shell-owned Process triggered a
  Quickshell crash during native-library hot reload (PID 110106 at 07:01:34).
  The final terminal flow disables Fireworks before library installation,
  restarts the shell and then enables it. No subsequent core dump appeared
  during the final setup verification. The crash's deeper cause is unresolved.
- A muted chrysanthemum rendered and returned to an empty launch-slot list
  after the initial first-run build. The rendering implementation is unchanged.
- All four existing CTest suites passed. The final bundle builds successfully;
  `bash -n fireworks-build.sh` and `git diff --check` pass.

Missing dependencies and incompatible Qt builds are reported in the terminal;
automatic system-package installation is not implemented. The build helper
requires the full repository's backend source. The setup flow was subsequently
published with the prebuilt alternative in v0.2.0; see
[PREBUILT-VERIFICATION.md](PREBUILT-VERIFICATION.md).
