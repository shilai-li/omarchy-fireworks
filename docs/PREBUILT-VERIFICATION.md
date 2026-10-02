# Prebuilt distribution

The v0.2.0 native release targets Linux x86_64 and these Arch packages:

- qt6-base 6.11.2-3
- qt6-declarative 6.11.2-1
- qt6-shadertools 6.11.2-1
- qt6-multimedia 6.11.2-1

The native archive includes the two stripped shared libraries, native qmldir,
MIT license and build information with source-file hashes. Qt is not bundled.
The build machine has glibc 2.44 and GCC runtime 16.2.1; the installer checks
shared-library dependencies on the destination machine before installing.

The setup screen offers Use prebuilt and Build from source. Both run in the
configured Omarchy terminal. Prebuilt setup checks architecture, exact Qt
package versions, the pinned SHA-256 digest in prebuilt.json and runtime
dependencies. It copies only known regular archive entries. Fireworks is
disabled during installation, followed by a shell restart and re-enable.
Installed build metadata prevents the entry point from importing a native
module after its recorded Qt package versions change.

Local verification on 2026-10-02:

- All four existing CTest suites passed.
- The packaged, stripped libraries passed the existing native QML import
  check from a relocated directory with the offscreen Qt platform.
- A mismatched qt6-base package was rejected before download or installation.
- Both setup scripts passed bash syntax validation; git diff --check passed.

Published-release verification:

- Published v0.2.0 with native and matching source archives plus SHA256SUMS.
- Downloaded the public native asset through the installer; its pinned checksum,
  Qt package checks and shared-library dependency checks passed.
- Cloned the public GitHub repository into a fresh temporary directory and ran
  the prebuilt installer. No compiler or CMake was invoked.
- The installed prebuilt passed the existing native QML import check.
- Altering its recorded Qt package version made the entry point's readiness
  check reject it, preventing an incompatible import after a Qt update.

QRhi's private API has no binary compatibility guarantee. This archive is not
claimed to work on other architectures, distributions or Qt package builds.
Use the source option when no compatible published archive is available.
