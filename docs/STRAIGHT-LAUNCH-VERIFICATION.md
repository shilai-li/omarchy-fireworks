# Straight launch verification

Verified 2026-09-08: rocket ascent now keeps its launch x and depth fixed,
removing the initial lateral/depth velocity and sinusoidal wobble. Gravity
and drag still slow the ascent; shed embers and smoke still drift.

`cmake --build build -j 4` succeeded and all three CTest suites passed.
The engine test checks every simulation step through burst and every recorded
rocket trail point at left, centre, and right launch positions with wind enabled.

`./build/fireworks-capture artifacts/straight-launch --shell chrysanthemum`
rendered with Vulkan on Intel Arc B390 at 1920 × 1080 with HDR accumulation.
The contact sheet was visually inspected across launch, burst, fall, and decay;
the rocket rises vertically and the final 11-second frame has zero coverage
and vertices. Generated captures remain untracked.

The installed desktop library was subsequently updated with the shell stopped,
then the shell was restarted successfully. The installed library matches the
tested build byte for byte and the plugin remains enabled. The previous library
is backed up in `~/.config/omarchy/fireworks-backup.Owclxk/`.
